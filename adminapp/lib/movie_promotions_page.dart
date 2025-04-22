import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class MoviePromotionsPage extends StatefulWidget {
  const MoviePromotionsPage({super.key});

  @override
  State<MoviePromotionsPage> createState() => _MoviePromotionsPageState();
}

class _MoviePromotionsPageState extends State<MoviePromotionsPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _promotions = [];
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentPage = 1;
  final int _itemsPerPage = 5;

  @override
  void initState() {
    super.initState();
    _fetchPromotions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPromotions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await supabase
          .from('tbl_promotion')
          .select('''
            promotion_id, movie_title, movie_description, movie_poster, movie_duration, movie_releasedate, movie_status, created_at,
            tbl_filmmakers!filmmaker_id(filmmaker_name, filmmaker_email)
          ''')
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _promotions = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching promotions: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching promotions: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF4361EE),
          ),
        );
      }
    }
  }

  Future<void> _togglePromotionStatus(
    String promotionId,
    int currentStatus,
  ) async {
    try {
      final newStatus = currentStatus == 1 ? 0 : 1;
      await supabase
          .from('tbl_promotion')
          .update({'movie_status': newStatus})
          .eq('promotion_id', promotionId);

      await _fetchPromotions();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 1
                ? 'Promotion unblocked successfully'
                : 'Promotion blocked successfully',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF4361EE),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF4361EE),
        ),
      );
    }
  }

  List<Map<String, dynamic>> _getFilteredPromotions() {
    if (_searchQuery.isEmpty) return _promotions;

    return _promotions.where((promotion) {
      final title = promotion['movie_title']?.toString().toLowerCase() ?? '';
      final filmmaker =
          (promotion['tbl_filmmakers']
                  as Map<String, dynamic>?)?['filmmaker_name']
              ?.toString()
              .toLowerCase() ??
          '';
      final query = _searchQuery.toLowerCase();

      return title.contains(query) || filmmaker.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> _getPaginatedPromotions() {
    final filteredPromotions = _getFilteredPromotions();
    final startIndex = (_currentPage - 1) * _itemsPerPage;

    if (startIndex >= filteredPromotions.length) {
      return [];
    }

    final endIndex = (startIndex + _itemsPerPage).clamp(
      0,
      filteredPromotions.length,
    );
    return filteredPromotions.sublist(startIndex, endIndex);
  }

  int get _pageCount {
    return (_getFilteredPromotions().length / _itemsPerPage).ceil();
  }

  String _getStatusText(int status) {
    return status == 1 ? 'Active' : 'Blocked';
  }

  Color _getStatusColor(int status) {
    return status == 1 ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
  }

  void _showPromotionDetailsDialog(Map<String, dynamic> promotion) {
    final filmmaker = promotion['tbl_filmmakers'] as Map<String, dynamic>?;
    final formattedCreatedDate = DateFormat(
      'MMM dd, yyyy',
    ).format(DateTime.parse(promotion['created_at']));
    final formattedReleaseDate = DateFormat(
      'MMM dd, yyyy',
    ).format(DateTime.parse(promotion['movie_releasedate']));

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              promotion['movie_title'] ?? 'Promotion Details',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow('Posted Date', formattedCreatedDate),
                  _buildDetailRow('Title', promotion['movie_title'] ?? ''),
                  _buildDetailRow(
                    'Description',
                    promotion['movie_description'] ?? '',
                  ),
                  if (promotion['movie_poster'] != null) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Poster:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 300,
                      height: 200,
                      child: Image.network(
                        promotion['movie_poster'],
                        fit: BoxFit.cover,
                        errorBuilder:
                            (context, error, stackTrace) =>
                                const Icon(Icons.broken_image, size: 50),
                      ),
                    ),
                  ],
                  _buildDetailRow(
                    'Duration',
                    '${promotion['movie_duration'] ?? 'N/A'} minutes',
                  ),
                  _buildDetailRow('Release Date', formattedReleaseDate),
                  _buildDetailRow(
                    'Status',
                    _getStatusText(promotion['movie_status'] ?? 1),
                  ),
                  _buildDetailRow(
                    'Posted By',
                    filmmaker?['filmmaker_name'] ?? 'N/A',
                  ),
                  _buildDetailRow(
                    'Email',
                    filmmaker?['filmmaker_email'] ?? 'N/A',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Color(0xFF4361EE)),
                ),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            backgroundColor: Colors.white,
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
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3748),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF2D3748)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paginatedPromotions = _getPaginatedPromotions();
    final activePromotions =
        _getFilteredPromotions()
            .where((promotion) => promotion['movie_status'] == 1)
            .length;

    return Scaffold(
      body: Container(
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
                    'Movie Promotions Management',
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
                        hintText: 'Search by title or filmmaker',
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
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                          _currentPage = 1; // Reset to first page
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Overview Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Promotions Overview',
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
                      title: 'Total Promotions',
                      value: _getFilteredPromotions().length.toString(),
                      icon: Icons.movie_outlined,
                      iconColor: const Color(0xFF4361EE),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      title: 'Active Promotions',
                      value: activePromotions.toString(),
                      icon: Icons.check_circle_outline,
                      iconColor: const Color(0xFF4CAF50),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      title: 'Blocked Promotions',
                      value:
                          (_getFilteredPromotions().length - activePromotions)
                              .toString(),
                      icon: Icons.block_outlined,
                      iconColor: const Color(0xFFF44336),
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
                        'Duration',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Release Date',
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
                  _isLoading && _promotions.isEmpty
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4361EE),
                        ),
                      )
                      : paginatedPromotions.isEmpty
                      ? Center(
                        child: Text(
                          'No promotions found',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      )
                      : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: paginatedPromotions.length,
                        separatorBuilder:
                            (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final promotion = paginatedPromotions[index];
                          final status = promotion['movie_status'] ?? 1;
                          final filmmaker =
                              promotion['tbl_filmmakers']
                                  as Map<String, dynamic>?;
                          final formattedDate = DateFormat(
                            'MMM dd, yyyy',
                          ).format(DateTime.parse(promotion['created_at']));
                          final formattedReleaseDate = DateFormat(
                            'MMM dd, yyyy',
                          ).format(
                            DateTime.parse(promotion['movie_releasedate']),
                          );
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
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF4361EE,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          (promotion['movie_title']
                                                          as String? ??
                                                      '')
                                                  .isNotEmpty
                                              ? (promotion['movie_title']
                                                      as String)
                                                  .substring(0, 1)
                                                  .toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Color(0xFF4361EE),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        promotion['movie_title'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    postedBy,
                                    style: TextStyle(color: Colors.grey[700]),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${promotion['movie_duration'] ?? 'N/A'} minutes',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    formattedReleaseDate,
                                    style: TextStyle(color: Colors.grey[700]),
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
                                      borderRadius: BorderRadius.circular(4),
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
                                      OutlinedButton(
                                        onPressed:
                                            () => _showPromotionDetailsDialog(
                                              promotion,
                                            ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(
                                            0xFF4361EE,
                                          ),
                                          side: const BorderSide(
                                            color: Color(0xFF4361EE),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          minimumSize: const Size(0, 32),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'View',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton(
                                        onPressed:
                                            () => _togglePromotionStatus(
                                              promotion['promotion_id']
                                                  .toString(),
                                              status,
                                            ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              status == 1
                                                  ? const Color(0xFFF44336)
                                                  : const Color(0xFF4CAF50),
                                          side: BorderSide(
                                            color:
                                                status == 1
                                                    ? const Color(0xFFF44336)
                                                    : const Color(0xFF4CAF50),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          minimumSize: const Size(0, 32),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          status == 1 ? 'Block' : 'Activate',
                                          style: const TextStyle(fontSize: 12),
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
            if (!_isLoading && _getFilteredPromotions().isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${paginatedPromotions.length} of ${_getFilteredPromotions().length} promotions',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed:
                              _currentPage > 1
                                  ? () => setState(() {
                                    _currentPage--;
                                  })
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
                              margin: const EdgeInsets.symmetric(horizontal: 4),
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
                              onTap:
                                  () => setState(() {
                                    _currentPage = i;
                                  }),
                              child: Container(
                                width: 32,
                                height: 32,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '$i',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ),
                            ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed:
                              _currentPage < _pageCount
                                  ? () => setState(() {
                                    _currentPage++;
                                  })
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
