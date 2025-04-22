import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talentspotfilmmaker/filmmaker_home_page.dart';
import 'package:talentspotfilmmaker/filmmaker_jobs_page.dart'; // For navigation
import 'package:talentspotfilmmaker/filmmaker_profile_page.dart'; // For navigation
import 'package:talentspotfilmmaker/filmmaker_promotions_page.dart'; // For navigation
import 'package:talentspotfilmmaker/filmmaker_talent_search_page.dart'; // For navigation
import 'package:talentspotfilmmaker/login.dart'; // For navigation

class FilmmakerJobsPage extends StatefulWidget {
  const FilmmakerJobsPage({super.key});

  @override
  State<FilmmakerJobsPage> createState() => _FilmmakerJobsPageState();
}

class _FilmmakerJobsPageState extends State<FilmmakerJobsPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  bool _isCategoryLoading = true;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _budgetController = TextEditingController();
  DateTime _lastDate = DateTime.now().add(const Duration(days: 30));
  String? _selectedCategoryId;
  bool _isFormLoading = false;
  int? _editingJobId;

  String _userName = ''; // To match homepage user display
  String _profilePic = ''; // To match homepage profile picture
  int _selectedIndex = 1; // Default to Jobs tab

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchCategories();
    _fetchJobs();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final userData =
          await supabase
              .from('tbl_filmmakers')
              .select()
              .eq('filmmaker_id', userId)
              .single();
      if (mounted) {
        setState(() {
          _userName = userData['filmmaker_name'] ?? '';
          _profilePic = userData['filmmaker_photo'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _fetchCategories() async {
    setState(() => _isCategoryLoading = true);
    try {
      final response = await supabase
          .from('tbl_category')
          .select('id, category_name');
      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(response);
          _selectedCategoryId =
              _categories.isNotEmpty ? _categories[0]['id'].toString() : null;
          _isCategoryLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      if (mounted) {
        setState(() => _isCategoryLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching categories: $e')),
        );
      }
    }
  }

  Future<void> _fetchJobs() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await supabase
          .from('tbl_job')
          .select('*, category:category_id(category_name)')
          .eq('filmmaker_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _jobs = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching jobs: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _jobs = [];
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error fetching jobs: $e')));
      }
    }
  }

  Future<void> _deleteJob(int jobId) async {
    try {
      await supabase.from('tbl_job').delete().eq('job_id', jobId);
      await _fetchJobs();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Job deleted successfully')));
    } catch (e) {
      debugPrint('Error deleting job: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting job: $e')));
    }
  }

  Future<void> _toggleJobStatus(int jobId, int currentStatus) async {
    final newStatus = currentStatus == 0 ? 1 : 0;
    try {
      await supabase
          .from('tbl_job')
          .update({'job_status': newStatus})
          .eq('job_id', jobId);
      await _fetchJobs();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Job ${newStatus == 1 ? 'opened' : 'closed'} successfully',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error updating job status: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
    }
  }

  Future<void> _saveJob() async {
    if (!_formKey.currentState!.validate() || _selectedCategoryId == null) {
      return;
    }

    setState(() => _isFormLoading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You need to be logged in to post a job'),
          ),
        );
        return;
      }

      final jobData = {
        'job_title': _titleController.text.trim(),
        'job_description': _descriptionController.text.trim(),
        'job_amount': _budgetController.text.trim(),
        'category_id': _selectedCategoryId,
        'job_lastdate': _lastDate.toIso8601String(),
        'filmmaker_id': userId,
        'job_status': 1,
        'created_at': DateTime.now().toIso8601String(),
      };

      jobData['job_location'] =
          _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim();

      if (_editingJobId == null) {
        await supabase.from('tbl_job').insert(jobData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job posted successfully!')),
        );
      } else {
        await supabase
            .from('tbl_job')
            .update(jobData)
            .eq('job_id', _editingJobId!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job updated successfully!')),
        );
      }

      await _fetchJobs();
      Navigator.pop(context);
      _resetForm();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isFormLoading = false);
      }
    }
  }

  void _resetForm() {
    _titleController.clear();
    _descriptionController.clear();
    _locationController.clear();
    _budgetController.clear();
    _lastDate = DateTime.now().add(const Duration(days: 30));
    _selectedCategoryId =
        _categories.isNotEmpty ? _categories[0]['id'].toString() : null;
    _editingJobId = null;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _lastDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _lastDate) {
      setState(() => _lastDate = picked);
    }
  }

  void _showJobForm({Map<String, dynamic>? job}) {
    if (job != null) {
      _editingJobId = job['job_id'].toInt();
      _titleController.text = job['job_title'] ?? '';
      _descriptionController.text = job['job_description'] ?? '';
      _locationController.text = job['job_location'] ?? '';
      _budgetController.text = job['job_amount']?.toString() ?? '';
      _lastDate =
          job['job_lastdate'] != null
              ? DateTime.parse(job['job_lastdate'])
              : DateTime.now().add(const Duration(days: 30));
      _selectedCategoryId = job['category_id']?.toString();
    } else {
      _resetForm();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: MediaQuery.of(context).size.width * 0.04,
              right: MediaQuery.of(context).size.width * 0.04,
              top: MediaQuery.of(context).size.height * 0.02,
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job != null ? 'Edit Job' : 'Add New Job',
                      style: GoogleFonts.poppins(
                        fontSize:
                            MediaQuery.of(context).size.width < 600 ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF4361EE),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    _buildTextField(
                      controller: _titleController,
                      label: 'Job Title',
                      hint: 'e.g. Lead Actor for Short Film',
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? 'Please enter a job title'
                                  : null,
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    _buildDropdown(),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Job Description',
                      hint:
                          'Describe the job requirements and responsibilities',
                      maxLines: 5,
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? 'Please enter a job description'
                                  : null,
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    _buildTextField(
                      controller: _locationController,
                      label: 'Location',
                      hint: 'e.g. Los Angeles, CA',
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? 'Please enter a location'
                                  : null,
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    _buildTextField(
                      controller: _budgetController,
                      label: 'Budget',
                      hint: 'e.g. 500 per day or Negotiable',
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? 'Please enter a budget'
                                  : null,
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: _buildDateField(
                        'Last Date',
                        _lastDate.toString().substring(0, 10),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.04),
                    ElevatedButton(
                      onPressed: _isFormLoading ? null : _saveJob,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4361EE),
                        padding: EdgeInsets.symmetric(
                          vertical: MediaQuery.of(context).size.height * 0.02,
                          horizontal: MediaQuery.of(context).size.width * 0.1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child:
                          _isFormLoading
                              ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                              : Text(
                                job != null ? 'Update Job' : 'Add Job',
                                style: GoogleFonts.poppins(
                                  fontSize:
                                      MediaQuery.of(context).size.width < 600
                                          ? 14
                                          : 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF4361EE),
                onRefresh: _fetchJobs,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width * 0.05,
                    vertical: MediaQuery.of(context).size.height * 0.02,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _isLoading || _isCategoryLoading
                          ? Center(
                            child: CircularProgressIndicator(
                              color: const Color(0xFF4361EE),
                            ),
                          )
                          : _jobs.isEmpty
                          ? Center(
                            child: Text(
                              'You haven\'t posted any jobs yet',
                              style: GoogleFonts.poppins(
                                fontSize:
                                    MediaQuery.of(context).size.width < 600
                                        ? 14
                                        : 16,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          )
                          : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _jobs.length,
                            itemBuilder: (context, index) {
                              final job = _jobs[index];
                              return Container(
                                margin: EdgeInsets.only(
                                  bottom:
                                      MediaQuery.of(context).size.height * 0.02,
                                ),
                                child: Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Container(
                                    padding: EdgeInsets.all(
                                      MediaQuery.of(context).size.width * 0.04,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Title Section
                                        Text(
                                          job['job_title'] ?? 'Untitled Job',
                                          style: GoogleFonts.poppins(
                                            fontSize:
                                                MediaQuery.of(
                                                          context,
                                                        ).size.width <
                                                        600
                                                    ? 16
                                                    : 18,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF2D3748),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(
                                          height:
                                              MediaQuery.of(
                                                context,
                                              ).size.height *
                                              0.01,
                                        ),

                                        // Details Section
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildDetailRow(
                                              'Location',
                                              job['job_location'] ??
                                                  'Not specified',
                                            ),
                                            SizedBox(
                                              height:
                                                  MediaQuery.of(
                                                    context,
                                                  ).size.height *
                                                  0.01,
                                            ),
                                            _buildDetailRow(
                                              'Category',
                                              job['category']?['category_name'] ??
                                                  'Not specified',
                                            ),
                                            SizedBox(
                                              height:
                                                  MediaQuery.of(
                                                    context,
                                                  ).size.height *
                                                  0.01,
                                            ),
                                            _buildDetailRow(
                                              'Deadline',
                                              job['job_lastdate'] != null
                                                  ? DateTime.parse(
                                                    job['job_lastdate'],
                                                  ).toString().substring(0, 10)
                                                  : 'Not set',
                                            ),
                                            SizedBox(
                                              height:
                                                  MediaQuery.of(
                                                    context,
                                                  ).size.height *
                                                  0.01,
                                            ),
                                            _buildDetailRow(
                                              'Budget',
                                              job['job_amount'] ??
                                                  'Not specified',
                                            ),
                                          ],
                                        ),

                                        // Trailing Actions and Status
                                        SizedBox(
                                          height:
                                              MediaQuery.of(
                                                context,
                                              ).size.height *
                                              0.01,
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.edit,
                                                    color: Color(0xFF4361EE),
                                                  ),
                                                  onPressed:
                                                      () => _showJobForm(
                                                        job: job,
                                                      ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete,
                                                    color: Colors.red,
                                                  ),
                                                  onPressed:
                                                      () => _deleteJob(
                                                        job['job_id'],
                                                      ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              job['job_status'] == 1
                                                  ? 'Open'
                                                  : 'Closed',
                                              style: GoogleFonts.poppins(
                                                fontSize:
                                                    MediaQuery.of(
                                                              context,
                                                            ).size.width <
                                                            600
                                                        ? 12
                                                        : 14,
                                                color:
                                                    job['job_status'] == 1
                                                        ? Colors.green
                                                        : Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showJobForm(),
        backgroundColor: const Color(0xFF4361EE),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width * 0.05,
        vertical: MediaQuery.of(context).size.height * 0.02,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $_userName',
                style: GoogleFonts.poppins(
                  fontSize: MediaQuery.of(context).size.width < 600 ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D3748),
                ),
              ),
              Text(
                'Manage Your Jobs',
                style: GoogleFonts.poppins(
                  fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Color(0xFF4361EE),
                ),
                onPressed: () {},
              ),
              SizedBox(width: MediaQuery.of(context).size.width * 0.02),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FilmmakerProfilePage(),
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: MediaQuery.of(context).size.width * 0.05,
                  backgroundColor: const Color(0xFFE2E8F0),
                  backgroundImage:
                      _profilePic.isNotEmpty
                          ? CachedNetworkImageProvider(_profilePic)
                          : null,
                  child:
                      _profilePic.isEmpty
                          ? const Icon(Icons.person, color: Color(0xFF64748B))
                          : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavItemTapped,
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF4361EE),
        unselectedItemColor: const Color(0xFF94A3B8),
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: MediaQuery.of(context).size.width < 600 ? 10 : 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: MediaQuery.of(context).size.width < 600 ? 10 : 12,
          fontWeight: FontWeight.w500,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline_rounded),
            activeIcon: Icon(Icons.work_rounded),
            label: 'Jobs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.movie_outlined),
            activeIcon: Icon(Icons.movie_rounded),
            label: 'Promotions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const FilmmakerHomePage()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PromotionsPage()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const FilmmakerProfilePage()),
        );
        break;
    }
    if (index != 1) {
      setState(() {
        _selectedIndex = 1;
      });
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF4361EE),
          ),
        ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.01),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
              fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
              color: const Color(0xFF64748B),
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.all(
              MediaQuery.of(context).size.width * 0.03,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: GoogleFonts.poppins(
            fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF4361EE),
          ),
        ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.01),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.03,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategoryId,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF4361EE)),
              style: GoogleFonts.poppins(
                fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
                color: const Color(0xFF2D3748),
              ),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedCategoryId = newValue;
                  });
                }
              },
              items:
                  _categories.map<DropdownMenuItem<String>>((
                    Map<String, dynamic> category,
                  ) {
                    return DropdownMenuItem<String>(
                      value: category['id'].toString(),
                      child: Text(category['category_name']),
                    );
                  }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF4361EE),
          ),
        ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.01),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.03,
            vertical: MediaQuery.of(context).size.height * 0.01,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
                  color: const Color(0xFF64748B),
                ),
              ),
              Icon(Icons.calendar_today, color: const Color(0xFF4361EE)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
            color: const Color(0xFF4361EE),
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(width: MediaQuery.of(context).size.width * 0.02),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
              color: const Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
