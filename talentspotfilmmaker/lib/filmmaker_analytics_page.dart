import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

class FilmmakerAnalyticsPage extends StatefulWidget {
  const FilmmakerAnalyticsPage({super.key});

  @override
  State<FilmmakerAnalyticsPage> createState() => _FilmmakerAnalyticsPageState();
}

class _FilmmakerAnalyticsPageState extends State<FilmmakerAnalyticsPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  // Analytics data
  final int _totalJobs = 0;
  final int _totalApplications = 0;
  final int _totalPromotions = 0;
  final int _totalPromotionViews = 0;
  
  // Chart data
  List<Map<String, dynamic>> _applicationsByJob = [];
  final List<Map<String, dynamic>> _promotionViewsData = [];
  
  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Get job count
      // final jobsResponse = await supabase
      //     .from('Jobs')
      //     .select('job_id', count: CountOption.exact)
      //     .eq('filmmaker_id', userId);
      
      // _totalJobs = jobsResponse.count ?? 0;
      
      // // Get applications count
      // final applicationsResponse = await supabase
      //     .from('Job_Applications')
      //     .select('application_id', count: CountOption.exact)
      //     .eq('Jobs.filmmaker_id', userId);
      
      // _totalApplications = applicationsResponse.count ?? 0;
      
      // // Get promotions count and total views
      // final promotionsResponse = await supabase
      //     .from('Movie_Promotions')
      //     .select('promotion_id, views')
      //     .eq('filmmaker_id', userId);
      
      // final promotions = List<Map<String, dynamic>>.from(promotionsResponse);
      // _totalPromotions = promotions.length;
      // _totalPromotionViews = promotions.fold(0, (sum, item) => sum + (item['views'] ?? 0));
      
      // Get applications by job
      final applicationsByJobResponse = await supabase
          .from('Jobs')
          .select('''
            job_id,
            title,
            job_applications:Job_Applications(count)
          ''')
          .eq('filmmaker_id', userId)
          .order('created_at', ascending: false)
          .limit(5);
      
      _applicationsByJob = List<Map<String, dynamic>>.from(applicationsByJobResponse);
      
      // Get promotion views data
      // _promotionViewsData = promotions
      //     .where((p) => p['views'] != null && p['views'] > 0)
      //     .toList()
      //     .sublist(0, promotions.length > 5 ? 5 : promotions.length);

      // if (mounted) {
      //   setState(() {
      //     _isLoading = false;
      //   });
      // }
    } catch (e) {
      debugPrint('Error loading analytics data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalyticsData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary cards
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildSummaryCard(
                          'Total Jobs',
                          _totalJobs.toString(),
                          Icons.work,
                          Colors.blue,
                        ),
                        _buildSummaryCard(
                          'Total Applications',
                          _totalApplications.toString(),
                          Icons.people,
                          Colors.green,
                        ),
                        _buildSummaryCard(
                          'Total Promotions',
                          _totalPromotions.toString(),
                          Icons.movie,
                          Colors.purple,
                        ),
                        _buildSummaryCard(
                          'Promotion Views',
                          _totalPromotionViews.toString(),
                          Icons.visibility,
                          Colors.orange,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Applications by job chart
                    if (_applicationsByJob.isNotEmpty) ...[
                      const Text(
                        'Applications by Job',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: _applicationsByJob
                                .map((job) => job['job_applications'][0]['count'] as int)
                                .reduce((a, b) => a > b ? a : b)
                                .toDouble() * 1.2,
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                // tooltipBgColor: Colors.blueGrey,
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  return BarTooltipItem(
                                    '${_applicationsByJob[groupIndex]['title']}\n',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: '${rod.toY.round()} applications',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    if (value >= _applicationsByJob.length || value < 0) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        _applicationsByJob[value.toInt()]['title'],
                                        style: const TextStyle(
                                          fontSize: 10,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  getTitlesWidget: (value, meta) {
                                    if (value == 0) {
                                      return const SizedBox.shrink();
                                    }
                                    return Text(
                                      value.toInt().toString(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: _applicationsByJob.asMap().entries.map((entry) {
                              final index = entry.key;
                              final job = entry.value;
                              final applicationCount = job['job_applications'][0]['count'] as int;
                              
                              return BarChartGroupData(
                                x: index,
                                barRods: [
                                  BarChartRodData(
                                    toY: applicationCount.toDouble(),
                                    color: Colors.blue,
                                    width: 20,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4),
                                      topRight: Radius.circular(4),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                    
                    // Promotion views chart
                    if (_promotionViewsData.isNotEmpty) ...[
                      const Text(
                        'Promotion Views',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: PieChart(
                          PieChartData(
                            sections: _promotionViewsData.map((promotion) {
                              final views = promotion['views'] as int;
                              final totalViews = _totalPromotionViews;
                              final percentage = totalViews > 0 ? views / totalViews : 0;
                              
                              return PieChartSectionData(
                                color: Colors.primaries[_promotionViewsData.indexOf(promotion) % Colors.primaries.length],
                                value: views.toDouble(),
                                title: '${(percentage * 100).toStringAsFixed(1)}%',
                                radius: 80,
                                titleStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              );
                            }).toList(),
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                            startDegreeOffset: -90,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Legend
                      Column(
                        children: _promotionViewsData.map((promotion) {
                          final index = _promotionViewsData.indexOf(promotion);
                          final color = Colors.primaries[index % Colors.primaries.length];
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  color: color,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    promotion['movie_title'] ?? 'Promotion ${index + 1}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text('${promotion['views']} views'),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 40,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

