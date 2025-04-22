import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:google_fonts/google_fonts.dart';

class PostDetailPage extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostDetailPage({super.key, required this.post});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final supabase = Supabase.instance.client;
  int _likeCount = 0;
  int _commentCount = 0;
  bool _isLoading = true;
  String? _currentUserId;
  bool _userLiked = false;
  List<Map<String, dynamic>> _comments = [];
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingComment = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = supabase.auth.currentUser?.id;
    _fetchData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchLikesData(),
      _fetchComments(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchLikesData() async {
    try {
      final likesResponse = await supabase
          .from('tbl_like')
          .select()
          .eq('post_id', widget.post['id']);
      _likeCount = likesResponse.length;

      if (_currentUserId != null) {
        final userLikeResponse = await supabase
            .from('tbl_like')
            .select()
            .eq('post_id', widget.post['id'])
            .eq('user_id', _currentUserId!)
            .maybeSingle();
        _userLiked = userLikeResponse != null;
      }
    } catch (e) {
      debugPrint('Error fetching likes data: $e');
    }
  }

  Future<void> _fetchComments() async {
    try {
      final response = await supabase
          .from('tbl_comment')
          .select(
            '*, tbl_user(user_id, user_name, user_photo), tbl_filmmakers(filmmaker_id, filmmaker_name, filmmaker_photo)',
          )
          .eq('post_id', widget.post['id'])
          .order('created_at', ascending: false);

      _comments = List<Map<String, dynamic>>.from(
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
      _commentCount = _comments.length;
    } catch (e) {
      debugPrint('Error fetching comments: $e');
    }
  }

  Future<void> _toggleLike() async {
    if (_currentUserId == null) return;
    try {
      final existingLike = await supabase
          .from('tbl_like')
          .select()
          .eq('post_id', widget.post['id'])
          .eq('user_id', _currentUserId!)
          .maybeSingle();

      if (existingLike != null) {
        await supabase.from('tbl_like').delete().eq('like_id', existingLike['like_id']);
        setState(() {
          _userLiked = false;
          _likeCount--;
        });
      } else {
        await supabase.from('tbl_like').insert({
          'post_id': widget.post['id'],
          'user_id': _currentUserId,
        });
        setState(() {
          _userLiked = true;
          _likeCount++;
        });
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update like')));
    }
  }

  Future<void> _deletePost() async {
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
        await supabase.from('tbl_talentpost').delete().eq('id', widget.post['id']);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Post deleted successfully')));
        Navigator.pop(context);
      } catch (e) {
        debugPrint('Error deleting post: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting post')));
      }
    }
  }

  Future<void> _deleteComment(int commentId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Comment', style: GoogleFonts.poppins()),
        content: Text('Are you sure you want to delete this comment?', style: GoogleFonts.poppins()),
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
        await supabase.from('tbl_comment').delete().eq('id', commentId);
        await _fetchComments();
        setState(() {});
      } catch (e) {
        debugPrint('Error deleting comment: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting comment')));
      }
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty || _currentUserId == null) return;
    setState(() => _isSubmittingComment = true);
    try {
      final newComment = {
        'post_id': widget.post['id'],
        'user_id': _currentUserId,
        'comment_content': _commentController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      };
      await supabase.from('tbl_comment').insert(newComment);
      _commentController.clear();
      await _fetchComments();
      setState(() => _isSubmittingComment = false);
    } catch (e) {
      debugPrint('Error adding comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add comment')));
      setState(() => _isSubmittingComment = false);
    }
  }

  void _showLikesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Liked by', style: GoogleFonts.poppins()),
        content: FutureBuilder<List<dynamic>>(
          future: supabase
              .from('tbl_like')
              .select('user_id, tbl_user!inner(user_name)')
              .eq('post_id', widget.post['id'])
              .then((res) => res as List<dynamic>),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            final likes = snapshot.data ?? [];
            return likes.isEmpty
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
                            like['tbl_user']['user_name'] ?? 'Unknown',
                            style: GoogleFonts.poppins(),
                          ),
                        );
                      },
                    ),
                  );
          },
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

    final user = widget.post['tbl_user'] as Map<String, dynamic>? ?? {};
    final isOwner = widget.post['user_id'] == _currentUserId;
    final isAdmin = supabase.auth.currentUser?.role == 'admin';
    final tags = (widget.post['post_tags'] as String?)
            ?.replaceAll('[', '')
            .replaceAll(']', '')
            .replaceAll('"', '')
            .split(',')
            .map((tag) => tag.trim())
            .toList() ??
        [];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Post Details',
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
          if (isOwner || isAdmin)
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: _deletePost,
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.05,
                vertical: 8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: accentColor,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
                              backgroundImage: user['user_photo'] != null
                                  ? CachedNetworkImageProvider(user['user_photo'])
                                  : null,
                              child: user['user_photo'] == null
                                  ? Icon(Icons.person, color: secondaryColor)
                                  : null,
                            ),
                            title: Text(
                              user['user_name'] ?? 'Unknown',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2D3748),
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                Text(
                                  _getTimeAgo(widget.post['created_at']),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: secondaryColor,
                                  ),
                                ),
                                if (widget.post['is_highlighted'] == true)
                                  Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: Icon(Icons.star, color: Colors.amber, size: 16),
                                  ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.share, color: primaryColor),
                              onPressed: () {},
                            ),
                          ),
                          if (widget.post['post_title']?.trim().isNotEmpty ?? false)
                            Padding(
                              padding: EdgeInsets.only(top: 8, bottom: 8),
                              child: Text(
                                widget.post['post_title'],
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2D3748),
                                ),
                              ),
                            ),
                          if (widget.post['post_description']?.trim().isNotEmpty ?? false)
                            Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text(
                                widget.post['post_description'],
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
                                            color: accentColor,
                                          ),
                                        ),
                                        backgroundColor: primaryColor.withOpacity(0.1),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          if (widget.post['post_file'] != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: widget.post['post_type'] == 'video'
                                    ? VideoPlayerWidget(videoUrl: widget.post['post_file'])
                                    : CachedNetworkImage(
                                        imageUrl: widget.post['post_file'],
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Center(
                                          child: CircularProgressIndicator(color: primaryColor),
                                        ),
                                        errorWidget: (context, url, error) => Icon(
                                          Icons.error,
                                          color: Colors.red,
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
                                        _userLiked ? Icons.favorite : Icons.favorite_border,
                                        color: _userLiked ? Colors.red : null,
                                      ),
                                      onPressed: _toggleLike,
                                    ),
                                    GestureDetector(
                                      onTap: _showLikesDialog,
                                      child: Text(
                                        '$_likeCount',
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
                                        color: primaryColor,
                                      ),
                                      onPressed: () {},
                                    ),
                                    Text(
                                      '$_commentCount',
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
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Comments',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2D3748),
                    ),
                  ),
                  SizedBox(height: 8),
                  _comments.isEmpty
                      ? Center(
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
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: _comments.length,
                          itemBuilder: (context, index) {
                            final comment = _comments[index];
                            final isCommentOwner = comment['user_id'] == _currentUserId;
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
                                  if (isCommentOwner || isAdmin)
                                    IconButton(
                                      icon: Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteComment(comment['id']),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                  SizedBox(height: 16),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: InputDecoration(
                              hintText: 'Write a comment...',
                              filled: true,
                              fillColor: secondaryColor.withOpacity(0.1),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            maxLines: null,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ),
                        SizedBox(width: 8),
                        IconButton(
                          icon: _isSubmittingComment
                              ? CircularProgressIndicator(strokeWidth: 2, color: primaryColor)
                              : Icon(Icons.send, color: primaryColor),
                          onPressed: _isSubmittingComment ? null : _addComment,
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
  Widget build(Context) {
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