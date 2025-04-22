import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class TalentPostsPage extends StatefulWidget {
  const TalentPostsPage({super.key});

  @override
  State<TalentPostsPage> createState() => _TalentPostsPageState();
}

class _TalentPostsPageState extends State<TalentPostsPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _likes = [];
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentPage = 1;
  final int _itemsPerPage = 5;

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
      // Fetch likes
      final likesResponse = await supabase
          .from('tbl_like')
          .select()
          .eq('like_status', 1);

      // Fetch posts with user details
      final postsResponse = await supabase
          .from('tbl_talentpost')
          .select('''
            *,
            tbl_user!user_id(user_name, user_email)
          ''')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _posts = List<Map<String, dynamic>>.from(postsResponse);
          _likes = List<Map<String, dynamic>>.from(likesResponse);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error fetching data: $e')));
      }
    }
  }

  Future<void> _togglePostStatus(String postId, int currentStatus) async {
    try {
      final newStatus =
          currentStatus == 1
              ? 0
              : 1; // Toggle between active (1) and blocked (0)
      await supabase
          .from('tbl_talentpost')
          .update({'post_status': newStatus})
          .eq('id', postId);

      await _fetchData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 1
                ? 'Post unblocked successfully'
                : 'Post blocked successfully',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF4361EE),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  List<Map<String, dynamic>> _getFilteredPosts() {
    if (_searchQuery.isEmpty) return _posts;

    return _posts.where((post) {
      final title = post['post_title']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return title.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> _getPaginatedPosts() {
    final filteredPosts = _getFilteredPosts();
    final startIndex = (_currentPage - 1) * _itemsPerPage;

    if (startIndex >= filteredPosts.length) {
      return [];
    }

    final endIndex =
        startIndex + _itemsPerPage > filteredPosts.length
            ? filteredPosts.length
            : startIndex + _itemsPerPage;

    return filteredPosts.sublist(startIndex, endIndex);
  }

  int get _pageCount {
    return (_getFilteredPosts().length / _itemsPerPage).ceil();
  }

  int _getTotalLikes(String postId) {
    return _likes.where((like) => like['post_id'].toString() == postId).length;
  }

  String _getStatusText(int status) {
    return status == 1 ? 'Active' : 'Blocked';
  }

  Color _getStatusColor(int status) {
    return status == 1 ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
  }

  void _showPostDetailsDialog(Map<String, dynamic> post) {
    final user = post['tbl_user'] as Map<String, dynamic>?;
    final formattedDate = DateFormat(
      'MMM dd, yyyy',
    ).format(DateTime.parse(post['created_at']));
    final tags =
        post['post_tags'] != null
            ? (post['post_tags'] as String)
                .replaceAll(RegExp(r'[\[\]"]'), '')
                .split(',')
            : [];

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              post['post_title'] ?? 'Post Details',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow('Posted Date', formattedDate),
                  _buildDetailRow('Title', post['post_title'] ?? 'N/A'),
                  _buildDetailRow(
                    'Description',
                    post['post_description'] ?? 'N/A',
                  ),
                  if (post['post_file'] != null) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Media:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 300,
                      height: 200,
                      child: Image.network(
                        post['post_file'],
                        fit: BoxFit.cover,
                        errorBuilder:
                            (context, error, stackTrace) =>
                                const Icon(Icons.broken_image),
                      ),
                    ),
                  ],
                  _buildDetailRow(
                    'Tags',
                    tags.isNotEmpty ? tags.join(', ') : 'None',
                  ),
                  _buildDetailRow('Type', post['post_type'] ?? 'N/A'),
                  _buildDetailRow(
                    'Status',
                    _getStatusText(post['post_status'] ?? 1),
                  ),
                  _buildDetailRow('Posted By', user?['user_name'] ?? 'N/A'),
                  _buildDetailRow('Email', user?['user_email'] ?? 'N/A'),
                  _buildDetailRow(
                    'Total Likes',
                    _getTotalLikes(post['id'].toString()).toString(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
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
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paginatedPosts = _getPaginatedPosts();
    final activePosts =
        _getFilteredPosts().where((post) => post['post_status'] == 1).length;

    return Scaffold(
      body:
          _isLoading && _posts.isEmpty
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF4361EE)),
              )
              : Container(
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
                            'Talent Posts Management',
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
                                hintText: 'Search by post title...',
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
                                suffixIcon:
                                    _searchQuery.isNotEmpty
                                        ? IconButton(
                                          icon: Icon(
                                            Icons.clear,
                                            color: Colors.grey[500],
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _searchController.clear();
                                              _searchQuery = '';
                                              _currentPage = 1;
                                            });
                                          },
                                        )
                                        : null,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                  _currentPage = 1;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Overview
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Talent Posts Overview',
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
                              title: 'Total Posts',
                              value: _getFilteredPosts().length.toString(),
                              icon: Icons.post_add,
                              iconColor: const Color(0xFF4361EE),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _StatCard(
                              title: 'Active Posts',
                              value: activePosts.toString(),
                              icon: Icons.check_circle_outline,
                              iconColor: const Color(0xFF4CAF50),
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
                              flex: 1,
                              child: Text(
                                'Likes',
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
                          _isLoading
                              ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF4361EE),
                                ),
                              )
                              : paginatedPosts.isEmpty
                              ? Center(
                                child: Text(
                                  'No posts found',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              )
                              : ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                itemCount: paginatedPosts.length,
                                separatorBuilder:
                                    (context, index) =>
                                        const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final post = paginatedPosts[index];
                                  final status = post['post_status'] ?? 1;
                                  final user =
                                      post['tbl_user'] as Map<String, dynamic>?;
                                  final postedBy =
                                      user != null
                                          ? '${user['user_name']} (${user['user_email']})'
                                          : 'N/A';

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
                                          child: Text(
                                            post['post_title'] ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            postedBy,
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            _getTotalLikes(
                                              post['id'].toString(),
                                            ).toString(),
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                            ),
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
                                              borderRadius:
                                                  BorderRadius.circular(4),
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
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.visibility,
                                                  color: Colors.blue,
                                                ),
                                                onPressed:
                                                    () =>
                                                        _showPostDetailsDialog(
                                                          post,
                                                        ),
                                                tooltip: 'View Details',
                                              ),
                                              OutlinedButton(
                                                onPressed:
                                                    () => _togglePostStatus(
                                                      post['id'].toString(),
                                                      status,
                                                    ),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor:
                                                      status == 1
                                                          ? const Color(
                                                            0xFFF44336,
                                                          )
                                                          : const Color(
                                                            0xFF4CAF50,
                                                          ),
                                                  side: BorderSide(
                                                    color:
                                                        status == 1
                                                            ? const Color(
                                                              0xFFF44336,
                                                            )
                                                            : const Color(
                                                              0xFF4CAF50,
                                                            ),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                      ),
                                                  minimumSize: const Size(
                                                    0,
                                                    32,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                ),
                                                child: Text(
                                                  status == 1
                                                      ? 'Block'
                                                      : 'Unblock',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
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
                    if (!_isLoading && _getFilteredPosts().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.white,
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Showing ${paginatedPosts.length} of ${_getFilteredPosts().length} posts',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left),
                                  onPressed:
                                      _currentPage > 1
                                          ? () {
                                            setState(() {
                                              _currentPage--;
                                            });
                                          }
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
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
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
                                      onTap: () {
                                        setState(() {
                                          _currentPage = i;
                                        });
                                      },
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '$i',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                    ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right),
                                  onPressed:
                                      _currentPage < _pageCount
                                          ? () {
                                            setState(() {
                                              _currentPage++;
                                            });
                                          }
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
