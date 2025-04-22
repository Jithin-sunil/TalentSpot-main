import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talentspotfilmmaker/filmmaker_applications_page.dart';
import 'package:talentspotfilmmaker/filmmaker_jobs_page.dart';
import 'package:talentspotfilmmaker/filmmaker_profile_page.dart';
import 'package:google_fonts/google_fonts.dart';

class FilmmakerDashboardPage extends StatefulWidget {
  const FilmmakerDashboardPage({super.key});

  @override
  State<FilmmakerDashboardPage> createState() => _FilmmakerDashboardPageState();
}

class _FilmmakerDashboardPageState extends State<FilmmakerDashboardPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  int _totalJobs = 0;
  int _activeJobs = 0;
  int _totalPromotions = 0;
  int _totalApplications = 0;
  int _pendingApplications = 0;
  List<Map<String, dynamic>> _recentApplications = [];
  String _userName = '';
  String _profilePic = '';

  // Color scheme from previous context
  static const Color primaryColor = Color(0xFF6750A4); // Rich purple
  static const Color secondaryColor = Color(0xFF625B71); // Muted purple-gra
  static const Color backgroundColor = Color(0xFFF5F5F5); // Grey[100]

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('No user ID found');
        return;
      }

      final userData =
          await supabase
              .from('tbl_user')
              .select('user_name, user_photo')
              .eq('user_id', userId)
              .single();

      if (mounted) {
        setState(() {
          _userName = userData['user_name'] ?? '';
          _profilePic = userData['user_photo'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('No user ID found');
        return;
      }

      // Get total jobs count by fetching all jobs and counting
      final jobsResponse = await supabase
          .from('Jobs')
          .select('job_id')
          .eq('filmmaker_id', userId);

      // Get active jobs count by fetching filtered jobs and counting
      final activeJobsResponse = await supabase
          .from('Jobs')
          .select('job_id')
          .eq('filmmaker_id', userId)
          .eq('status', 'open');

      // Get promotions count by fetching all promotions and counting
      final promotionsResponse = await supabase
          .from('Movie_Promotions')
          .select('promotion_id')
          .eq('filmmaker_id', userId);

      // Get applications count and pending applications by fetching all applications
      final applicationsResponse = await supabase
          .from('Job_Applications')
          .select('application_id, status')
          .eq('Jobs.filmmaker_id', userId)
          .order('applied_at', ascending: false);

      // Get recent applications
      final recentAppsResponse = await supabase
          .from('Job_Applications')
          .select('''
            *,
            Jobs:job_id (title),
            Users:user_id (name, profile_pic)
          ''')
          .eq('Jobs.filmmaker_id', userId)
          .order('applied_at', ascending: false)
          .limit(5);

      if (mounted) {
        setState(() {
          _totalJobs = jobsResponse.length;
          _activeJobs = activeJobsResponse.length;
          _totalPromotions = promotionsResponse.length;
          _totalApplications = applicationsResponse.length;
          _pendingApplications =
              applicationsResponse.isNotEmpty
                  ? (applicationsResponse as List)
                      .where((app) => app['status'] == 'pending')
                      .length
                  : 0;
          _recentApplications = List<Map<String, dynamic>>.from(
            recentAppsResponse,
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _totalJobs = 0;
          _activeJobs = 0;
          _totalPromotions = 0;
          _totalApplications = 0;
          _pendingApplications = 0;
          _recentApplications = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : RefreshIndicator(
                onRefresh: _loadDashboardData,
                color: primaryColor,
                child: CustomScrollView(
                  slivers: [
                    _buildSliverAppBar(),
                    SliverToBoxAdapter(child: SizedBox(height: 24)),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildWelcomeSection(),
                          SizedBox(height: 24),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              _buildStatCard(
                                'Total Jobs',
                                _totalJobs,
                                Icons.work,
                                primaryColor,
                              ),
                              _buildStatCard(
                                'Active Jobs',
                                _activeJobs,
                                Icons.work_outline,
                                Colors.green,
                              ),
                              _buildStatCard(
                                'Promotions',
                                _totalPromotions,
                                Icons.movie,
                                secondaryColor,
                              ),
                              _buildStatCard(
                                'Applications',
                                _totalApplications,
                                Icons.people,
                                Colors.orange,
                              ),
                            ],
                          ),
                          SizedBox(height: 32),
                          _buildQuickAccessSection(),
                          SizedBox(height: 32),
                          _buildRecentApplicationsSection(),
                          SizedBox(height: 32),
                          _buildFeaturedContent(),
                          SizedBox(height: 24),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryColor, secondaryColor],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'TalentSpot',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Filmmaker Dashboard',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      // Navigate to profile page
                    },
                    child: CircleAvatar(
                      radius: 30,
                      backgroundImage:
                          _profilePic.isNotEmpty
                              ? NetworkImage(_profilePic)
                              : null,
                      child:
                          _profilePic.isEmpty
                              ? Icon(
                                Icons.person,
                                size: 30,
                                color: Colors.white,
                              )
                              : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.logout, color: Colors.white),
          onPressed: () async {
            await supabase.auth.signOut();
            // Navigate to login page
          },
        ),
      ],
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome Back, $_userName!',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Manage your projects and talent applications',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: secondaryColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 20, color: primaryColor),
        ],
      ),
    );
  }

  Widget _buildQuickAccessSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Access',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildQuickAccessButton(
              'Jobs',
              Icons.work,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FilmmakerJobsPage()),
              ),
              Colors.green,
            ),
            _buildQuickAccessButton(
              'Promotions',
              Icons.movie,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FilmmakerProfilePage()),
              ),
              Colors.purple,
            ),
            _buildQuickAccessButton(
              'Applications',
              Icons.people,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FilmmakerApplicationsPage(),
                ),
              ),
              Colors.orange,
            ),
            _buildQuickAccessButton('Analytics', Icons.bar_chart, () {
              // Navigate to analytics page
            }, Colors.blue),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAccessButton(
    String label,
    IconData icon,
    VoidCallback onTap,
    Color color,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: secondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentApplicationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Applications',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FilmmakerApplicationsPage(),
                  ),
                );
              },
              child: Text(
                'View All',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        _recentApplications.isEmpty
            ? Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: Center(
                child: Text(
                  'No applications yet',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: secondaryColor.withOpacity(0.7),
                  ),
                ),
              ),
            )
            : ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _recentApplications.length,
              itemBuilder: (context, index) {
                final application = _recentApplications[index];
                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundImage:
                          application['Users'] != null &&
                                  application['Users']['profile_pic'] != null
                              ? NetworkImage(
                                application['Users']['profile_pic'],
                              )
                              : null,
                      child:
                          application['Users'] == null ||
                                  application['Users']['profile_pic'] == null
                              ? Icon(Icons.person)
                              : null,
                    ),
                    title: Text(
                      application['Users'] != null
                          ? application['Users']['name'] ?? 'Unknown'
                          : 'Unknown',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      application['Jobs'] != null
                          ? application['Jobs']['title'] ?? 'Unknown Job'
                          : 'Unknown Job',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    trailing: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(
                          application['status'] ?? 'pending',
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        application['status'] ?? 'Pending',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => FilmmakerApplicationDetailPage(
                                application: application,
                              ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      ],
    );
  }

  Widget _buildFeaturedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildFeaturedCard(
                'Post New Job',
                'Create Job',
                Colors.green,
                () {
                  // Navigate to create job page
                },
              ),
              SizedBox(width: 16),
              _buildFeaturedCard(
                'Add Movie Promotion',
                'Create Promotion',
                Colors.purple,
                () {
                  // Navigate to create promotion page
                },
              ),
              SizedBox(width: 16),
              _buildFeaturedCard(
                'Review Applications',
                'View Pending ($_pendingApplications)',
                Colors.orange,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FilmmakerApplicationsPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedCard(
    String title,
    String action,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      width: 250,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              action,
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int value, IconData icon, Color color) {
    return SizedBox(
      width: 200,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              SizedBox(height: 12),
              Text(
                value.toString(),
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              SizedBox(height: 4),
              Text(
                title,
                style: GoogleFonts.poppins(fontSize: 14, color: secondaryColor),
              ),
            ],
          ),
        ),
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
}

// Placeholder for FilmmakerApplicationDetailPage
class FilmmakerApplicationDetailPage extends StatelessWidget {
  final Map<String, dynamic> application;

  const FilmmakerApplicationDetailPage({super.key, required this.application});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Application Details')),
      body: Center(child: Text('Application Detail Placeholder')),
    );
  }
}
