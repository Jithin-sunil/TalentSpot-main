// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;

  // Dashboard stats
  int _totalUsers = 0;
  int _totalFilmmakers = 0;
  int _totalJobs = 0;
  int _totalPosts = 0;
  int _totalPromotions = 0;
  int _totalApplications = 0;
  final int _pendingVerifications = 0;
  int _pendingComplaints = 0;

  // Recent items
  List<Map<String, dynamic>> _recentUsers = [];
  List<Map<String, dynamic>> _recentJobs = [];
  List<Map<String, dynamic>> _pendingApprovals = [];

  // Activity data for chart
  final List<FlSpot> _activityData = [
    const FlSpot(0, 3),
    const FlSpot(1, 1),
    const FlSpot(2, 4),
    const FlSpot(3, 2),
    const FlSpot(4, 5),
    const FlSpot(5, 3),
    const FlSpot(6, 4),
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get counts
      final usersResponse = await supabase
          .from('tbl_user')
          .select()
          .count(CountOption.exact);
      _totalUsers = usersResponse.count;

      final filmmakersResponse = await supabase
          .from('tbl_filmmakers')
          .select()
          .count(CountOption.exact);
      _totalFilmmakers = filmmakersResponse.count;

      final jobsResponse = await supabase
          .from('tbl_job')
          .select()
          .count(CountOption.exact);
      _totalJobs = jobsResponse.count;

      final postsResponse = await supabase
          .from('tbl_talentpost')
          .select()
          .count(CountOption.exact);
      _totalPosts = postsResponse.count;

      final promotionsResponse = await supabase
          .from('tbl_promotion')
          .select()
          .count(CountOption.exact);
      _totalPromotions = promotionsResponse.count;

      final applicationsResponse = await supabase
          .from('tbl_jobapplication')
          .select()
          .count(CountOption.exact);
      _totalApplications = applicationsResponse.count;

      final pendingComplaintsResponse = await supabase
          .from('tbl_complaint')
          .select()
          .eq('complaint_status', 0)
          .count(CountOption.exact);
      _pendingComplaints = pendingComplaintsResponse.count;

      // Get recent users
      final recentUsersResponse = await supabase
          .from('tbl_user')
          .select('user_id, user_name, user_email, created_at')
          .order('created_at', ascending: false)
          .limit(5);
      _recentUsers = List<Map<String, dynamic>>.from(recentUsersResponse);

      // Get recent jobs
      final recentJobsResponse = await supabase
          .from('tbl_job')
          .select(
            'job_id, job_title, job_status, created_at, tbl_filmmakers!filmmaker_id(filmmaker_name)',
          )
          .order('created_at', ascending: false)
          .limit(5);
      _recentJobs = List<Map<String, dynamic>>.from(recentJobsResponse);

      // Get pending approvals
      final pendingPostsResponse = await supabase
          .from('tbl_talentpost')
          .select('id, post_title, created_at, tbl_user!user_id(user_name)')
          .eq('post_status', 0)
          .order('created_at', ascending: false)
          .limit(3);

      final pendingJobsResponse = await supabase
          .from('tbl_job')
          .select(
            'job_id, job_title, created_at, tbl_filmmakers!filmmaker_id(filmmaker_name)',
          )
          .eq('job_status', 0)
          .order('created_at', ascending: false)
          .limit(3);

      final pendingPromotionsResponse = await supabase
          .from('tbl_promotion')
          .select(
            'promotion_id, movie_title, created_at, tbl_filmmakers!filmmaker_id(filmmaker_name)',
          )
          .eq('movie_status', 0)
          .order('created_at', ascending: false)
          .limit(3);

      _pendingApprovals = [
        ...List<Map<String, dynamic>>.from(
          pendingPostsResponse,
        ).map((post) => {...post, 'type': 'post'}),
        ...List<Map<String, dynamic>>.from(
          pendingJobsResponse,
        ).map((job) => {...job, 'type': 'job'}),
        ...List<Map<String, dynamic>>.from(
          pendingPromotionsResponse,
        ).map((promo) => {...promo, 'type': 'promotion'}),
      ];

      _pendingApprovals.sort(
        (a, b) => DateTime.parse(
          b['created_at'],
        ).compareTo(DateTime.parse(a['created_at'])),
      );

      if (_pendingApprovals.length > 5) {
        _pendingApprovals = _pendingApprovals.sublist(0, 5);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF4361EE)),
              )
              : RefreshIndicator(
                color: const Color(0xFF4361EE),
                onRefresh: _loadDashboardData,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 32),
                      _buildSummaryCards(),
                      const SizedBox(height: 32),
                      _buildChartSection(),
                      const SizedBox(height: 32),
                      _buildRecentSection(),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Welcome back, Admin',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _loadDashboardData,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4361EE),
                side: const BorderSide(color: Color(0xFF4361EE)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;
        final isTablet =
            constraints.maxWidth >= 800 && constraints.maxWidth < 1200;

        int crossAxisCount = 4;
        if (isMobile) {
          crossAxisCount = 2;
        } else if (isTablet) {
          crossAxisCount = 3;
        }

        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: isMobile ? 1.3 : 1.5,
          ),
          children: [
            _buildStatCard(
              title: 'Total Users',
              value: _totalUsers,
              icon: Icons.people_alt_rounded,
              iconColor: const Color(0xFF4361EE),
              trend: '+12%',
              trendUp: true,
            ),
            _buildStatCard(
              title: 'Filmmakers',
              value: _totalFilmmakers,
              icon: Icons.movie_creation_rounded,
              iconColor: const Color(0xFF7209B7),
              trend: '+8%',
              trendUp: true,
            ),
            _buildStatCard(
              title: 'Active Jobs',
              value: _totalJobs,
              icon: Icons.work_rounded,
              iconColor: const Color(0xFFF72585),
              trend: '+5%',
              trendUp: true,
            ),
            _buildStatCard(
              title: 'Talent Posts',
              value: _totalPosts,
              icon: Icons.image_rounded,
              iconColor: const Color(0xFF3A0CA3),
              trend: '+15%',
              trendUp: true,
            ),
            _buildStatCard(
              title: 'Promotions',
              value: _totalPromotions,
              icon: Icons.movie_rounded,
              iconColor: const Color(0xFF4CC9F0),
              trend: '+3%',
              trendUp: true,
            ),
            _buildStatCard(
              title: 'Applications',
              value: _totalApplications,
              icon: Icons.assignment_rounded,
              iconColor: const Color(0xFF4D908E),
              trend: '-2%',
              trendUp: false,
            ),

            _buildStatCard(
              title: 'Pending Complaints',
              value: _pendingComplaints,
              icon: Icons.report_problem_rounded,
              iconColor: const Color(0xFFFF5400),
              trend: '-5%',
              trendUp: false,
              isAlert: true,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required int value,
    required IconData icon,
    required Color iconColor,
    required String trend,
    required bool trendUp,
    bool isAlert = false,
  }) {
    return Container(
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              if (isAlert)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3F2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Action needed',
                    style: TextStyle(
                      color: Color(0xFFD92D20),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                trendUp ? Icons.trending_up : Icons.trending_down,
                color:
                    trendUp ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                trend,
                style: TextStyle(
                  color:
                      trendUp
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFF44336),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'vs last month',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;
        return isMobile
            ? Column(
              children: [
                _buildActivityChart(),
                const SizedBox(height: 16),
                _buildDistributionChart(),
              ],
            )
            : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildActivityChart()),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _buildDistributionChart()),
              ],
            );
      },
    );
  }

  Widget _buildActivityChart() {
    return Container(
      padding: const EdgeInsets.all(24),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Platform Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              DropdownButton<String>(
                value: 'This Week',
                underline: const SizedBox(),
                icon: const Icon(Icons.keyboard_arrow_down),
                items:
                    ['This Week', 'This Month', 'This Year'].map((
                      String value,
                    ) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                onChanged: (_) {},
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Overview of platform engagement and activity',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child:
                _activityData.isEmpty
                    ? const Center(child: Text('No activity data available'))
                    : LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 1,
                          getDrawingHorizontalLine:
                              (value) => FlLine(
                                color: Colors.grey[200]!,
                                strokeWidth: 1,
                              ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                const style = TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                );
                                String text;
                                switch (value.toInt()) {
                                  case 0:
                                    text = 'Mon';
                                    break;
                                  case 1:
                                    text = 'Tue';
                                    break;
                                  case 2:
                                    text = 'Wed';
                                    break;
                                  case 3:
                                    text = 'Thu';
                                    break;
                                  case 4:
                                    text = 'Fri';
                                    break;
                                  case 5:
                                    text = 'Sat';
                                    break;
                                  case 6:
                                    text = 'Sun';
                                    break;
                                  default:
                                    return const SizedBox.shrink();
                                }
                                return SideTitleWidget(
                                  meta: meta,
                                  child: Text(text, style: style),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                if (value == 0) return const SizedBox.shrink();
                                return SideTitleWidget(
                                  meta: meta,
                                  child: Text(
                                    '${value.toInt()}k',
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: 6,
                        minY: 0,
                        maxY: 6,
                        lineBarsData: [
                          LineChartBarData(
                            spots: _activityData,
                            isCurved: true,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4361EE), Color(0xFF7209B7)],
                            ),
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF4361EE).withOpacity(0.2),
                                  const Color(0xFF7209B7).withOpacity(0.0),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Users', const Color(0xFF4361EE)),
              const SizedBox(width: 24),
              _buildLegendItem('Filmmakers', const Color(0xFF7209B7)),
              const SizedBox(width: 24),
              _buildLegendItem('Jobs', const Color(0xFFF72585)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
      ],
    );
  }

  Widget _buildDistributionChart() {
    return Container(
      padding: const EdgeInsets.all(24),
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
        children: [
          const Text(
            'User Distribution',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Breakdown of platform users by type',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    value: 35,
                    title: '35%',
                    color: const Color(0xFF4361EE),
                    radius: 100,
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: 40,
                    title: '40%',
                    color: const Color(0xFF7209B7),
                    radius: 100,
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: 25,
                    title: '25%',
                    color: const Color(0xFFF72585),
                    radius: 100,
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              _buildDistributionLegendItem(
                'Regular Users',
                '35%',
                const Color(0xFF4361EE),
              ),
              const SizedBox(height: 8),
              _buildDistributionLegendItem(
                'Filmmakers',
                '40%',
                const Color(0xFF7209B7),
              ),
              const SizedBox(height: 8),
              _buildDistributionLegendItem(
                'Talent',
                '25%',
                const Color(0xFFF72585),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionLegendItem(
    String label,
    String percentage,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
        const Spacer(),
        Text(
          percentage,
          style: const TextStyle(
            color: Color(0xFF2D3748),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;
        return isMobile
            ? Column(
              children: [
                _buildRecentUsersCard(),
                const SizedBox(height: 16),
                _buildRecentJobsCard(),
                const SizedBox(height: 16),
                _buildPendingApprovalsCard(),
              ],
            )
            : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildRecentUsersCard()),
                const SizedBox(width: 16),
                Expanded(child: _buildRecentJobsCard()),
                const SizedBox(width: 16),
                Expanded(child: _buildPendingApprovalsCard()),
              ],
            );
      },
    );
  }

  Widget _buildRecentUsersCard() {
    return Container(
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
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Users',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: Color(0xFF4361EE),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _recentUsers.isEmpty
              ? const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('No recent users')),
              )
              : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentUsers.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = _recentUsers[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF4361EE).withOpacity(0.1),
                      child: Text(
                        (user['user_name'] as String? ?? '').isNotEmpty
                            ? (user['user_name'] as String)
                                .substring(0, 1)
                                .toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Color(0xFF4361EE),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      user['user_name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    subtitle: Text(
                      user['user_email'] ?? '',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    trailing: Text(
                      _formatDate(user['created_at']),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }

  Widget _buildRecentJobsCard() {
    return Container(
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
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Jobs',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: Color(0xFF4361EE),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _recentJobs.isEmpty
              ? const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('No recent jobs')),
              )
              : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentJobs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final job = _recentJobs[index];
                  final filmmaker =
                      job['tbl_filmmakers'] as Map<String, dynamic>?;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF7209B7).withOpacity(0.1),
                      child: const Icon(
                        Icons.work_rounded,
                        color: Color(0xFF7209B7),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      job['job_title'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    subtitle: Text(
                      'By: ${filmmaker?['filmmaker_name'] ?? 'Unknown'}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                job['job_status'] == 1
                                    ? const Color(0xFF4CAF50).withOpacity(0.1)
                                    : const Color(0xFFF44336).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            job['job_status'] == 1 ? 'Active' : 'Blocked',
                            style: TextStyle(
                              color:
                                  job['job_status'] == 1
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFFF44336),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(job['created_at']),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }

  Widget _buildPendingApprovalsCard() {
    return Container(
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
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Pending Approvals',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Badge(
                      backgroundColor: const Color(0xFFF44336),
                      label: Text(_pendingApprovals.length.toString()),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: Color(0xFF4361EE),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _pendingApprovals.isEmpty
              ? const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('No pending approvals')),
              )
              : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _pendingApprovals.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _pendingApprovals[index];
                  final type = item['type'];

                  IconData icon;
                  Color iconColor;
                  String title;
                  String creatorName;

                  if (type == 'post') {
                    icon = Icons.image_rounded;
                    iconColor = const Color(0xFF3A0CA3);
                    title = item['post_title'] ?? 'Unknown Post';
                    creatorName =
                        (item['tbl_user']
                            as Map<String, dynamic>?)?['user_name'] ??
                        'Unknown User';
                  } else if (type == 'job') {
                    icon = Icons.work_rounded;
                    iconColor = const Color(0xFFF72585);
                    title = item['job_title'] ?? 'Unknown Job';
                    creatorName =
                        (item['tbl_filmmakers']
                            as Map<String, dynamic>?)?['filmmaker_name'] ??
                        'Unknown Filmmaker';
                  } else {
                    // promotion
                    icon = Icons.movie_rounded;
                    iconColor = const Color(0xFF4CC9F0);
                    title = item['movie_title'] ?? 'Unknown Promotion';
                    creatorName =
                        (item['tbl_filmmakers']
                            as Map<String, dynamic>?)?['filmmaker_name'] ??
                        'Unknown Filmmaker';
                  }

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: iconColor.withOpacity(0.1),
                      child: Icon(icon, color: iconColor, size: 20),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    subtitle: Text(
                      'By: $creatorName',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getTypeColor(type),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${type[0].toUpperCase()}${type.substring(1)}',
                            style: TextStyle(
                              color: _getTypeTextColor(type),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(item['created_at']),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} min ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('dd MMM yyyy').format(date);
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'post':
        return const Color(0xFF3A0CA3).withOpacity(0.1);
      case 'job':
        return const Color(0xFFF72585).withOpacity(0.1);
      case 'promotion':
        return const Color(0xFF4CC9F0).withOpacity(0.1);
      default:
        return Colors.grey[100]!;
    }
  }

  Color _getTypeTextColor(String type) {
    switch (type) {
      case 'post':
        return const Color(0xFF3A0CA3);
      case 'job':
        return const Color(0xFFF72585);
      case 'promotion':
        return const Color(0xFF4CC9F0);
      default:
        return Colors.grey[800]!;
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
