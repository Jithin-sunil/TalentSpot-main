import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talentspotfilmmaker/applicationdetails.dart';
import 'package:talentspotfilmmaker/chat.dart'; // Import the Chat page
import 'package:talentspotfilmmaker/filmmaker_home_page.dart';
import 'package:talentspotfilmmaker/filmmaker_jobs_page.dart';
import 'package:talentspotfilmmaker/filmmaker_profile_page.dart';
import 'package:talentspotfilmmaker/filmmaker_promotions_page.dart';
import 'package:talentspotfilmmaker/filmmaker_talent_search_page.dart';
import 'package:talentspotfilmmaker/login.dart';
import 'package:video_player/video_player.dart';

// Extension to add capitalize method to String
extension StringExtension on String {
  String capitalize() => "${this[0].toUpperCase()}${substring(1)}";
}

class FilmmakerApplicationsPage extends StatefulWidget {
  const FilmmakerApplicationsPage({super.key});

  @override
  State<FilmmakerApplicationsPage> createState() =>
      _FilmmakerApplicationsPageState();
}

class _FilmmakerApplicationsPageState extends State<FilmmakerApplicationsPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _jobApplications = [];
  List<Map<String, dynamic>> _myRequests = [];
  bool _isLoading = true;
  late TabController _tabController;

  // Define colors statically
  static const Color primaryColor = Color(0xFF4361EE); // Blue
  static const Color secondaryColor = Color(0xFF64748B); // Gray
  static const Color accentColor = Colors.white; // White
  static const Color backgroundColor = Color(0xFFF8F9FA); // Light Gray

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchApplications();
    _fetchMyRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchApplications() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await supabase
          .from('tbl_jobapplication')
          .select('''
            id,
            created_at,
            job_id,
            user_id,
            application_status,
            apply_date,
            bio_data,
            demo_video,
            tbl_job:job_id (
              job_id,
              created_at,
              job_title,
              job_description,
              job_amount,
              job_location,
              job_lastdate,
              filmmaker_id,
              job_status
            ),
            tbl_user:user_id (
              user_id,
              user_name,
              user_photo
            )
          ''')
          .eq('tbl_job.filmmaker_id', userId);

      if (mounted) {
        setState(() {
          _jobApplications = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching applications: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMyRequests() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await supabase
          .from('tbl_hire')
          .select('''
            hire_id,
            filmmaker_id,
            user_id,
            created_at,
            hire_status,
            hire_message,
            tbl_user (
              user_id,
              user_name,
              user_photo,
              user_age,
              user_gender,
              user_contact
            )
          ''')
          .eq('filmmaker_id', userId);

      if (mounted) {
        setState(() {
          _myRequests = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Error fetching my requests: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Applications & Requests',
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
          tabs: [Tab(text: 'View Job Requests'), Tab(text: 'My Requests')],
        ),
      ),
      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: () async {
          await _fetchApplications();
          await _fetchMyRequests();
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.05,
            vertical: MediaQuery.of(context).size.height * 0.02,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.85,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildJobApplicationsSection(),
                    _buildMyRequestsSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobApplicationsSection() {
    return _isLoading
        ? Center(child: CircularProgressIndicator(color: primaryColor))
        : _jobApplications.isEmpty
        ? Center(
          child: Text(
            'No job applications available',
            style: GoogleFonts.poppins(
              fontSize: MediaQuery.of(context).size.width < 600 ? 14 : 16,
              color: secondaryColor,
            ),
          ),
        )
        : ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _jobApplications.length,
          itemBuilder: (context, index) {
            final application = _jobApplications[index];
            final user = application['tbl_user'] as Map<String, dynamic>;
            final job = application['tbl_job'] as Map<String, dynamic>;
            final status =
                application['application_status'] == 0
                    ? 'Pending'
                    : application['application_status'] == 1
                    ? 'Accepted'
                    : 'Rejected';
            final filmmakerId = supabase.auth.currentUser?.id;
            final userId = application['user_id'];

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            ApplicationDetailPage(application: application),
                  ),
                ).then((_) => _fetchApplications());
              },
              child: Container(
                margin: EdgeInsets.only(
                  bottom: MediaQuery.of(context).size.height * 0.02,
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
                      color: accentColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user['user_name'] ?? 'Unknown Applicant',
                                style: GoogleFonts.poppins(
                                  fontSize:
                                      MediaQuery.of(context).size.width < 600
                                          ? 16
                                          : 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.01,
                              ),
                              _buildDetailRow('Job', job['job_title'] ?? 'N/A'),
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.01,
                              ),
                              _buildDetailRow(
                                'Applied',
                                application['apply_date'].toString().substring(
                                      0,
                                      10,
                                    ) ??
                                    'N/A',
                              ),
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.01,
                              ),
                              _buildDetailRow('Status', status),
                            ],
                          ),
                        ),
                        if (application['application_status'] == 1)
                          IconButton(
                            icon: Icon(Icons.chat, color: primaryColor),
                            onPressed: () {
                              if (filmmakerId != null && userId != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => Chat(
                                          filmmakerId: filmmakerId,
                                          userId: userId,
                                        ),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Unable to start chat: Invalid IDs',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
  }

  Widget _buildMyRequestsSection() {
    return _isLoading
        ? Center(child: CircularProgressIndicator(color: primaryColor))
        : _myRequests.isEmpty
        ? Center(
          child: Text(
            'No requests available',
            style: GoogleFonts.poppins(
              fontSize: MediaQuery.of(context).size.width < 600 ? 14 : 16,
              color: secondaryColor,
            ),
          ),
        )
        : ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _myRequests.length,
          itemBuilder: (context, index) {
            final request = _myRequests[index];
            final user = request['tbl_user'] as Map<String, dynamic>;
            final status =
                request['hire_status'] == 0
                    ? 'Pending'
                    : request['hire_status'] == 1
                    ? 'Accepted'
                    : 'Rejected';
            final filmmakerId = supabase.auth.currentUser?.id;
            final userId = request['user_id'];

            return Container(
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height * 0.02,
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
                    color: accentColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['user_name'] ?? 'Unknown User',
                              style: GoogleFonts.poppins(
                                fontSize:
                                    MediaQuery.of(context).size.width < 600
                                        ? 16
                                        : 18,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.01,
                            ),
                            _buildDetailRow('Name', user['user_name'] ?? 'N/A'),
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.01,
                            ),
                            _buildDetailRow(
                              'Age',
                              user['user_age']?.toString() ?? 'N/A',
                            ),
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.01,
                            ),
                            _buildDetailRow(
                              'Gender',
                              user['user_gender'] ?? 'N/A',
                            ),
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.01,
                            ),
                            _buildDetailRow(
                              'Contact',
                              user['user_contact'] ?? 'N/A',
                            ),
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.01,
                            ),
                            _buildDetailRow(
                              'Requested',
                              request['created_at'].toString().substring(
                                    0,
                                    10,
                                  ) ??
                                  'N/A',
                            ),
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.01,
                            ),
                            _buildDetailRow('Status', status),
                            if (request['hire_message'] != null &&
                                request['hire_message'].isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(
                                  top:
                                      MediaQuery.of(context).size.height * 0.01,
                                ),
                                child: _buildDetailRow(
                                  'Message',
                                  request['hire_message'],
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (request['hire_status'] == 1)
                        IconButton(
                          icon: Icon(Icons.chat, color: primaryColor),
                          onPressed: () {
                            if (filmmakerId != null && userId != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => Chat(
                                        filmmakerId: filmmakerId,
                                        userId: userId,
                                      ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Unable to start chat: Invalid IDs',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
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
            color: primaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(width: MediaQuery.of(context).size.width * 0.02),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
              color: secondaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
