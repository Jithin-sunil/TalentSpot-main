import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

class FilmmakerTalentFeedPage extends StatefulWidget {
  const FilmmakerTalentFeedPage({super.key});

  @override
  State<FilmmakerTalentFeedPage> createState() =>
      _FilmmakerTalentFeedPageState();
}

class _FilmmakerTalentFeedPageState extends State<FilmmakerTalentFeedPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  String? _currentUserId;
  final TextEditingController _commentController = TextEditingController();
  Map<int, bool> loadingComments = {};
  Map<int, List<Map<String, dynamic>>> postComments = {};
  Map<int, bool> isSubmittingComment = {};

  @override
  void initState() {
    super.initState();
    _currentUserId = supabase.auth.currentUser?.id;
    _fetchPosts();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchPosts() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('tbl_talentpost')
          .select('''
            *,
            tbl_user(user_id, user_name, user_photo),
            tbl_like(*),
            tbl_comment(*)
          ''')
          .order('created_at', ascending: false);

      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        setState(() => _isLoading = false);
        return;
      }

      List<Map<String, dynamic>> postsWithLikes = [];
      for (var post in response) {
        final userLikes = post['tbl_like'] as List<dynamic>;
        final isLikedByUser = userLikes.any(
          (like) =>
              like['filmmaker_id'] == currentUserId ||
              like['user_id'] == currentUserId,
        );
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
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike(int postId, bool isLiked) async {
    try {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      setState(() {
        for (var post in _posts) {
          if (post['id'] == postId) {
            post['is_liked_by_user'] = !isLiked;
            post['like_count'] =
                isLiked
                    ? (post['tbl_like'].length - 1)
                    : (post['tbl_like'].length + 1);
            if (isLiked) {
              post['tbl_like'].removeWhere(
                (like) =>
                    like['filmmaker_id'] == currentUserId ||
                    like['user_id'] == currentUserId,
              );
            } else {
              post['tbl_like'].add({
                'post_id': postId,
                'filmmaker_id': currentUserId,
              });
            }
          }
        }
      });

      if (isLiked) {
        await supabase.from('tbl_like').delete().match({
          'post_id': postId,
          'filmmaker_id': currentUserId,
        });
      } else {
        await supabase.from('tbl_like').insert({
          'post_id': postId,
          'filmmaker_id': currentUserId,
        });
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');
      _fetchPosts();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update like')));
    }
  }

  Future<void> _fetchComments(int postId) async {
    if (loadingComments[postId] == true) return;
    setState(() => loadingComments[postId] = true);
    try {
      final response = await supabase
          .from('tbl_comment')
          .select(
            '*, tbl_user(user_id, user_name, user_photo), tbl_filmmakers(filmmaker_id, filmmaker_name, filmmaker_photo)',
          )
          .eq('post_id', postId)
          .order('created_at', ascending: false);

      setState(() {
        postComments[postId] = List<Map<String, dynamic>>.from(
          response.map((comment) {
            if (comment['filmmaker_id'] != null) {
              final filmmaker =
                  comment['tbl_filmmakers'] as Map<String, dynamic>? ?? {};
              return {
                ...comment,
                'commenter_name': filmmaker['filmmaker_name'] ?? 'Unknown',
                'commenter_photo': filmmaker['filmmaker_photo'],
                'commenter_type': 'filmmaker',
              };
            } else if (comment['user_id'] != null) {
              final user = comment['tbl_user'] as Map<String, dynamic>? ?? {};
              return {
                ...comment,
                'commenter_name': user['user_name'] ?? 'Unknown',
                'commenter_photo': user['user_photo'],
                'commenter_type': 'user',
              };
            }
            return comment;
          }).toList(),
        );
        for (var post in _posts) {
          if (post['id'] == postId) {
            post['tbl_comment'] = postComments[postId];
            post['comment_count'] = post['tbl_comment'].length ?? 0;
          }
        }
        loadingComments[postId] = false;
      });
    } catch (e) {
      debugPrint('Error fetching comments: $e');
      setState(() => loadingComments[postId] = false);
    }
  }

  Future<void> _addComment(int postId) async {
    if (_commentController.text.trim().isEmpty ||
        supabase.auth.currentUser?.id == null)
      return;
    setState(() => isSubmittingComment[postId] = true);
    try {
      final currentFilmmakerId = supabase.auth.currentUser!.id;
      final newComment = {
        'post_id': postId,
        'filmmaker_id': currentFilmmakerId,
        'comment_content': _commentController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      };
      await supabase.from('tbl_comment').insert(newComment);
      _commentController.clear();
      _fetchComments(postId);

      final currentFilmmaker =
          await supabase
              .from('tbl_filmmakers')
              .select('filmmaker_id, filmmaker_name, filmmaker_photo')
              .eq('filmmaker_id', currentFilmmakerId)
              .single();

      setState(() {
        final commentWithFilmmaker = {
          ...newComment,
          'tbl_filmmakers': currentFilmmaker,
          'commenter_name': currentFilmmaker['filmmaker_name'] ?? 'Unknown',
          'commenter_photo': currentFilmmaker['filmmaker_photo'],
          'commenter_type': 'filmmaker',
        };
        for (var post in _posts) {
          if (post['id'] == postId) {
            post['tbl_comment'].add(commentWithFilmmaker);
            post['comment_count'] = post['tbl_comment'].length ?? 0;
          }
        }
        postComments[postId] = List<Map<String, dynamic>>.from(
          postComments[postId] ?? [],
        )..add(commentWithFilmmaker);
      });
    } catch (e) {
      debugPrint('Error adding comment: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add comment')));
      _fetchComments(postId);
    } finally {
      setState(() => isSubmittingComment[postId] = false);
    }
  }

  VoidCallback _showCommentsSheet(int postId) {
    return () {
      _fetchComments(postId);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (context) => CommentsBottomSheet(
              postId: postId,
              comments: postComments[postId] ?? [],
              isLoadingComments: loadingComments[postId] ?? false,
              isSubmitting: isSubmittingComment[postId] ?? false,
              commentController: _commentController,
              onAddComment: () => _addComment(postId),
            ),
      );
    };
  }

  Future<void> _requestForWork(String userId) async {
    try {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      await supabase.from('tbl_hire').insert({
        'filmmaker_id': currentUserId,
        'user_id': userId,
        'hired_at': DateTime.now().toIso8601String(),
        'hire_status': 0,
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Work request sent')));
    } catch (e) {
      debugPrint('Error requesting work: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send work request')));
    }
  }

  void _showUserProfile(String userId) async {
    final userPosts = await supabase
        .from('tbl_talentpost')
        .select('''
          *,
          tbl_user(user_id, user_name, user_photo),
          tbl_like(*),
          tbl_comment(*)
        ''')
        .eq('tbl_user.user_id', userId)
        .order('created_at', ascending: false);

    final currentUserId = supabase.auth.currentUser?.id;
    for (var post in userPosts) {
      final userLikes = post['tbl_like'] as List<dynamic>;
      post['is_liked_by_user'] = userLikes.any(
        (like) =>
            like['filmmaker_id'] == currentUserId ||
            like['user_id'] == currentUserId,
      );
      post['like_count'] = userLikes.length;
      post['comment_count'] = (post['tbl_comment'] as List<dynamic>).length;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => UserProfileBottomSheet(
            userId: userId,
            posts: userPosts,
            onRequestWork: () => _requestForWork(userId),
            onToggleLike: (postId, isLiked) => _toggleLike(postId, isLiked),
            onShowComments: _showCommentsSheet,
          ),
    );
  }

  void _navigateToUserProfilePage(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserProfilePage(userId: userId)),
    );
  }

  String _getTimeAgo(String dateTime) {
    final date = DateTime.parse(dateTime);
    return timeago.format(date);
  }

  @override
  Widget build(BuildContext context) {
    final filteredPosts = _posts;

    const Color primaryColor = Color(0xFF4361EE);
    const Color secondaryColor = Color(0xFF64748B);
    const Color accentColor = Colors.white;
    const Color backgroundColor = Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Talent Feed',
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
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : Column(
                children: [
                  Expanded(
                    child:
                        filteredPosts.isEmpty
                            ? Center(
                              child: Text(
                                'No posts available',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: secondaryColor,
                                ),
                              ),
                            )
                            : RefreshIndicator(
                              color: primaryColor,
                              onRefresh: _fetchPosts,
                              child: ListView.builder(
                                itemCount: filteredPosts.length,
                                padding: EdgeInsets.symmetric(vertical: 8),
                                itemBuilder: (context, index) {
                                  final post = filteredPosts[index];
                                  final user =
                                      post['tbl_user']
                                          as Map<String, dynamic>? ??
                                      {};
                                  final isLiked =
                                      post['is_liked_by_user'] ?? false;
                                  final likeCount = post['like_count'] ?? 0;
                                  final commentCount =
                                      post['comment_count'] ?? 0;
                                  final postId = post['id'];
                                  final postType = post['post_type'] ?? 'image';
                                  final mediaUrl = post['post_file'];
                                  final tags =
                                      (post['post_tags'] as String?)
                                          ?.replaceAll('[', '')
                                          .replaceAll(']', '')
                                          .replaceAll('"', '')
                                          .split(',') ??
                                      [];
                                  return Card(
                                    color: accentColor,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    margin: EdgeInsets.symmetric(
                                      horizontal:
                                          MediaQuery.of(context).size.width *
                                          0.05,
                                      vertical: 8,
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(
                                        MediaQuery.of(context).size.width *
                                            0.04,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: CircleAvatar(
                                              radius: 20,
                                              backgroundImage:
                                                  user['user_photo'] != null
                                                      ? CachedNetworkImageProvider(
                                                        user['user_photo'],
                                                      )
                                                      : null,
                                              child:
                                                  user['user_photo'] == null
                                                      ? Icon(
                                                        Icons.person,
                                                        color: secondaryColor,
                                                      )
                                                      : null,
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
                                                color: secondaryColor,
                                              ),
                                            ),
                                            trailing: PopupMenuButton<String>(
                                              onSelected: (value) {
                                                if (value == 'view_profile') {
                                                  _navigateToUserProfilePage(
                                                    user['user_id'],
                                                  );
                                                }
                                              },
                                              itemBuilder:
                                                  (
                                                    BuildContext context,
                                                  ) => <PopupMenuEntry<String>>[
                                                    const PopupMenuItem<String>(
                                                      value: 'view_profile',
                                                      child: Text(
                                                        'View Profile',
                                                      ),
                                                    ),
                                                  ],
                                              icon: Icon(
                                                Icons.more_vert,
                                                color: primaryColor,
                                              ),
                                            ),
                                            onTap:
                                                () => _showUserProfile(
                                                  user['user_id'],
                                                ),
                                          ),
                                          if (post['post_description']
                                                  ?.trim()
                                                  .isNotEmpty ??
                                              false)
                                            Padding(
                                              padding: EdgeInsets.only(
                                                top: 8,
                                                bottom: 8,
                                              ),
                                              child: Text(
                                                post['post_description'],
                                                style: GoogleFonts.poppins(
                                                  fontSize: 15,
                                                  color: const Color(
                                                    0xFF2D3748,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          if (tags.isNotEmpty)
                                            Padding(
                                              padding: EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              child: Wrap(
                                                spacing: 8,
                                                children:
                                                    tags
                                                        .map(
                                                          (tag) => Chip(
                                                            label: Text(
                                                              tag.trim(),
                                                              style: GoogleFonts.poppins(
                                                                color:
                                                                    accentColor,
                                                              ),
                                                            ),
                                                            backgroundColor:
                                                                primaryColor
                                                                    .withOpacity(
                                                                      0.1,
                                                                    ),
                                                          ),
                                                        )
                                                        .toList(),
                                              ),
                                            ),
                                          if (mediaUrl != null)
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: AspectRatio(
                                                aspectRatio: 16 / 9,
                                                child:
                                                    postType == 'video'
                                                        ? VideoPlayerWidget(
                                                          videoUrl: mediaUrl,
                                                        )
                                                        : CachedNetworkImage(
                                                          imageUrl: mediaUrl,
                                                          fit: BoxFit.cover,
                                                          placeholder:
                                                              (
                                                                context,
                                                                url,
                                                              ) => Center(
                                                                child: CircularProgressIndicator(
                                                                  color:
                                                                      primaryColor,
                                                                ),
                                                              ),
                                                          errorWidget:
                                                              (
                                                                context,
                                                                url,
                                                                error,
                                                              ) => Icon(
                                                                Icons.error,
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                        ),
                                              ),
                                            ),
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    IconButton(
                                                      icon: Icon(
                                                        isLiked
                                                            ? Icons.favorite
                                                            : Icons
                                                                .favorite_border,
                                                        color:
                                                            isLiked
                                                                ? Colors.red
                                                                : null,
                                                      ),
                                                      onPressed:
                                                          () => _toggleLike(
                                                            postId,
                                                            isLiked,
                                                          ),
                                                    ),
                                                    Text(
                                                      '$likeCount',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 14,
                                                            color: const Color(
                                                              0xFF2D3748,
                                                            ),
                                                          ),
                                                    ),
                                                    SizedBox(width: 16),
                                                    IconButton(
                                                      icon: Icon(
                                                        Icons
                                                            .chat_bubble_outline,
                                                        color: primaryColor,
                                                      ),
                                                      onPressed:
                                                          () =>
                                                              _showCommentsSheet(
                                                                postId,
                                                              )(),
                                                    ),
                                                    Text(
                                                      '$commentCount',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 14,
                                                            color: const Color(
                                                              0xFF2D3748,
                                                            ),
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                                IconButton(
                                                  icon: Icon(
                                                    Icons.share,
                                                    color: primaryColor,
                                                  ),
                                                  onPressed: () {},
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                  ),
                ],
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
      ..initialize()
          .then((_) {
            setState(() {});
            _controller.setLooping(true);
            _controller.play();
          })
          .catchError((e) {
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
        : Center(
          child: CircularProgressIndicator(color: const Color(0xFF4361EE)),
        );
  }
}

class CommentsBottomSheet extends StatelessWidget {
  final int postId;
  final List<Map<String, dynamic>> comments;
  final bool isLoadingComments;
  final bool isSubmitting;
  final TextEditingController commentController;
  final VoidCallback onAddComment;

  const CommentsBottomSheet({
    super.key,
    required this.postId,
    required this.comments,
    required this.isLoadingComments,
    required this.isSubmitting,
    required this.commentController,
    required this.onAddComment,
  });

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
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(
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
                child:
                    isLoadingComments
                        ? Center(
                          child: CircularProgressIndicator(color: primaryColor),
                        )
                        : comments.isEmpty
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
                                    backgroundImage:
                                        comment['commenter_photo'] != null
                                            ? CachedNetworkImageProvider(
                                              comment['commenter_photo'],
                                            )
                                            : null,
                                    child:
                                        comment['commenter_photo'] == null
                                            ? Text(
                                              comment['commenter_name']?[0]
                                                      .toUpperCase() ??
                                                  'U',
                                              style: GoogleFonts.poppins(
                                                color: accentColor,
                                              ),
                                            )
                                            : null,
                                    backgroundColor: primaryColor.withOpacity(
                                      0.1,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: secondaryColor.withOpacity(
                                              0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                comment['commenter_name'] ??
                                                    'Unknown',
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(
                                                    0xFF2D3748,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                comment['comment_content'] ??
                                                    '',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  color: const Color(
                                                    0xFF2D3748,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.only(
                                            left: 8,
                                            top: 4,
                                          ),
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
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        decoration: InputDecoration(
                          hintText: 'Write a comment...',
                          filled: true,
                          fillColor: secondaryColor.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      icon:
                          isSubmitting
                              ? CircularProgressIndicator(
                                strokeWidth: 2,
                                color: primaryColor,
                              )
                              : Icon(Icons.send, color: primaryColor),
                      onPressed: isSubmitting ? null : onAddComment,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class UserProfileBottomSheet extends StatefulWidget {
  final String userId;
  final List<Map<String, dynamic>> posts;
  final VoidCallback onRequestWork;
  final Future<void> Function(int, bool) onToggleLike;
  final VoidCallback Function(int) onShowComments;

  const UserProfileBottomSheet({
    super.key,
    required this.userId,
    required this.posts,
    required this.onRequestWork,
    required this.onToggleLike,
    required this.onShowComments,
  });

  @override
  State<UserProfileBottomSheet> createState() => _UserProfileBottomSheetState();
}

class _UserProfileBottomSheetState extends State<UserProfileBottomSheet> {
  bool _isLoadingRequest = false;

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF4361EE);
    const Color secondaryColor = Color(0xFF64748B);
    const Color accentColor = Colors.white;

    final user =
        widget.posts.isNotEmpty
            ? widget.posts[0]['tbl_user'] as Map<String, dynamic>
            : {};
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundImage:
                              user['user_photo'] != null
                                  ? CachedNetworkImageProvider(
                                    user['user_photo'],
                                  )
                                  : null,
                          child:
                              user['user_photo'] == null
                                  ? Icon(Icons.person, color: secondaryColor)
                                  : null,
                        ),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['user_name'] ?? 'Unknown',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2D3748),
                              ),
                            ),
                            Text(
                              '${widget.posts.length} Posts',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: secondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child:
                    widget.posts.isEmpty
                        ? Center(
                          child: Text(
                            'No posts available',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: secondaryColor,
                            ),
                          ),
                        )
                        : ListView.builder(
                          controller: scrollController,
                          itemCount: widget.posts.length,
                          padding: EdgeInsets.all(16),
                          itemBuilder: (context, index) {
                            final post = widget.posts[index];
                            final isLiked = post['is_liked_by_user'] ?? false;
                            final likeCount = post['like_count'] ?? 0;
                            final commentCount = post['comment_count'] ?? 0;
                            final postId = post['id'];
                            final postType = post['post_type'] ?? 'image';
                            final mediaUrl = post['post_file'];
                            return Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              margin: EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (post['post_description']
                                            ?.trim()
                                            .isNotEmpty ??
                                        false)
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
                                    if (mediaUrl != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: AspectRatio(
                                          aspectRatio: 16 / 9,
                                          child:
                                              postType == 'video'
                                                  ? VideoPlayerWidget(
                                                    videoUrl: mediaUrl,
                                                  )
                                                  : CachedNetworkImage(
                                                    imageUrl: mediaUrl,
                                                    fit: BoxFit.cover,
                                                    placeholder:
                                                        (
                                                          context,
                                                          url,
                                                        ) => Center(
                                                          child:
                                                              CircularProgressIndicator(
                                                                color:
                                                                    primaryColor,
                                                              ),
                                                        ),
                                                    errorWidget:
                                                        (context, url, error) =>
                                                            Icon(
                                                              Icons.error,
                                                              color: Colors.red,
                                                            ),
                                                  ),
                                        ),
                                      ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  isLiked
                                                      ? Icons.favorite
                                                      : Icons.favorite_border,
                                                  color:
                                                      isLiked
                                                          ? Colors.red
                                                          : null,
                                                ),
                                                onPressed:
                                                    () => widget.onToggleLike(
                                                      postId,
                                                      isLiked,
                                                    ),
                                              ),
                                              Text(
                                                '$likeCount',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  color: const Color(
                                                    0xFF2D3748,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 16),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.chat_bubble_outline,
                                                  color: primaryColor,
                                                ),
                                                onPressed:
                                                    () =>
                                                        widget.onShowComments(
                                                          postId,
                                                        )(),
                                              ),
                                              Text(
                                                '$commentCount',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  color: const Color(
                                                    0xFF2D3748,
                                                  ),
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
                          },
                        ),
              ),
              Padding(
                padding: EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed:
                      _isLoadingRequest
                          ? null
                          : () {
                            setState(() => _isLoadingRequest = true);
                            widget.onRequestWork();
                            setState(() => _isLoadingRequest = false);
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _isLoadingRequest
                          ? CircularProgressIndicator(color: accentColor)
                          : Text(
                            'Request for Work',
                            style: GoogleFonts.poppins(
                              color: accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class UserProfilePage extends StatefulWidget {
  final String userId;
  const UserProfilePage({super.key, required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? _userDetails;
  List<Map<String, dynamic>> _userPosts = [];
  bool _isLoading = true;
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _requestMessageController =
      TextEditingController(); // New controller for request message
  Map<int, bool> loadingComments = {};
  Map<int, List<Map<String, dynamic>>> postComments = {};
  Map<int, bool> isSubmittingComment = {};

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _requestMessageController.dispose(); // Dispose the new controller
    super.dispose();
  }

  Future<void> _fetchUserDetails() async {
    setState(() => _isLoading = true);
    try {
      final userResponse =
          await supabase
              .from('tbl_user')
              .select()
              .eq('user_id', widget.userId)
              .single();
      final postsResponse = await supabase
          .from('tbl_talentpost')
          .select(
            '*, tbl_user(user_id, user_name, user_photo), tbl_like(*), tbl_comment(*)',
          )
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);
      for (var post in postsResponse) {
        final userLikes = post['tbl_like'] as List<dynamic>;
        post['is_liked_by_user'] = userLikes.any(
          (like) =>
              like['filmmaker_id'] == supabase.auth.currentUser?.id ||
              like['user_id'] == supabase.auth.currentUser?.id,
        );
        post['like_count'] = userLikes.length;
        post['comment_count'] = (post['tbl_comment'] as List<dynamic>).length;
      }
      setState(() {
        _userDetails = userResponse;
        _userPosts = postsResponse;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching user details: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike(int postId, bool isLiked) async {
    try {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      setState(() {
        for (var post in _userPosts) {
          if (post['id'] == postId) {
            post['is_liked_by_user'] = !isLiked;
            post['like_count'] =
                isLiked
                    ? (post['tbl_like'].length - 1)
                    : (post['tbl_like'].length + 1);
            if (isLiked) {
              post['tbl_like'].removeWhere(
                (like) =>
                    like['filmmaker_id'] == currentUserId ||
                    like['user_id'] == currentUserId,
              );
            } else {
              post['tbl_like'].add({
                'post_id': postId,
                'filmmaker_id': currentUserId,
              });
            }
          }
        }
      });

      if (isLiked) {
        await supabase.from('tbl_like').delete().match({
          'post_id': postId,
          'filmmaker_id': currentUserId,
        });
      } else {
        await supabase.from('tbl_like').insert({
          'post_id': postId,
          'filmmaker_id': currentUserId,
        });
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');
      _fetchUserDetails();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update like')));
    }
  }

  Future<void> _fetchComments(int postId) async {
    if (loadingComments[postId] == true) return;
    setState(() => loadingComments[postId] = true);
    try {
      final response = await supabase
          .from('tbl_comment')
          .select(
            '*, tbl_user(user_id, user_name, user_photo), tbl_filmmakers(filmmaker_id, filmmaker_name, filmmaker_photo)',
          )
          .eq('post_id', postId)
          .order('created_at', ascending: false);

      setState(() {
        postComments[postId] = List<Map<String, dynamic>>.from(
          response.map((comment) {
            if (comment['filmmaker_id'] != null) {
              final filmmaker =
                  comment['tbl_filmmakers'] as Map<String, dynamic>? ?? {};
              return {
                ...comment,
                'commenter_name': filmmaker['filmmaker_name'] ?? 'Unknown',
                'commenter_photo': filmmaker['filmmaker_photo'],
                'commenter_type': 'filmmaker',
              };
            } else if (comment['user_id'] != null) {
              final user = comment['tbl_user'] as Map<String, dynamic>? ?? {};
              return {
                ...comment,
                'commenter_name': user['user_name'] ?? 'Unknown',
                'commenter_photo': user['user_photo'],
                'commenter_type': 'user',
              };
            }
            return comment;
          }).toList(),
        );
        for (var post in _userPosts) {
          if (post['id'] == postId) {
            post['tbl_comment'] = postComments[postId];
            post['comment_count'] = post['tbl_comment'].length ?? 0;
          }
        }
        loadingComments[postId] = false;
      });
    } catch (e) {
      debugPrint('Error fetching comments: $e');
      setState(() => loadingComments[postId] = false);
    }
  }

  Future<void> _addComment(int postId) async {
    if (_commentController.text.trim().isEmpty ||
        supabase.auth.currentUser?.id == null)
      return;
    setState(() => isSubmittingComment[postId] = true);
    try {
      final currentFilmmakerId = supabase.auth.currentUser!.id;
      final newComment = {
        'post_id': postId,
        'filmmaker_id': currentFilmmakerId,
        'comment_content': _commentController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      };
      await supabase.from('tbl_comment').insert(newComment);
      _commentController.clear();

      final currentFilmmaker =
          await supabase
              .from('tbl_filmmakers')
              .select('filmmaker_id, filmmaker_name, filmmaker_photo')
              .eq('filmmaker_id', currentFilmmakerId)
              .single();

      setState(() {
        final commentWithFilmmaker = {
          ...newComment,
          'tbl_filmmakers': currentFilmmaker,
          'commenter_name': currentFilmmaker['filmmaker_name'] ?? 'Unknown',
          'commenter_photo': currentFilmmaker['filmmaker_photo'],
          'commenter_type': 'filmmaker',
        };
        for (var post in _userPosts) {
          if (post['id'] == postId) {
            post['tbl_comment'].add(commentWithFilmmaker);
            post['comment_count'] = post['tbl_comment'].length ?? 0;
          }
        }
        postComments[postId] = List<Map<String, dynamic>>.from(
          postComments[postId] ?? [],
        )..add(commentWithFilmmaker);
      });
    } catch (e) {
      debugPrint('Error adding comment: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add comment')));
      _fetchComments(postId);
    } finally {
      setState(() => isSubmittingComment[postId] = false);
    }
  }

  VoidCallback _showCommentsSheet(int postId) {
    return () {
      _fetchComments(postId);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (context) => CommentsBottomSheet(
              postId: postId,
              comments: postComments[postId] ?? [],
              isLoadingComments: loadingComments[postId] ?? false,
              isSubmitting: isSubmittingComment[postId] ?? false,
              commentController: _commentController,
              onAddComment: () => _addComment(postId),
            ),
      );
    };
  }

  Future<void> _sendRequest() async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null || _requestMessageController.text.trim().isEmpty)
      return;

    try {
      await supabase.from('tbl_hire').insert({
        'filmmaker_id': currentUserId,
        'user_id': widget.userId,
        'created_at': DateTime.now().toIso8601String(),
        'hire_status': 0,
        'hire_message':
            _requestMessageController.text.trim(), // Add message to tbl_hire
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Work request sent successfully')));
      _requestMessageController.clear();
      Navigator.of(context).pop(); // Close the dialog
    } catch (e) {
      debugPrint('Error sending request: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send work request')));
    }
  }

  void _showSendRequestDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Send Work Request',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2D3748),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter your message for the request:',
                  style: GoogleFonts.poppins(color: const Color(0xFF64748B)),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _requestMessageController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Type your message here...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(color: const Color(0xFF4361EE)),
                ),
              ),
              ElevatedButton(
                onPressed: _sendRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4361EE),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Send',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ],
          ),
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
      appBar: AppBar(
        title: Text(
          'User Profile',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D3748),
          ),
        ),
        backgroundColor: accentColor,
        elevation: 2,
        shadowColor: const Color(0x0D000000).withOpacity(0.05),
        actions: [
          IconButton(
            icon: Icon(Icons.send, color: primaryColor),
            onPressed: _showSendRequestDialog, // Trigger the dialog
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage:
                              _userDetails?['user_photo'] != null
                                  ? CachedNetworkImageProvider(
                                    _userDetails!['user_photo'],
                                  )
                                  : null,
                          child:
                              _userDetails?['user_photo'] == null
                                  ? Icon(
                                    Icons.person,
                                    size: 50,
                                    color: secondaryColor,
                                  )
                                  : null,
                        ),
                      ),
                      SizedBox(height: 16),
                      Center(
                        child: Text(
                          _userDetails?['user_name'] ?? 'Unknown',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2D3748),
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Age: ${_userDetails?['user_age'] ?? 'N/A'}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: secondaryColor,
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          'Gender: ${_userDetails?['user_gender'] ?? 'N/A'}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: secondaryColor,
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          'Contact: ${_userDetails?['user_contact'] ?? 'N/A'}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: secondaryColor,
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Posts',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2D3748),
                        ),
                      ),
                      _userPosts.isEmpty
                          ? Center(
                            child: Text(
                              'No posts available',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: secondaryColor,
                              ),
                            ),
                          )
                          : ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: _userPosts.length,
                            itemBuilder: (context, index) {
                              final post = _userPosts[index];
                              final isLiked = post['is_liked_by_user'] ?? false;
                              final likeCount = post['like_count'] ?? 0;
                              final commentCount = post['comment_count'] ?? 0;
                              final postId = post['id'];
                              final postType = post['post_type'] ?? 'image';
                              final mediaUrl = post['post_file'];
                              final tags =
                                  (post['post_tags'] as String?)
                                      ?.replaceAll('[', '')
                                      .replaceAll(']', '')
                                      .replaceAll('"', '')
                                      .split(',') ??
                                  [];
                              return Card(
                                color: accentColor,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                margin: EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (post['post_description']
                                              ?.trim()
                                              .isNotEmpty ??
                                          false)
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
                                            children:
                                                tags
                                                    .map(
                                                      (tag) => Chip(
                                                        label: Text(
                                                          tag.trim(),
                                                          style:
                                                              GoogleFonts.poppins(
                                                                color:
                                                                    accentColor,
                                                              ),
                                                        ),
                                                        backgroundColor:
                                                            primaryColor
                                                                .withOpacity(
                                                                  0.1,
                                                                ),
                                                      ),
                                                    )
                                                    .toList(),
                                          ),
                                        ),
                                      if (mediaUrl != null)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: AspectRatio(
                                            aspectRatio: 16 / 9,
                                            child:
                                                postType == 'video'
                                                    ? VideoPlayerWidget(
                                                      videoUrl: mediaUrl,
                                                    )
                                                    : CachedNetworkImage(
                                                      imageUrl: mediaUrl,
                                                      fit: BoxFit.cover,
                                                      placeholder:
                                                          (
                                                            context,
                                                            url,
                                                          ) => Center(
                                                            child: CircularProgressIndicator(
                                                              color:
                                                                  primaryColor,
                                                            ),
                                                          ),
                                                      errorWidget:
                                                          (
                                                            context,
                                                            url,
                                                            error,
                                                          ) => Icon(
                                                            Icons.error,
                                                            color: Colors.red,
                                                          ),
                                                    ),
                                          ),
                                        ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                IconButton(
                                                  icon: Icon(
                                                    isLiked
                                                        ? Icons.favorite
                                                        : Icons.favorite_border,
                                                    color:
                                                        isLiked
                                                            ? Colors.red
                                                            : null,
                                                  ),
                                                  onPressed:
                                                      () => _toggleLike(
                                                        postId,
                                                        isLiked,
                                                      ),
                                                ),
                                                Text(
                                                  '$likeCount',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14,
                                                    color: const Color(
                                                      0xFF2D3748,
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 16),
                                                IconButton(
                                                  icon: Icon(
                                                    Icons.chat_bubble_outline,
                                                    color: primaryColor,
                                                  ),
                                                  onPressed:
                                                      () =>
                                                          _showCommentsSheet(
                                                            postId,
                                                          )(),
                                                ),
                                                Text(
                                                  '$commentCount',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14,
                                                    color: const Color(
                                                      0xFF2D3748,
                                                    ),
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
                            },
                          ),
                    ],
                  ),
                ),
              ),
    );
  }
}
