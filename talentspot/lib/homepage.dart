import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talentspot/complaint.dart';
import 'package:talentspot/feedpage.dart';
import 'package:talentspot/jobopertunities.dart';
import 'package:talentspot/login.dart';
import 'package:talentspot/moviepromotion.dart';
import 'package:talentspot/myapplication.dart';
import 'package:talentspot/mypost.dart';
import 'package:talentspot/plan.dart';
import 'package:talentspot/profile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;
  String _userName = '';
  String _profilePic = '';
  int _userStatus = 1; // Default to 1, updated from DB
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        await _signOut();
        return;
      }

      final userData = await supabase
          .from('tbl_user')
          .select('user_name, user_photo, user_status')
          .eq('user_id', userId)
          .single();

      if (mounted) {
        setState(() {
          _userName = userData['user_name'] ?? '';
          _profilePic = userData['user_photo'] ?? '';
          _userStatus = userData['user_status'] ?? 1;
          _isLoading = false;
        });

        // Show subscription dialog if user_status is 0
        if (_userStatus == 0) {
          _showSubscriptionDialog();
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load user data')),
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

  void _showSubscriptionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) => AlertDialog(
        title: Text(
          'Subscription Required',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D3748),
          ),
        ),
        content: Text(
          'Please subscribe to access full features.',
          style: GoogleFonts.poppins(
            color: const Color(0xFF64748B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SubscriptionPlansPage()),
              );
            },
            child: Text(
              'Subscribe',
              style: GoogleFonts.poppins(
                color: const Color(0xFF4361EE),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToSubscription() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SubscriptionPlansPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF4361EE);
    const Color secondaryColor = Color(0xFF64748B);
    const Color accentColor = Colors.white;
    const Color backgroundColor = Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        color: primaryColor,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: primaryColor))
            : CustomScrollView(
                slivers: [
                  _buildSliverAppBar(),
                  SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildWelcomeSection(),
                        SizedBox(height: 32),
                        _buildQuickAccessSection(),
                        SizedBox(height: 32),
                        _buildFeaturedContent(),
                      ]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar() {
    const Color primaryColor = Color(0xFF4361EE);
    const Color accentColor = Colors.white;

    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4361EE), Color(0xFF64748B)],
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
                          color: accentColor,
                        ),
                      ),
                      Text(
                        'Discover Your Potential',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: accentColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AccountPage()),
                      );
                    },
                    child: CircleAvatar(
                      radius: 30,
                      backgroundImage: _profilePic.isNotEmpty
                          ? NetworkImage(_profilePic)
                          : null,
                      backgroundColor: _profilePic.isEmpty ? Colors.grey[300] : null,
                      child: _profilePic.isEmpty
                          ? Icon(Icons.person, size: 30, color: accentColor)
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
          icon: Icon(Icons.refresh, color: accentColor),
          onPressed: _loadUserData,
          tooltip: 'Reload',
        ),
        IconButton(
          icon: Icon(Icons.subscriptions, color: accentColor),
          onPressed: _navigateToSubscription,
          tooltip: 'Subscription Plans',
        ),
        IconButton(
          icon: Icon(Icons.logout, color: accentColor),
          onPressed: _signOut,
          tooltip: 'Sign Out',
        ),
      ],
    );
  }

  Widget _buildWelcomeSection() {
    const Color primaryColor = Color(0xFF4361EE);
    const Color secondaryColor = Color(0xFF64748B);
    const Color accentColor = Colors.white;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accentColor,
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
                    color: const Color(0xFF2D3748),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Ready to explore new opportunities today?',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: secondaryColor,
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
    const Color primaryColor = Color(0xFF4361EE);
    const Color secondaryColor = Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Access',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D3748),
          ),
        ),
        SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildQuickAccessButton(
              'Feeds',
              Icons.feed,
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => FeedPage())),
              Colors.blueAccent,
            ),
            _buildQuickAccessButton(
              'Jobs',
              Icons.work,
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => JobListPage())),
              Colors.green,
            ),
            _buildQuickAccessButton(
              'Movies',
              Icons.movie,
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => MoviePromotionsPage())),
              Colors.purple,
            ),
            _buildQuickAccessButton(
              'Posts',
              Icons.post_add,
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => MyPostsPage())),
              Colors.orange,
            ),
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
              color: const Color(0xFF2D3748),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedContent() {
    const Color primaryColor = Color(0xFF4361EE);
    const Color accentColor = Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Featured For You',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D3748),
          ),
        ),
        SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildFeaturedCard(
                'Latest Job Openings',
                'Apply Now',
                Colors.blue,
                () => Navigator.push(context, MaterialPageRoute(builder: (context) => JobListPage())),
              ),
              SizedBox(width: 16),
              _buildFeaturedCard(
                'New Movie Releases',
                'Watch Trailer',
                Colors.purple,
                () => Navigator.push(context, MaterialPageRoute(builder: (context) => MoviePromotionsPage())),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedCard(String title, String action, Color color, VoidCallback onTap) {
    const Color accentColor = Colors.white;

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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              action,
              style: GoogleFonts.poppins(color: accentColor),
            ),
          ),
        ],
      ),
    );
  }
}