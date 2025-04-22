import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talentspot/chat.dart';
import 'package:talentspot/login.dart';

class MyApplicationsPage extends StatefulWidget {
  const MyApplicationsPage({super.key});

  @override
  State<MyApplicationsPage> createState() => _MyApplicationsPageState();
}

class _MyApplicationsPageState extends State<MyApplicationsPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _myRequests = [];
  List<Map<String, dynamic>> _viewRequests = [];
  bool _isLoading = true;
  late TabController _tabController;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeUserAndData(); // Initialize user and fetch data sequentially
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeUserAndData() async {
    await _fetchUserId(); // Fetch userId first
    if (_userId != null) {
      await Future.wait([
        _fetchMyRequests(),
        _fetchViewRequests(),
      ]); // Fetch data only if userId is available
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUserId() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      debugPrint('User not authenticated');
      await _signOut(); // Automatically sign out if no user
      return;
    }
    setState(() {
      _userId = user.id;
    });
  }

  Future<void> _fetchMyRequests() async {
    if (_userId == null) {
      debugPrint('User ID is null, fetching aborted');
      return;
    }
    try {
      final response = await supabase
          .from('tbl_jobapplication')
          .select('''
            *,
            tbl_job:job_id (
              job_id,
              job_title,
              job_location,
              job_lastdate,
              job_description,
              tbl_category:category_id (category_name),
              tbl_filmmakers:filmmaker_id (filmmaker_name, filmmaker_id)
            )
          ''')
          .eq('user_id', _userId!)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _myRequests = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Error fetching my requests: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch job applications')),
        );
      }
    }
  }

  Future<void> _fetchViewRequests() async {
    if (_userId == null) {
      debugPrint('User ID is null, fetching aborted');
      return;
    }
    try {
      final response = await supabase
          .from('tbl_hire')
          .select('''
            hire_id,
            filmmaker_id,
            user_id,
            created_at,
            hire_status,
            hire_message,
            tbl_user:user_id (
              user_id,
              user_name,
              user_photo,
              user_age,
              user_gender,
              user_contact
            ),
            tbl_filmmakers:filmmaker_id (
              filmmaker_name,
              filmmaker_id
            )
          ''')
          .eq('user_id', _userId!)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _viewRequests = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Error fetching view requests: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch hire requests')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await supabase.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } catch (e) {
      debugPrint('Error signing out: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign out')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green[600]!;
      case 'rejected':
        return Colors.red[600]!;
      case 'pending':
      default:
        return Colors.orange[700]!;
    }
  }

  String _getStatusMessage(int status) {
    switch (status) {
      case 0:
        return 'Your request is currently pending review.';
      case 1:
        return 'Your request has been accepted! Proceed accordingly.';
      case 2:
        return 'Your request has been rejected. Please try again.';
      default:
        return 'Unknown status.';
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
          'My Applications & Requests',
          style: GoogleFonts.poppins(
            fontSize: MediaQuery.of(context).size.width < 600 ? 18 : 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D3748),
          ),
        ),
        backgroundColor: accentColor,
        elevation: 2,
        shadowColor: const Color(0x0D000000).withOpacity(0.05),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: secondaryColor,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: 'My Applications'),
            Tab(text: 'Hire Requests'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _initializeUserAndData,
        color: primaryColor,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: primaryColor))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildMyRequestsSection(),
                  _buildViewRequestsSection(),
                ],
              ),
      ),
    );
  }

  Widget _buildMyRequestsSection() {
    const Color primaryColor = Color(0xFF4361EE);
    const Color secondaryColor = Color(0xFF64748B);
    const Color accentColor = Colors.white;

    return _myRequests.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.work_off,
                  size: 64,
                  color: secondaryColor.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'You haven\'t applied to any jobs yet',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: secondaryColor,
                  ),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width * 0.05,
              vertical: MediaQuery.of(context).size.height * 0.02,
            ),
            itemCount: _myRequests.length,
            itemBuilder: (context, index) {
              final application = _myRequests[index];
              final job = application['tbl_job'] as Map<String, dynamic>;
              final filmmaker = job['tbl_filmmakers'] as Map<String, dynamic>;
              final category = job['tbl_category'] as Map<String, dynamic>;
              final status = application['application_status'] == 0
                  ? 'Pending'
                  : application['application_status'] == 1
                      ? 'Accepted'
                      : 'Rejected';
              final statusColor = _getStatusColor(status);
              final statusMessage = _getStatusMessage(application['application_status']);
              final filmmakerId = filmmaker['filmmaker_id']?.toString() ?? '';

              print('Filmmaker ID: $filmmakerId');
              print('User ID: $_userId');

              return Card(
                color: accentColor,
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              job['job_title'] ?? 'Unknown Job',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2D3748),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: statusColor, width: 1),
                            ),
                            child: Text(
                              status,
                              style: GoogleFonts.poppins(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.person, size: 16, color: secondaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Filmmaker: ${filmmaker['filmmaker_name'] ?? 'Unknown'}',
                            style: GoogleFonts.poppins(
                              color: secondaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 16, color: secondaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Location: ${job['job_location'] ?? 'N/A'}',
                            style: GoogleFonts.poppins(
                              color: secondaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.category, size: 16, color: secondaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Category: ${category['category_name'] ?? 'N/A'}',
                            style: GoogleFonts.poppins(
                              color: secondaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.date_range, size: 16, color: secondaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Deadline: ${job['job_lastdate']?.substring(0, 10) ?? 'N/A'}',
                            style: GoogleFonts.poppins(
                              color: secondaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      if (job['job_description'] != null && job['job_description'].isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Text(
                            'Description: ${job['job_description']}',
                            style: GoogleFonts.poppins(
                              color: secondaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: secondaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Applied on: ${application['created_at']?.substring(0, 10) ?? 'N/A'}',
                            style: GoogleFonts.poppins(
                              color: secondaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        statusMessage,
                        style: GoogleFonts.poppins(
                          fontStyle: FontStyle.italic,
                          color: secondaryColor.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                      if (application['application_status'] == 1 && _userId != null && filmmakerId.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => Chat(
                                    filmmakerId: filmmakerId,
                                    userId: _userId!,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: accentColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Chat',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  Widget _buildViewRequestsSection() {
    const Color primaryColor = Color(0xFF4361EE);
    const Color secondaryColor = Color(0xFF64748B);
    const Color accentColor = Colors.white;

    return _viewRequests.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.work_off,
                  size: 64,
                  color: secondaryColor.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'You haven\'t received any requests yet',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: secondaryColor,
                  ),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width * 0.05,
              vertical: MediaQuery.of(context).size.height * 0.02,
            ),
            itemCount: _viewRequests.length,
            itemBuilder: (context, index) {
              final request = _viewRequests[index];
              final user = request['tbl_user'] as Map<String, dynamic>;
              final filmmaker = request['tbl_filmmakers'] as Map<String, dynamic>;
              final status = request['hire_status'] == 0
                  ? 'Pending'
                  : request['hire_status'] == 1
                      ? 'Accepted'
                      : 'Rejected';
              final statusColor = _getStatusColor(status);
              final statusMessage = _getStatusMessage(request['hire_status']);
              final filmmakerId = filmmaker['filmmaker_id']?.toString() ?? '';

              return Card(
                color: accentColor,
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Request from ${filmmaker['filmmaker_name'] ?? 'Unknown'}',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2D3748),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: statusColor, width: 1),
                            ),
                            child: Text(
                              status,
                              style: GoogleFonts.poppins(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.person, size: 16, color: secondaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'From: ${filmmaker['filmmaker_name'] ?? 'Unknown'}',
                            style: GoogleFonts.poppins(
                              color: secondaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 16, color: secondaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Age: ${user['user_age']?.toString() ?? 'N/A'}',
                            style: GoogleFonts.poppins(
                              color: secondaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.wc, size: 16, color: secondaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Gender: ${user['user_gender'] ?? 'N/A'}',
                            style: GoogleFonts.poppins(
                              color: secondaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 16, color: secondaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Contact: ${user['user_contact'] ?? 'N/A'}',
                            style: GoogleFonts.poppins(
                              color: secondaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: secondaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Requested on: ${request['created_at']?.substring(0, 10) ?? 'N/A'}',
                            style: GoogleFonts.poppins(
                              color: secondaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      if (request['hire_message'] != null && request['hire_message'].isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Text(
                            'Message: ${request['hire_message']}',
                            style: GoogleFonts.poppins(
                              color: secondaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        statusMessage,
                        style: GoogleFonts.poppins(
                          fontStyle: FontStyle.italic,
                          color: secondaryColor.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                      if (request['hire_status'] == 1 && _userId != null && filmmakerId.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => Chat(
                                    filmmakerId: filmmakerId,
                                    userId: _userId!,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: accentColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Chat',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
  }
}