import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class JobsPage extends StatefulWidget {
  const JobsPage({super.key});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _jobs = [];
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentPage = 1;
  final int _itemsPerPage = 5;

  @override
  void initState() {
    super.initState();
    _fetchJobs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchJobs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await supabase
          .from('tbl_job')
          .select(
            '*, tbl_filmmakers!filmmaker_id(filmmaker_name, filmmaker_email), tbl_category!category_id(category_name)',
          )
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
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error fetching jobs: $e')));
      }
    }
  }

  Future<void> _toggleJobStatus(String jobId, int currentStatus) async {
    try {
      final newStatus =
          currentStatus == 1
              ? 0
              : 1; // Toggle between active (1) and blocked (0)
      await supabase
          .from('tbl_job')
          .update({'job_status': newStatus})
          .eq('job_id', jobId);

      await _fetchJobs();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 1
                ? 'Job unblocked successfully'
                : 'Job blocked successfully',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF4361EE),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  List<Map<String, dynamic>> _getFilteredJobs() {
    if (_searchQuery.isEmpty) return _jobs;

    return _jobs.where((job) {
      final title = job['job_title']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return title.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> _getPaginatedJobs() {
    final filteredJobs = _getFilteredJobs();
    final startIndex = (_currentPage - 1) * _itemsPerPage;

    if (startIndex >= filteredJobs.length) {
      return [];
    }

    final endIndex =
        startIndex + _itemsPerPage > filteredJobs.length
            ? filteredJobs.length
            : startIndex + _itemsPerPage;

    return filteredJobs.sublist(startIndex, endIndex);
  }

  int get _pageCount {
    return (_getFilteredJobs().length / _itemsPerPage).ceil();
  }

  String _getStatusText(int status) {
    return status == 1 ? 'Active' : 'Blocked';
  }

  Color _getStatusColor(int status) {
    return status == 1 ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
  }

  void _showJobDetailsDialog(Map<String, dynamic> job) {
    final filmmaker = job['tbl_filmmakers'] as Map<String, dynamic>?;
    final formattedDate = DateFormat(
      'MMM dd, yyyy',
    ).format(DateTime.parse(job['created_at']));
    final formattedDeadline = DateFormat(
      'MMM dd, yyyy',
    ).format(DateTime.parse(job['job_lastdate']));

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              job['job_title'] ?? 'Job Details',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow('Posted Date', formattedDate),
                  _buildDetailRow('Title', job['job_title'] ?? 'N/A'),
                  _buildDetailRow(
                    'Description',
                    job['job_description'] ?? 'N/A',
                  ),
                  _buildDetailRow(
                    'Category',
                    job['tbl_category']['category_name'] ?? 'N/A',
                  ),
                  _buildDetailRow(
                    'Amount',
                    '₹${job['job_amount']?.toString() ?? 'N/A'}',
                  ),
                  _buildDetailRow('Location', job['job_location'] ?? 'N/A'),
                  _buildDetailRow('Last Date', formattedDeadline),
                  _buildDetailRow(
                    'Filmmaker Name',
                    filmmaker?['filmmaker_name'] ?? 'N/A',
                  ),
                  _buildDetailRow(
                    'Filmmaker Email',
                    filmmaker?['filmmaker_email'] ?? 'N/A',
                  ),
                  _buildDetailRow(
                    'Status',
                    _getStatusText(job['job_status'] ?? 1),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paginatedJobs = _getPaginatedJobs();
    final activeJobs =
        _getFilteredJobs().where((job) => job['job_status'] == 1).length;

    return Scaffold(
      body:
          _isLoading && _jobs.isEmpty
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF4361EE)),
              )
              : Container(
                color: const Color(0xFFF8F9FA),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      color: Colors.white,
                      child: Row(
                        children: [
                          const Text(
                            'Jobs Management',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 300,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search by job title...',
                                hintStyle: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Colors.grey[500],
                                  size: 20,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                suffixIcon:
                                    _searchQuery.isNotEmpty
                                        ? IconButton(
                                          icon: Icon(
                                            Icons.clear,
                                            color: Colors.grey[500],
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _searchController.clear();
                                              _searchQuery = '';
                                              _currentPage = 1;
                                            });
                                          },
                                        )
                                        : null,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                  _currentPage = 1;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Overview
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Jobs Overview',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Stats Cards
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              title: 'Total Jobs',
                              value: _getFilteredJobs().length.toString(),
                              icon: Icons.work_outline,
                              iconColor: const Color(0xFF4361EE),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _StatCard(
                              title: 'Active Jobs',
                              value: activeJobs.toString(),
                              icon: Icons.check_circle_outline,
                              iconColor: const Color(0xFF4CAF50),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Table Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Title',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Posted By',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Location',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                'Amount',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                'Status',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                'Action',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Table Content
                    Expanded(
                      child:
                          _isLoading
                              ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF4361EE),
                                ),
                              )
                              : paginatedJobs.isEmpty
                              ? Center(
                                child: Text(
                                  'No jobs found',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              )
                              : ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                itemCount: paginatedJobs.length,
                                separatorBuilder:
                                    (context, index) =>
                                        const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final job = paginatedJobs[index];
                                  final status = job['job_status'] ?? 1;
                                  final filmmaker =
                                      job['tbl_filmmakers']
                                          as Map<String, dynamic>?;
                                  final formattedDate = DateFormat(
                                    'MMM dd, yyyy',
                                  ).format(DateTime.parse(job['created_at']));
                                  final postedBy =
                                      filmmaker != null
                                          ? '${filmmaker['filmmaker_name']} (${filmmaker['filmmaker_email']}) - $formattedDate'
                                          : 'N/A - $formattedDate';

                                  return Container(
                                    color: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            job['job_title'] ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            postedBy,
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            job['job_location'] ?? '',
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            '₹${job['job_amount']?.toString() ?? 'N/A'}',
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(
                                                status,
                                              ).withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              _getStatusText(status),
                                              style: TextStyle(
                                                color: _getStatusColor(status),
                                                fontWeight: FontWeight.w500,
                                                fontSize: 12,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.visibility,
                                                  color: Colors.blue,
                                                ),
                                                onPressed:
                                                    () => _showJobDetailsDialog(
                                                      job,
                                                    ),
                                                tooltip: 'View Details',
                                              ),
                                              OutlinedButton(
                                                onPressed:
                                                    () => _toggleJobStatus(
                                                      job['job_id'].toString(),
                                                      status,
                                                    ),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor:
                                                      status == 1
                                                          ? const Color(
                                                            0xFFF44336,
                                                          )
                                                          : const Color(
                                                            0xFF4CAF50,
                                                          ),
                                                  side: BorderSide(
                                                    color:
                                                        status == 1
                                                            ? const Color(
                                                              0xFFF44336,
                                                            )
                                                            : const Color(
                                                              0xFF4CAF50,
                                                            ),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                      ),
                                                  minimumSize: const Size(
                                                    0,
                                                    32,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                ),
                                                child: Text(
                                                  status == 1
                                                      ? 'Block'
                                                      : 'Unblock',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                    ),
                    // Pagination
                    if (!_isLoading && _getFilteredJobs().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.white,
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Showing ${paginatedJobs.length} of ${_getFilteredJobs().length} jobs',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left),
                                  onPressed:
                                      _currentPage > 1
                                          ? () {
                                            setState(() {
                                              _currentPage--;
                                            });
                                          }
                                          : null,
                                  color:
                                      _currentPage > 1
                                          ? const Color(0xFF4361EE)
                                          : Colors.grey[400],
                                ),
                                for (int i = 1; i <= _pageCount; i++)
                                  if (i == _currentPage)
                                    Container(
                                      width: 32,
                                      height: 32,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4361EE),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '$i',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  else
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _currentPage = i;
                                        });
                                      },
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '$i',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                    ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right),
                                  onPressed:
                                      _currentPage < _pageCount
                                          ? () {
                                            setState(() {
                                              _currentPage++;
                                            });
                                          }
                                          : null,
                                  color:
                                      _currentPage < _pageCount
                                          ? const Color(0xFF4361EE)
                                          : Colors.grey[400],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
