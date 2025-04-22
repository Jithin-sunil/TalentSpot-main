import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:talentspot/jobdetails.dart'; // Import JobDetailPage

class JobListPage extends StatefulWidget {
  const JobListPage({super.key});

  @override
  State<JobListPage> createState() => _JobListPageState();
}

class _JobListPageState extends State<JobListPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _filteredJobs = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  Map<int, bool> _selectedCategories = {};

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchJobs();
    _searchController.addListener(_filterJobs);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await supabase.from('tbl_category').select();
      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(response);
          _selectedCategories = {for (var cat in _categories) cat['id']: false};
        });
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load categories')),
      );
    }
  }

  Future<void> _fetchJobs() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('tbl_job')
          .select('*, tbl_filmmakers(filmmaker_name, filmmaker_photo)')
          .eq('job_status', '1')
          .order('job_lastdate', ascending: false);

      if (mounted) {
        setState(() {
          _jobs = List<Map<String, dynamic>>.from(response);
          _filteredJobs = _jobs;
          _isLoading = false;
        });
        _filterJobs();
      }
    } catch (e) {
      debugPrint('Error fetching jobs: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load jobs')),
      );
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterJobs() {
    final query = _searchController.text.toLowerCase();
    final selectedCatIds = _selectedCategories.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    setState(() {
      _filteredJobs = _jobs.where((job) {
        final matchesTitle = job['job_title'].toString().toLowerCase().contains(query);
        final matchesCategory = selectedCatIds.isEmpty || selectedCatIds.contains(job['category_id']);
        return matchesTitle && matchesCategory;
      }).toList();
    });
  }

  void _toggleCategoryFilter(int categoryId, bool value) {
    setState(() {
      _selectedCategories[categoryId] = value;
    });
    _filterJobs();
  }

  String _formatDate(String? date) {
    if (date == null) return 'N/A';
    try {
      final parsedDate = DateTime.parse(date);
      return '${parsedDate.day}/${parsedDate.month}/${parsedDate.year}';
    } catch (e) {
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF4361EE);
    const Color secondaryColor = Color(0xFF64748B);
    const Color accentColor = Colors.white;
    const Color backgroundColor = Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Job Listings',
          style: GoogleFonts.poppins(
            fontSize: MediaQuery.of(context).size.width < 600 ? 18 : 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D3748),
          ),
        ),
        backgroundColor: accentColor,
        elevation: 2,
        shadowColor: const Color(0x0D000000).withOpacity(0.05),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: primaryColor),
            onPressed: () {
              _fetchCategories();
              _fetchJobs();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width * 0.05,
              vertical: 16,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by job title...',
                hintStyle: GoogleFonts.poppins(color: secondaryColor),
                prefixIcon: Icon(Icons.search, color: primaryColor),
                filled: true,
                fillColor: secondaryColor.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: GoogleFonts.poppins(color: const Color(0xFF2D3748)),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.05),
            child: SizedBox(
              height: 40,
              child: _categories.isEmpty
                  ? Center(child: CircularProgressIndicator(color: primaryColor))
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final isSelected = _selectedCategories[category['id']] ?? false;
                        return Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(
                              category['category_name'] ?? 'Unknown',
                              style: GoogleFonts.poppins(
                                color: isSelected ? accentColor : const Color(0xFF2D3748),
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (value) => _toggleCategoryFilter(category['id'], value),
                            selectedColor: primaryColor.withOpacity(0.8),
                            checkmarkColor: accentColor,
                            backgroundColor: secondaryColor.withOpacity(0.1),
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: RefreshIndicator(
              color: primaryColor,
              onRefresh: _fetchJobs,
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: primaryColor))
                  : _filteredJobs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.work_off,
                                size: 64,
                                color: secondaryColor.withOpacity(0.7),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No jobs found',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  color: secondaryColor,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Try adjusting your search or filters',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: secondaryColor,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(
                            horizontal: MediaQuery.of(context).size.width * 0.05,
                            vertical: 8,
                          ),
                          itemCount: _filteredJobs.length,
                          itemBuilder: (context, index) {
                            final job = _filteredJobs[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => JobDetailPage(jobId: job['job_id'].toString()),
                                  ),
                                );
                              },
                              child: _buildJobCard(job),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    const Color primaryColor = Color(0xFF4361EE);
    const Color secondaryColor = Color(0xFF64748B);
    const Color accentColor = Colors.white;

    final filmmaker = job['tbl_filmmakers'] as Map<String, dynamic>? ?? {};

    return Card(
      color: accentColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: filmmaker['filmmaker_photo'] != null
                      ? NetworkImage(filmmaker['filmmaker_photo'])
                      : null,
                  child: filmmaker['filmmaker_photo'] == null
                      ? Text(
                          filmmaker['filmmaker_name']?[0].toUpperCase() ?? 'F',
                          style: GoogleFonts.poppins(color: accentColor),
                        )
                      : null,
                  backgroundColor: primaryColor.withOpacity(0.1),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job['job_title'] ?? 'Unknown Job',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2D3748),
                        ),
                      ),
                      Text(
                        filmmaker['filmmaker_name'] ?? 'Unknown Filmmaker',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: job['job_status'] == 1 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    job['job_status'] == 1 ? 'Active' : 'Closed',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: job['job_status'] == 1 ? Colors.green[800] : Colors.red[800],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              job['job_description']?.trim().isNotEmpty ?? false
                  ? job['job_description']
                  : 'No description provided',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF2D3748),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Amount: ${job['job_amount']?.toString() ?? 'N/A'}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: secondaryColor,
                  ),
                ),
                Text(
                  'Last Date: ${_formatDate(job['job_lastdate'])}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: secondaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}