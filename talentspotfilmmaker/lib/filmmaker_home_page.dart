import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:talentspotfilmmaker/filmmaker_applications_page.dart';
import 'package:talentspotfilmmaker/filmmaker_jobs_page.dart';
import 'package:talentspotfilmmaker/filmmaker_profile_page.dart';
import 'package:talentspotfilmmaker/filmmaker_promotions_page.dart';
import 'package:talentspotfilmmaker/filmmaker_talent_search_page.dart';
import 'package:talentspotfilmmaker/login.dart';

class FilmmakerHomePage extends StatefulWidget {
  const FilmmakerHomePage({super.key});

  @override
  State<FilmmakerHomePage> createState() => _FilmmakerHomePageState();
}

class _FilmmakerHomePageState extends State<FilmmakerHomePage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  String _userName = '';
  String _profilePic = '';
  bool _isLoading = true;
  int _selectedIndex = 0;
  late TabController _tabController;

  // State for dynamic data
  Map<String, int> _stats = {};
  List<Map<String, dynamic>> _talentPosts = [];
  List<Map<String, dynamic>> _jobApplications = [];
  List<Map<String, dynamic>> _promotions = [];

  @override
  void initState() {
    super.initState();
    try {
      _tabController = TabController(length: 2, vsync: this);
      _loadUserData();
      _fetchDashboardData();
    } catch (e) {
      debugPrint('Error initializing tab controller or data: $e');
      // Always keep length 2 to match TabBar and TabBarView
      _tabController = TabController(length: 2, vsync: this);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
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
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDashboardData() async {
    try {
      final userId = supabase.auth.currentUser!.id;

      // Fetch stats
      final activeJobs = await supabase
          .from('tbl_job')
          .select()
          .eq('filmmaker_id', userId)
          .eq('job_status', 1);
      final List<int> jobIds =
          activeJobs
              .where((job) => job['job_id'] != null)
              .map((job) => job['job_id'] as int)
              .toList();
      final allApplications =
          await supabase.from('tbl_jobapplication').select();
      final applications =
          jobIds.isNotEmpty
              ? allApplications
                  .where((app) => jobIds.contains(app['job_id'] as int))
                  .toList()
              : [];
      final hiredTalents =
          0; // Requires additional logic to determine hired status
      final promotions = await supabase
          .from('tbl_promotion')
          .select()
          .eq('filmmaker_id', userId)
          .eq('movie_status', 1);

      setState(() {
        _stats = {
          'Active Jobs': activeJobs.length,
          'Applications': applications.length,
          'Hired Talents': hiredTalents,
          'Promotions': promotions.length,
        };
      });

      // Fetch talent posts
      final talentPosts = await supabase
          .from('tbl_talentpost')
          .select()
          .order('created_at', ascending: false)
          .limit(5);
      setState(() {
        _talentPosts =
            talentPosts
                .map(
                  (tp) => {
                    'title': tp['post_title'],
                    'description': tp['post_description'],
                    'image': tp['post_file'],
                    'tags': tp['post_tags'],
                    'status': tp['post_status'] == 1 ? 'Active' : 'Inactive',
                    'posted': _formatTimeAgo(tp['created_at']),
                  },
                )
                .toList();
      });

      // Fetch job applications
      final jobApplications = await supabase
          .from('tbl_jobapplication')
          .select('*, tbl_job(*)')
          .eq('tbl_job.filmmaker_id', userId)
          .order('created_at', ascending: false)
          .limit(5);
      setState(() {
        _jobApplications =
            jobApplications
                .map(
                  (ja) => {
                    'id': ja['id'],
                    'user_id': ja['user_id'],
                    'status':
                        ja['application_status'] == 0 ? 'Pending' : 'Accepted',
                    'apply_date': _formatTimeAgo(ja['apply_date']),
                    'bio_data': ja['bio_data'],
                    'demo_video': ja['demo_video'],
                  },
                )
                .toList();
      });

      // Fetch promotions (optional, can be removed if not needed)
      final promos = await supabase
          .from('tbl_promotion')
          .select()
          .eq('filmmaker_id', userId)
          .order('created_at', ascending: false)
          .limit(5);
      setState(() {
        _promotions =
            promos
                .map(
                  (p) => {
                    'title': p['movie_title'],
                    'type': p['movie_description'],
                    'views': 0, // Requires additional logic to track views
                    'status': p['movie_status'] == 1 ? 'Active' : 'Ended',
                    'posted': _formatTimeAgo(p['created_at']),
                  },
                )
                .toList();
      });
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
    }
  }

  String _formatTimeAgo(String createdAt) {
    final date = DateTime.parse(createdAt);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) return '${difference.inDays ~/ 7} weeks ago';
    if (difference.inDays > 0) return '${difference.inDays} days ago';
    if (difference.inHours > 0) return '${difference.inHours} hours ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes} minutes ago';
    return 'just now';
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const FilmmakerLoginPage()),
    );
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 1: // Jobs
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FilmmakerJobsPage()),
        );
        break;
      case 2: // Promotions
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PromotionsPage()),
        );
        break;
      case 3: // Profile
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FilmmakerProfilePage()),
        );
        break;
    }

    if (index != 0) {
      setState(() {
        _selectedIndex = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF4361EE)),
              )
              : SafeArea(
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: RefreshIndicator(
                        color: const Color(0xFF4361EE),
                        onRefresh: () async {
                          setState(() => _isLoading = true);
                          await _loadUserData();
                          await _fetchDashboardData();
                          setState(() => _isLoading = false);
                        },
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20),
                              _buildDashboardStats(),
                              const SizedBox(height: 24),
                              _buildQuickActions(),
                              const SizedBox(height: 24),
                              // _buildTabSection(),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D3748),
                ),
              ),
              Text(
                'Welcome back to TalentSpot',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          Row(
            children: [
              // IconButton(
              //   icon: const Icon(
              //     Icons.notifications_outlined,
              //     color: Color(0xFF4361EE),
              //   ),
              //   onPressed: () {},
              // ),
              const SizedBox(width: 8),
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
                  radius: 20,
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

  Widget _buildDashboardStats() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing:
            MediaQuery.of(context).size.width * 0.03, // 3% of screen width
        mainAxisSpacing:
            MediaQuery.of(context).size.width * 0.03, // 3% of screen width
        childAspectRatio:
            MediaQuery.of(context).size.width < 600
                ? 1.2 // Adjusted for smaller screens (e.g., phones)
                : 1.5, // Default for larger screens (e.g., tablets)
      ),
      itemCount: _stats.length,
      itemBuilder: (context, index) {
        final entry = _stats.entries.elementAt(index);
        Color cardColor;
        IconData iconData;

        switch (index) {
          case 0:
            cardColor = const Color(0xFF4361EE);
            iconData = Icons.work_outline_rounded;
            break;
          case 1:
            cardColor = const Color(0xFF3A0CA3);
            iconData = Icons.people_outline_rounded;
            break;
          case 2:
            cardColor = const Color(0xFFF72585);
            iconData = Icons.person_add_alt_1_rounded;
            break;
          case 3:
            cardColor = const Color(0xFF4CC9F0);
            iconData = Icons.movie_outlined;
            break;
          default:
            cardColor = const Color(0xFF4361EE);
            iconData = Icons.work_outline_rounded;
        }

        return Container(
          padding: EdgeInsets.all(
            MediaQuery.of(context).size.width * 0.03,
          ), // 3% of screen width
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
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(
                  MediaQuery.of(context).size.width * 0.02,
                ), // 2% of screen width
                decoration: BoxDecoration(
                  color: cardColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  iconData,
                  color: cardColor,
                  size: MediaQuery.of(context).size.width * 0.05,
                ), // 5% of screen width
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.value.toString(),
                    style: GoogleFonts.poppins(
                      fontSize:
                          MediaQuery.of(context).size.width < 600
                              ? 20 // Reduced for smaller screens
                              : 24, // Default for larger screens
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2D3748),
                    ),
                  ),
                  Text(
                    entry.key,
                    style: GoogleFonts.poppins(
                      fontSize:
                          MediaQuery.of(context).size.width < 600
                              ? 12 // Reduced for smaller screens
                              : 14, // Default for larger screens
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.poppins(
            fontSize:
                MediaQuery.of(context).size.width < 600
                    ? 16 // Reduced for smaller screens
                    : 18, // Default for larger screens
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D3748),
          ),
        ),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.02,
        ), // 2% of screen height
        Wrap(
          spacing:
              MediaQuery.of(context).size.width * 0.03, // 3% of screen width
          runSpacing:
              MediaQuery.of(context).size.height * 0.01, // 1% of screen height
          alignment: WrapAlignment.center,
          children: [
            _buildActionButton(
              'Post Job',
              Icons.add_circle_outline_rounded,
              const Color(0xFF4361EE),
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FilmmakerJobsPage(),
                ),
              ),
            ),
            _buildActionButton(
              'Add Promotion',
              Icons.movie_filter_outlined,
              const Color(0xFFF72585),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PromotionsPage()),
              ),
            ),
            _buildActionButton(
              'View Feeds',
              Icons.search_rounded,
              const Color(0xFF3A0CA3),
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FilmmakerTalentFeedPage(),
                ),
              ),
            ),
            _buildActionButton(
              'View Applications',
              Icons.chat_bubble_outline_rounded,
              const Color(0xFF4CC9F0),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FilmmakerApplicationsPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width:
                MediaQuery.of(context).size.width * 0.12, // 12% of screen width
            height:
                MediaQuery.of(context).size.width * 0.12, // 12% of screen width
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(
                MediaQuery.of(context).size.width * 0.02,
              ), // 2% of screen width
            ),
            child: Icon(
              icon,
              color: color,
              size: MediaQuery.of(context).size.width * 0.07,
            ), // 7% of screen width
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.01,
          ), // 1% of screen height
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize:
                  MediaQuery.of(context).size.width < 600
                      ? 10 // Reduced for smaller screens
                      : 12, // Default for larger screens
              fontWeight: FontWeight.w500,
              color: const Color(0xFF2D3748),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Widget _buildTabSection() {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Container(
  //         decoration: BoxDecoration(
  //           color: Colors.white,
  //           borderRadius: BorderRadius.circular(16),
  //           boxShadow: [
  //             BoxShadow(
  //               color: Colors.black.withOpacity(0.05),
  //               blurRadius: 10,
  //               offset: const Offset(0, 4),
  //             ),
  //           ],
  //         ),
  //         child: Column(
  //           children: [
  //             TabBar(
  //               controller: _tabController,
  //               labelColor: const Color(0xFF4361EE),
  //               unselectedLabelColor: const Color(0xFF64748B),
  //               indicatorColor: const Color(0xFF4361EE),
  //               indicatorSize: TabBarIndicatorSize.tab,
  //               labelStyle: GoogleFonts.poppins(
  //                 fontSize: 14,
  //                 fontWeight: FontWeight.w600,
  //               ),
  //               unselectedLabelStyle: GoogleFonts.poppins(
  //                 fontSize: 14,
  //                 fontWeight: FontWeight.w500,
  //               ),
  //               tabs: const [
  //                 Tab(text: 'Talent Posts'),
  //                 Tab(text: 'Job Applications'),
  //               ],
  //             ),
  //             SizedBox(
  //               height: 300,
  //               child: TabBarView(
  //                 controller: _tabController,
  //                 children: [
  //                   _buildTalentPostsTab(),
  //                   _buildJobApplicationsTab(),
  //                 ],
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ],
  //   );
  // }

  // Widget _buildTalentPostsTab() {
  //   return ListView.separated(
  //     padding: const EdgeInsets.all(16),
  //     itemCount: _talentPosts.length,
  //     separatorBuilder: (context, index) => const SizedBox(height: 16),
  //     itemBuilder: (context, index) {
  //       final post = _talentPosts[index];
  //       final bool isActive = post['status'] == 'Active';

  //       return Container(
  //         padding: const EdgeInsets.all(16),
  //         decoration: BoxDecoration(
  //           color: Colors.white,
  //           borderRadius: BorderRadius.circular(12),
  //           border: Border.all(color: const Color(0xFFE2E8F0)),
  //         ),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Row(
  //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //               children: [
  //                 Text(
  //                   post['title'],
  //                   style: GoogleFonts.poppins(
  //                     fontSize: 16,
  //                     fontWeight: FontWeight.w600,
  //                     color: const Color(0xFF2D3748),
  //                   ),
  //                 ),
  //                 Container(
  //                   padding: const EdgeInsets.symmetric(
  //                     horizontal: 8,
  //                     vertical: 4,
  //                   ),
  //                   decoration: BoxDecoration(
  //                     color:
  //                         isActive
  //                             ? const Color(0xFF4CC9F0).withOpacity(0.1)
  //                             : const Color(0xFF64748B).withOpacity(0.1),
  //                     borderRadius: BorderRadius.circular(4),
  //                   ),
  //                   child: Text(
  //                     post['status'],
  //                     style: GoogleFonts.poppins(
  //                       fontSize: 12,
  //                       fontWeight: FontWeight.w500,
  //                       color:
  //                           isActive
  //                               ? const Color(0xFF4CC9F0)
  //                               : const Color(0xFF64748B),
  //                     ),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //             const SizedBox(height: 8),
  //             Text(
  //               post['description'],
  //               style: GoogleFonts.poppins(
  //                 fontSize: 13,
  //                 color: const Color(0xFF64748B),
  //               ),
  //             ),
  //             const SizedBox(height: 8),
  //             if (post['image'] != null && post['image'].isNotEmpty)
  //               CachedNetworkImage(
  //                 imageUrl: post['image'],
  //                 placeholder:
  //                     (context, url) => const CircularProgressIndicator(),
  //                 errorWidget: (context, url, error) => const Icon(Icons.error),
  //                 height: 100,
  //                 width: double.infinity,
  //                 fit: BoxFit.cover,
  //               ),
  //             const SizedBox(height: 12),
  //             Row(
  //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //               children: [
  //                 Text(
  //                   'Tags: ${post['tags'] ?? 'None'}',
  //                   style: GoogleFonts.poppins(
  //                     fontSize: 12,
  //                     color: const Color(0xFF94A3B8),
  //                   ),
  //                 ),
  //                 Text(
  //                   'Posted ${post['posted']}',
  //                   style: GoogleFonts.poppins(
  //                     fontSize: 12,
  //                     color: const Color(0xFF94A3B8),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }

  // Widget _buildJobApplicationsTab() {
  //   return ListView.separated(
  //     padding: const EdgeInsets.all(16),
  //     itemCount: _jobApplications.length,
  //     separatorBuilder: (context, index) => const SizedBox(height: 16),
  //     itemBuilder: (context, index) {
  //       final application = _jobApplications[index];
  //       final bool isPending = application['status'] == 'Pending';

  //       return Container(
  //         padding: const EdgeInsets.all(16),
  //         decoration: BoxDecoration(
  //           color: Colors.white,
  //           borderRadius: BorderRadius.circular(12),
  //           border: Border.all(color: const Color(0xFFE2E8F0)),
  //         ),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Row(
  //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //               children: [
  //                 Text(
  //                   'Application #${application['id']}',
  //                   style: GoogleFonts.poppins(
  //                     fontSize: 16,
  //                     fontWeight: FontWeight.w600,
  //                     color: const Color(0xFF2D3748),
  //                   ),
  //                 ),
  //                 Container(
  //                   padding: const EdgeInsets.symmetric(
  //                     horizontal: 8,
  //                     vertical: 4,
  //                   ),
  //                   decoration: BoxDecoration(
  //                     color:
  //                         isPending
  //                             ? const Color(0xFFF72585).withOpacity(0.1)
  //                             : const Color(0xFF4CAF50).withOpacity(0.1),
  //                     borderRadius: BorderRadius.circular(4),
  //                   ),
  //                   child: Text(
  //                     application['status'],
  //                     style: GoogleFonts.poppins(
  //                       fontSize: 12,
  //                       fontWeight: FontWeight.w500,
  //                       color:
  //                           isPending
  //                               ? const Color(0xFFF72585)
  //                               : const Color(0xFF4CAF50),
  //                     ),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //             const SizedBox(height: 8),
  //             Text(
  //               'User ID: ${application['user_id']}',
  //               style: GoogleFonts.poppins(
  //                 fontSize: 13,
  //                 color: const Color(0xFF64748B),
  //               ),
  //             ),
  //             const SizedBox(height: 8),
  //             if (application['bio_data'] != null &&
  //                 application['bio_data'].isNotEmpty)
  //               Text(
  //                 'Bio Data: ${application['bio_data'].split('/').last}',
  //                 style: GoogleFonts.poppins(
  //                   fontSize: 12,
  //                   color: const Color(0xFF94A3B8),
  //                 ),
  //               ),
  //             if (application['demo_video'] != null &&
  //                 application['demo_video'].isNotEmpty)
  //               Text(
  //                 'Demo Video: ${application['demo_video'].split('/').last}',
  //                 style: GoogleFonts.poppins(
  //                   fontSize: 12,
  //                   color: const Color(0xFF94A3B8),
  //                 ),
  //               ),
  //             const SizedBox(height: 12),
  //             Row(
  //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //               children: [
  //                 Text(
  //                   'Applied ${application['apply_date']}',
  //                   style: GoogleFonts.poppins(
  //                     fontSize: 12,
  //                     color: const Color(0xFF94A3B8),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
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
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
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
}
