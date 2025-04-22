import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talentspot/createpost.dart';
import 'package:talentspot/postdetails.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:google_fonts/google_fonts.dart';

class MyPostsPage extends StatefulWidget {
  const MyPostsPage({super.key});

  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = supabase.auth.currentUser?.id;
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    setState(() => _isLoading = true);
    try {
      if (_currentUserId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await supabase
          .from('tbl_talentpost')
          .select('''
            *,
            tbl_user(user_id, user_name, user_photo),
            tbl_like(*),
            tbl_comment(*)
          ''')
          .eq('user_id', _currentUserId!)
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> postsWithLikes = [];
      for (var post in response) {
        final userLikes = post['tbl_like'] as List<dynamic>;
        final isLikedByUser = userLikes.any((like) => like['user_id'] == _currentUserId);
        post['is_liked_by_user'] = isLikedByUser;
        post['like_count'] = userLikes.length;
        post['comment_count'] = (post['tbl_comment'] as List<dynamic>).length;
        postsWithLikes.add(post);
      }

      if (mounted) {
        setState(() {
          _posts = postsWithLikes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching posts: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike(int postId, bool isLiked) async {
    try {
      if (_currentUserId == null) return;

      setState(() {
        for (var post in _posts) {
          if (post['id'] == postId) {
            post['is_liked_by_user'] = !isLiked;
            post['like_count'] = isLiked ? post['like_count'] - 1 : post['like_count'] + 1;
            if (isLiked) {
              post['tbl_like'].removeWhere((like) => like['user_id'] == _currentUserId);
            } else {
              post['tbl_like'].add({
                'post_id': postId,
                'user_id': _currentUserId,
              });
            }
          }
        }
      });

      if (isLiked) {
        await supabase.from('tbl_like').delete().match({
          'post_id': postId,
          'user_id': _currentUserId!,
        });
      } else {
        await supabase.from('tbl_like').insert({
          'post_id': postId,
          'user_id': _currentUserId,
        });
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');
      _fetchPosts();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update like')),
      );
    }
  }

  Future<void> _deletePost(int postId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Post', style: GoogleFonts.poppins()),
        content: Text('Are you sure you want to delete this post?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('tbl_talentpost').delete().eq('id', postId);
        await _fetchPosts();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Post deleted successfully')),
        );
      } catch (e) {
        debugPrint('Error deleting post: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting post')),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchComments(int postId) async {
    try {
      final response = await supabase
          .from('tbl_comment')
          .select(
            '*, tbl_user(user_id, user_name, user_photo), tbl_filmmakers(filmmaker_id, filmmaker_name, filmmaker_photo)',
          )
          .eq('post_id', postId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(
        response.map((comment) {
          if (comment['filmmaker_id'] != null) {
            final filmmaker = comment['tbl_filmmakers'] as Map<String, dynamic>? ?? {};
            return {
              ...comment,
              'commenter_name': filmmaker['filmmaker_name'] ?? 'Unknown',
              'commenter_photo': filmmaker['filmmaker_photo'],
              'commenter_type': 'filmmaker',
            };
          } else {
            final user = comment['tbl_user'] as Map<String, dynamic>? ?? {};
            return {
              ...comment,
              'commenter_name': user['user_name'] ?? 'Unknown',
              'commenter_photo': user['user_photo'],
              'commenter_type': 'user',
            };
          }
        }).toList(),
      );
    } catch (e) {
      debugPrint('Error fetching comments: $e');
      return [];
    }
  }

  void _showCommentsSheet(int postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(
        postId: postId,
        fetchComments: _fetchComments,
      ),
    );
  }

  void _showLikesDialog(int postId) {
    final post = _posts.firstWhere((p) => p['id'] == postId);
    final likes = post['tbl_like'] as List<dynamic>? ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Liked by', style: GoogleFonts.poppins()),
        content: likes.isEmpty
            ? Text('No likes yet', style: GoogleFonts.poppins())
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: likes.length,
                  itemBuilder: (context, index) {
                    final like = likes[index];
                    return ListTile(
                      leading: Icon(Icons.person, color: const Color(0xFF64748B)),
                      title: Text(
                        like['user_name'] ?? 'Unknown',
                        style: GoogleFonts.poppins(),
                      ),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(String dateTime) {
    final date = DateTime.parse(dateTime);
    return timeago.format(date);
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF4361EE);
    const Color secondaryColor = Color(0xFF64748B);
    const Color accentColor = Colors.white;
    const Color backgroundColor = Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'My Posts',
          style: GoogleFonts.poppins(
            fontSize: MediaQuery.of(context).size.width < 600 ? 18 : 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D3748),
          ),
        ),
        backgroundColor: accentColor,
        elevation: 2,
        shadowColor: const Color(0x0D000000).withOpacity(0.05),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: primaryColor),
            onPressed: _fetchPosts,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.post_add, size: 64, color: secondaryColor.withOpacity(0.7)),
                      SizedBox(height: 16),
                      Text(
                        'No posts yet',
                        style: GoogleFonts.poppins(fontSize: 18, color: secondaryColor),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Share your talents with the world!',
                        style: GoogleFonts.poppins(fontSize: 14, color: secondaryColor),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: primaryColor,
                  onRefresh: _fetchPosts,
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    itemCount: _posts.length,
                    itemBuilder: (context, index) {
                      return _buildPostCard(_posts[index]);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostPage())).then((_) => _fetchPosts()),
        child: Icon(Icons.add, color: accentColor),
        backgroundColor: primaryColor,
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final user = post['tbl_user'] as Map<String, dynamic>? ?? {};
    final isLiked = post['is_liked_by_user'] ?? false;
    final likeCount = post['like_count'] ?? 0;
    final commentCount = post['comment_count'] ?? 0;
    final postId = post['id'];
    final postType = post['post_type'] ?? 'image';
    final mediaUrl = post['post_file'];
    final tags = (post['post_tags'] as String?)
            ?.replaceAll('[', '')
            .replaceAll(']', '')
            .replaceAll('"', '')
            .split(',')
            .map((tag) => tag.trim())
            .toList() ??
        [];

    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width * 0.05,
        vertical: 8,
      ),
      child: Padding(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 20,
                backgroundImage: user['user_photo'] != null ? CachedNetworkImageProvider(user['user_photo']) : null,
                child: user['user_photo'] == null ? Icon(Icons.person, color: const Color(0xFF64748B)) : null,
              ),
              title: Text(
                user['user_name'] ?? 'Unknown',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D3748),
                ),
              ),
              subtitle: Text(
                _getTimeAgo(post['created_at']),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.share, color: const Color(0xFF4361EE)),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deletePost(postId),
                  ),
                ],
              ),
            ),
            if (post['post_title']?.trim().isNotEmpty ?? false)
              Padding(
                padding: EdgeInsets.only(top: 8, bottom: 8),
                child: Text(
                  post['post_title'],
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D3748),
                  ),
                ),
              ),
            if (post['post_description']?.trim().isNotEmpty ?? false)
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  post['post_description'],
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: const Color(0xFF2D3748),
                  ),
                ),
              ),
            if (tags.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 8,
                  children: tags
                      .map(
                        (tag) => Chip(
                          label: Text(
                            tag,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                            ),
                          ),
                          backgroundColor: const Color(0xFF4361EE).withOpacity(0.1),
                        ),
                      )
                      .toList(),
                ),
              ),
            if (mediaUrl != null)
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PostDetailPage(post: post)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: postType == 'video'
                        ? VideoPlayerWidget(videoUrl: mediaUrl)
                        : CachedNetworkImage(
                            imageUrl: mediaUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(
                              child: CircularProgressIndicator(color: const Color(0xFF4361EE)),
                            ),
                            errorWidget: (context, url, error) => Icon(
                              Icons.error,
                              color: Colors.red,
                            ),
                          ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : null,
                        ),
                        onPressed: () => _toggleLike(postId, isLiked),
                      ),
                      GestureDetector(
                        onTap: () => _showLikesDialog(postId),
                        child: Text(
                          '$likeCount',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: const Color(0xFF2D3748),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      IconButton(
                        icon: Icon(
                          Icons.chat_bubble_outline,
                          color: const Color(0xFF4361EE),
                        ),
                        onPressed: () => _showCommentsSheet(postId),
                      ),
                      Text(
                        '$commentCount',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFF2D3748),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerWidget({super.key, required this.videoUrl});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isError = false;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {});
        _controller.setLooping(true);
        _controller.play();
      }).catchError((e) {
        setState(() => _isError = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF4361EE);
    if (_isError) return Center(child: Icon(Icons.error, color: Colors.red));
    return _controller.value.isInitialized
        ? GestureDetector(
            onTap: () {
              setState(() {
                _isPlaying = !_isPlaying;
                _isPlaying ? _controller.play() : _controller.pause();
              });
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_controller),
                if (!_isPlaying)
                  Icon(
                    Icons.play_circle_fill,
                    size: 50,
                    color: Colors.white.withOpacity(0.7),
                  ),
              ],
            ),
          )
        : Center(child: CircularProgressIndicator(color: primaryColor));
  }
}

