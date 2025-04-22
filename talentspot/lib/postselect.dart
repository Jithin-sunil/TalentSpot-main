import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SelectPostsPage extends StatefulWidget {
  const SelectPostsPage({super.key});

  @override
  State<SelectPostsPage> createState() => _SelectPostsPageState();
}

class _SelectPostsPageState extends State<SelectPostsPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _posts = [];
  final List<Map<String, dynamic>> _selectedPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMyPosts();
  }

  Future<void> _fetchMyPosts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await supabase
          .from('Talent_Posts')
          .select()
          .eq('user_id', userId)
          .eq('approved', true)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _posts = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching posts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _togglePostSelection(Map<String, dynamic> post) {
    setState(() {
      if (_selectedPosts.any((p) => p['post_id'] == post['post_id'])) {
        _selectedPosts.removeWhere((p) => p['post_id'] == post['post_id']);
      } else {
        _selectedPosts.add(post);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Select Posts'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, _selectedPosts);
            },
            child: Text(
              'Done (${_selectedPosts.length})',
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              ),
            )
          : _posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.post_add,
                        size: 64,
                        color: theme.colorScheme.primary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'You don\'t have any approved posts',
                        style: TextStyle(
                          fontSize: 18,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _posts.length,
                  itemBuilder: (context, index) {
                    final post = _posts[index];
                    final isSelected = _selectedPosts.any(
                      (p) => p['post_id'] == post['post_id'],
                    );
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isSelected
                            ? BorderSide(color: theme.colorScheme.primary, width: 2)
                            : BorderSide.none,
                      ),
                      child: InkWell(
                        onTap: () => _togglePostSelection(post),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              // Post thumbnail
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image: NetworkImage(post['media_url']),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Post details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      post['title'] ?? '',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      post['category'] ?? '',
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateTime.parse(post['created_at']).toString().substring(0, 10),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Checkbox
                              Checkbox(
                                value: isSelected,
                                onChanged: (_) => _togglePostSelection(post),
                                activeColor: theme.colorScheme.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}