import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApplicationsPage extends StatefulWidget {
  const ApplicationsPage({super.key});

  @override
  State<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends State<ApplicationsPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _applications = [];
  
  // Search and filter
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  String _selectedJob = 'All';
  
  final List<String> _filterOptions = ['All', 'Pending', 'Accepted', 'Rejected'];
  List<Map<String, dynamic>> _jobOptions = [{'job_id': 'All', 'title': 'All Jobs'}];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch jobs for filter
      final jobsResponse = await supabase
          .from('Jobs')
          .select('job_id, title')
          .order('created_at', ascending: false);
      
      final jobs = List<Map<String, dynamic>>.from(jobsResponse);
      _jobOptions = [{'job_id': 'All', 'title': 'All Jobs'}, ...jobs];
      
      // Fetch applications
      await _fetchApplications();
    } catch (e) {
      debugPrint('Error fetching data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchApplications() async {
    try {
      var query = supabase
          .from('Job_Applications')
          .select('''
            *,
            Jobs:job_id (
              job_id,
              title,
              Filmmakers:filmmaker_id (name)
            ),
            Users:user_id (
              user_id,
              name,
              email
            )
          ''');
      
      // Apply status filter
      if (_selectedFilter != 'All') {
        query = query.eq('status', _selectedFilter.toLowerCase());
      }
      
      // Apply job filter
      if (_selectedJob != 'All') {
        query = query.eq('job_id', _selectedJob);
      }
      
      final response = await query.order('applied_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _applications = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching applications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateApplicationStatus(int applicationId, String status) async {
    try {
      await supabase
          .from('Job_Applications')
          .update({'status': status})
          .eq('application_id', applicationId);
      
      await _fetchApplications();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Application ${status.capitalize()} successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  List<Map<String, dynamic>> _getFilteredApplications() {
    if (_searchQuery.isEmpty) return _applications;
    
    return _applications.where((application) {
      final user = application['Users'] as Map<String, dynamic>;
      final job = application['Jobs'] as Map<String, dynamic>;
      final filmmaker = job['Filmmakers'] as Map<String, dynamic>;
      
      final userName = user['name']?.toString().toLowerCase() ?? '';
      final userEmail = user['email']?.toString().toLowerCase() ?? '';
      final jobTitle = job['title']?.toString().toLowerCase() ?? '';
      final filmmakerName = filmmaker['name']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      
      return userName.contains(query) || 
             userEmail.contains(query) || 
             jobTitle.contains(query) ||
             filmmakerName.contains(query);
    }).toList();
  }

  void _viewApplicationDetails(Map<String, dynamic> application) {
    final user = application['Users'] as Map<String, dynamic>;
    final job = application['Jobs'] as Map<String, dynamic>;
    final filmmaker = job['Filmmakers'] as Map<String, dynamic>;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.6,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Application Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              
              // Application info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column - Applicant info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Applicant Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow('Name', user['name'] ?? 'Unknown'),
                        _buildInfoRow('Email', user['email'] ?? 'Unknown'),
                        _buildInfoRow('Applied On', DateTime.parse(application['applied_at']).toString().substring(0, 10)),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(application['status']),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            (application['status'] ?? 'pending').capitalize(),
                            style: TextStyle(
                              color: _getStatusTextColor(application['status']),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 32),
                  
                  // Right column - Job info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Job Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow('Job Title', job['title'] ?? 'Unknown'),
                        _buildInfoRow('Filmmaker', filmmaker['name'] ?? 'Unknown'),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Action buttons
              if (application['status'] == 'pending')
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _updateApplicationStatus(application['application_id'], 'rejected');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Reject'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _updateApplicationStatus(application['application_id'], 'accepted');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Accept'),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredApplications = _getFilteredApplications();
    
    return Scaffold(
      body: _isLoading && _applications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with title
                const Text(
                  'Job Applications Management',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Search and filter
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search applications...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<String>(
                      value: _selectedFilter,
                      items: _filterOptions.map((filter) {
                        return DropdownMenuItem(
                          value: filter,
                          child: Text(filter),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedFilter = value!;
                          _fetchApplications();
                        });
                      },
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<String>(
                      value: _selectedJob,
                      items: _jobOptions.map((job) {
                        return DropdownMenuItem(
                          value: job['job_id'].toString(),
                          child: Text(
                            job['title'],
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedJob = value!;
                          _fetchApplications();
                        });
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Applications table
                Expanded(
                  child: Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Applicant')),
                            DataColumn(label: Text('Email')),
                            DataColumn(label: Text('Job')),
                            DataColumn(label: Text('Filmmaker')),
                            DataColumn(label: Text('Applied On')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: filteredApplications.map((application) {
                            final user = application['Users'] as Map<String, dynamic>;
                            final job = application['Jobs'] as Map<String, dynamic>;
                            final filmmaker = job['Filmmakers'] as Map<String, dynamic>;
                            final status = application['status'] ?? 'pending';
                            
                            return DataRow(
                              cells: [
                                DataCell(Text(user['name'] ?? '')),
                                DataCell(Text(user['email'] ?? '')),
                                DataCell(Text(job['title'] ?? '')),
                                DataCell(Text(filmmaker['name'] ?? '')),
                                DataCell(Text(DateTime.parse(application['applied_at']).toString().substring(0, 10))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      status.capitalize(),
                                      style: TextStyle(
                                        color: _getStatusTextColor(status),
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.visibility, color: Colors.blue),
                                        onPressed: () => _viewApplicationDetails(application),
                                        tooltip: 'View Details',
                                      ),
                                      if (status == 'pending') ...[
                                        IconButton(
                                          icon: const Icon(Icons.check_circle, color: Colors.green),
                                          onPressed: () => _updateApplicationStatus(application['application_id'], 'accepted'),
                                          tooltip: 'Accept',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.cancel, color: Colors.red),
                                          onPressed: () => _updateApplicationStatus(application['application_id'], 'rejected'),
                                          tooltip: 'Reject',
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green[100]!;
      case 'rejected':
        return Colors.red[100]!;
      case 'pending':
      default:
        return Colors.orange[100]!;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green[800]!;
      case 'rejected':
        return Colors.red[800]!;
      case 'pending':
      default:
        return Colors.orange[800]!;
    }
  }
}

// Extension to capitalize first letter of a string
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