class CommentsBottomSheet extends StatelessWidget {
  final int postId;
  final Future<List<Map<String, dynamic>>> Function(int) fetchComments;

  const CommentsBottomSheet({super.key, required this.postId, required this.fetchComments});

  String _getTimeAgo(String dateTime) {
    final date = DateTime.parse(dateTime);
    return timeago.format(date);
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF4361EE);
    const Color secondaryColor = Color(0xFF64748B);
    const Color accentColor = Colors.white;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2)),
            ],
          ),
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: fetchComments(postId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: primaryColor));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 48,
                        color: secondaryColor.withOpacity(0.7),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No comments yet',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: secondaryColor,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final comments = snapshot.data!;
              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: secondaryColor.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Comments',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2D3748),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: comments.length,
                      padding: EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundImage: comment['commenter_photo'] != null
                                    ? CachedNetworkImageProvider(comment['commenter_photo'])
                                    : null,
                                child: comment['commenter_photo'] == null
                                    ? Text(
                                        comment['commenter_name']?[0].toUpperCase() ?? 'U',
                                        style: GoogleFonts.poppins(color: accentColor),
                                      )
                                    : null,
                                backgroundColor: primaryColor.withOpacity(0.1),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: secondaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            comment['commenter_name'] ?? 'Unknown',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF2D3748),
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            comment['comment_content'] ?? '',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: const Color(0xFF2D3748),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(left: 8, top: 4),
                                      child: Text(
                                        _getTimeAgo(comment['created_at']),
                                        style: GoogleFonts.poppins(
                                          color: secondaryColor,
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
                ],
              );
            },
          ),
        );
      },
    );
  }
}