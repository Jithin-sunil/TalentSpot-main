// ignore_for_file: unnecessary_null_comparison

import 'package:adminapp/category.dart';
import 'package:adminapp/complaint.dart';
import 'package:adminapp/dashbooardpage.dart';
import 'package:adminapp/filmmakers_page.dart';
import 'package:adminapp/jobs_page.dart';
import 'package:adminapp/movie_promotions_page.dart';
import 'package:adminapp/plans.dart';
import 'package:adminapp/talent_posts_page.dart';
import 'package:adminapp/userpage.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  int _selectedIndex = 0;
  bool _isSidebarExpanded = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final supabase = Supabase.instance.client;
  String _adminName = 'Admin';
  String _adminEmail = '';
  int _unreadNotifications = 0;
  List<Map<String, dynamic>> _notifications = [];

  final List<Map<String, dynamic>> _sidebarItems = [
    {'title': 'Dashboard', 'icon': Icons.dashboard_outlined},
    {'title': 'Users', 'icon': Icons.people_outline},
    {'title': 'Filmmakers', 'icon': Icons.movie_creation_outlined},
    {'title': 'Jobs', 'icon': Icons.work_outline},
    {'title': 'Talent Posts', 'icon': Icons.post_add_outlined},
    {'title': 'Movie Promotions', 'icon': Icons.movie_outlined},
    {'title': 'Complaints', 'icon': Icons.report_problem_outlined},
    {'title': 'Subscription Plans', 'icon': Icons.card_membership_outlined},
    {'title': 'Categories', 'icon': Icons.category_outlined},
  ];

  final List<Widget> _pages = [
    const DashboardPage(),
    const UsersPage(),
    const FilmmakersPage(),
    const JobsPage(),
    const TalentPostsPage(),
    const MoviePromotionsPage(),
    const ComplaintsPage(),
    const SubscriptionPlansPage(),
    const CategoriesPage(),
  ];

  @override
  void initState() {
    super.initState();
    _loadAdminData();
    _fetchNotifications();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final adminData =
            await supabase
                .from('tbl_admin')
                .select('*')
                .eq('id', user.id)
                .single();

        if (adminData != null) {
          setState(() {
            _adminName = (adminData)['admin_name'] ?? 'Admin';
            _adminEmail = (adminData)['admin_email'] ?? user.email ?? '';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading admin data: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF4361EE),
          ),
        );
      }
    }
  }

  Future<void> _fetchNotifications() async {
    try {
      final DateTime now = DateTime.now();
      final DateTime startOfDay = DateTime(now.year, now.month, now.day);
      final DateTime endOfDay = DateTime(
        now.year,
        now.month,
        now.day,
        23,
        59,
        59,
      );

      // Fetch new users
      final usersResponse = await supabase
          .from('tbl_user')
          .select()
          .gte('created_at', startOfDay.toIso8601String())
          .lte('created_at', endOfDay.toIso8601String());

      // Fetch new filmmakers with verification requests
      final filmmakersResponse = await supabase
          .from('tbl_filmmakers')
          .select('*')
          .gte('created_at', startOfDay.toIso8601String())
          .lte('created_at', endOfDay.toIso8601String())
          .eq('flimmaker_status', 0);

      // Fetch new jobs
      final jobsResponse = await supabase
          .from('tbl_job')
          .select()
          .gte('created_at', startOfDay.toIso8601String())
          .lte('created_at', endOfDay.toIso8601String());

      // Fetch new talent posts
      final talentPostsResponse = await supabase
          .from('tbl_talentpost')
          .select()
          .gte('created_at', startOfDay.toIso8601String())
          .lte('created_at', endOfDay.toIso8601String());

      // Fetch new promotions
      final promotionsResponse = await supabase
          .from('tbl_promotion')
          .select()
          .gte('created_at', startOfDay.toIso8601String())
          .lte('created_at', endOfDay.toIso8601String());

      final List<Map<String, dynamic>> notifications = [];

      // Process users
      if (usersResponse != null) {
        for (var user in usersResponse as List) {
          notifications.add({
            'title': 'New User Registered',
            'message': 'User ${user['user_name'] ?? user['user_email']} joined',
            'created_at': user['created_at'],
            'type': 'user',
            'is_read': false,
          });
        }
      }

      // Process filmmakers
      if (filmmakersResponse != null) {
        for (var filmmaker in filmmakersResponse as List) {
          notifications.add({
            'title': 'New Verification Request',
            'message':
                'Filmmaker ${filmmaker['filmmaker_name']} needs verification',
            'created_at': filmmaker['created_at'],
            'type': 'verification_request',
            'is_read': false,
          });
        }
      }

      // Process jobs
      if (jobsResponse != null) {
        for (var job in jobsResponse as List) {
          notifications.add({
            'title': job['job_title'],
            'message': job['job_description'] ?? 'New job posted',
            'created_at': job['created_at'],
            'type': 'job_post',
            'is_read': false,
          });
        }
      }

      // Process talent posts
      if (talentPostsResponse != null) {
        for (var talentPost in talentPostsResponse as List) {
          notifications.add({
            'title': talentPost['post_title'],
            'message': talentPost['post_description'] ?? 'New talent post',
            'created_at': talentPost['created_at'],
            'type': 'talent_post',
            'is_read': false,
          });
        }
      }

      // Process promotions
      if (promotionsResponse != null) {
        for (var promotion in promotionsResponse as List) {
          notifications.add({
            'title': promotion['movie_title'],
            'message': promotion['movie_description'] ?? 'New promotion',
            'created_at': promotion['created_at'],
            'type': 'promotion',
            'is_read': false,
          });
        }
      }

      setState(() {
        _notifications = notifications;
        _unreadNotifications =
            _notifications.length; // All new records are unread
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching notifications: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF4361EE),
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    try {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF4361EE),
          ),
        );
      }
    }
  }

  void _showNotifications() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Notifications'),
            content: SizedBox(
              width: 400,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  return _buildNotificationItem(
                    notification['title'] as String,
                    notification['message'] as String,
                    DateTime.parse(notification['created_at'] as String),
                    isUnread: notification['is_read'] as bool? ?? false,
                    type: notification['type'] as String,
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _notifications =
                        _notifications
                            .map((n) => {...n, 'is_read': true})
                            .toList();
                    _unreadNotifications = 0;
                  });
                  Navigator.pop(context);
                },
                child: const Text('Mark all as read'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _buildNotificationItem(
    String title,
    String message,
    DateTime time, {
    bool isUnread = false,
    String type = '',
  }) {
    String typeLabel = '';
    switch (type) {
      case 'user':
        typeLabel = 'New User';
        break;
      case 'verification_request':
        typeLabel = 'Verification Request';
        break;
      case 'job_post':
        typeLabel = 'New Job Post';
        break;
      case 'talent_post':
        typeLabel = 'New Talent Post';
        break;
      case 'promotion':
        typeLabel = 'Promotion';
        break;
      default:
        typeLabel = 'Notification';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUnread ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUnread ? Colors.blue.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$typeLabel: $title',
                  style: TextStyle(
                    fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if (isUnread)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTime(time),
            style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildSidebar(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _isSidebarExpanded ? 250 : 70,
      color:
          Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[900]
              : Colors.white,
      child: Column(
        children: [
          Container(
            height: 64,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: IconButton(
              icon: Icon(
                _isSidebarExpanded ? Icons.chevron_left : Icons.chevron_right,
                color: const Color(0xFF4361EE),
              ),
              onPressed: () {
                setState(() {
                  _isSidebarExpanded = !_isSidebarExpanded;
                });
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _sidebarItems.length,
              itemBuilder: (context, index) {
                final item = _sidebarItems[index];
                return ListTile(
                  leading: Icon(
                    item['icon'],
                    color:
                        _selectedIndex == index
                            ? const Color(0xFF4361EE)
                            : null,
                  ),
                  title:
                      _isSidebarExpanded
                          ? Text(
                            item['title'],
                            style: TextStyle(
                              fontWeight:
                                  _selectedIndex == index
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                              color:
                                  _selectedIndex == index
                                      ? const Color(0xFF4361EE)
                                      : null,
                            ),
                          )
                          : null,
                  selected: _selectedIndex == index,
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                    });
                    if (MediaQuery.of(context).size.width < 1100) {
                      Navigator.pop(context);
                    }
                  },
                );
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title:
                _isSidebarExpanded
                    ? const Text('Logout', style: TextStyle(color: Colors.red))
                    : null,
            onTap: _logout,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 1100;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text(
          'TalentSpot Admin',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        leading:
            isSmallScreen
                ? IconButton(
                  icon: const Icon(Icons.menu, color: Colors.black),
                  onPressed: () {
                    _scaffoldKey.currentState!.openDrawer();
                  },
                )
                : null,
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined, color: Colors.black),
                if (_unreadNotifications > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _unreadNotifications.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showNotifications,
            tooltip: 'Notifications',
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            offset: const Offset(0, 40),
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 18,
                          color: Colors.black,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _adminName,
                              style: const TextStyle(color: Colors.black),
                            ),
                            Text(
                              _adminEmail,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Logout', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.indigo.shade100,
                    child: Text(
                      _adminName.isNotEmpty ? _adminName[0].toUpperCase() : 'A',
                      style: TextStyle(
                        color: Colors.indigo.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!isSmallScreen) ...[
                    const SizedBox(width: 8),
                    Text(
                      _adminName,
                      style: const TextStyle(color: Colors.black),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.black),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      drawer: isSmallScreen ? _buildSidebar(context) : null,
      body: Row(
        children: [
          if (!isSmallScreen)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _isSidebarExpanded ? 250 : 70,
              child: _buildSidebar(context),
            ),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }
}
