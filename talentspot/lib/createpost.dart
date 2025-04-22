import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  PlatformFile? _mediaFile;
  String? _mediaType;
  VideoPlayerController? _videoController;
  bool _isLoading = false;
  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(bool isVideo) async {
    FileType fileType = isVideo ? FileType.video : FileType.image;

    FilePickerResult? result = await FilePicker.platform.pickFiles(type: fileType);

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _mediaFile = result.files.first;
        _mediaType = isVideo ? 'video' : 'image';

        if (_mediaType == 'video' && _mediaFile!.path != null) {
          _videoController?.dispose();
          _videoController = VideoPlayerController.file(File(_mediaFile!.path!))
            ..initialize().then((_) {
              setState(() {});
            }).catchError((e) {
              debugPrint('Error initializing video: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to load video preview')),
              );
            });
        }
      });
    }
  }

  Future<String?> _uploadMedia() async {
    if (_mediaFile == null) return null;

    final fileExt = _mediaFile!.name.split('.').last;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    Uint8List? fileBytes;

    try {
      // Handle file bytes differently for web vs mobile
      if (_mediaFile!.bytes != null) {
        // Web platform
        fileBytes = _mediaFile!.bytes!;
      } else if (_mediaFile!.path != null) {
        // Mobile platform
        fileBytes = await File(_mediaFile!.path!).readAsBytes();
      } else {
        throw Exception('No file bytes or path available');
      }

      await supabase.storage.from('media').uploadBinary(fileName, fileBytes);
      return supabase.storage.from('media').getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Error uploading media: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload media. Please try again.'),
          backgroundColor: Colors.red[600],
        ),
      );
      return null;
    }
  }

  Future<void> _createPost() async {
    if (!_formKey.currentState!.validate() || _mediaFile == null) {
      if (_mediaFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select an image or video to upload.'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final mediaUrl = await _uploadMedia();
      if (mediaUrl == null) {
        throw Exception('Media upload failed');
      }

      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      await supabase.from('tbl_talentpost').insert({
        'user_id': userId,
        'post_title': _titleController.text.trim(),
        'post_description': _descriptionController.text.trim(),
        'post_file': mediaUrl,
        'post_tags': tags, // Store as array for Supabase
        'post_type': _mediaType,
        'post_status': 0,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Post created successfully! Waiting for approval.'),
          backgroundColor: Colors.green[600],
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error creating post: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create post: ${e.toString().split(':').last.trim()}'),
          backgroundColor: Colors.red[600],
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4361EE), Color(0xFF64748B)],
            ),
          ),
        ),
        title: Text(
          'Create Post',
          style: GoogleFonts.poppins(
            color: accentColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        elevation: 2,
        shadowColor: Colors.black12,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.05,
            vertical: 16,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: accentColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      builder: (context) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: Icon(Icons.image, color: primaryColor, size: 28),
                              title: Text(
                                'Pick Image',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: const Color(0xFF2D3748),
                                ),
                              ),
                              onTap: () async {
                                Navigator.pop(context);
                                await _pickMedia(false);
                              },
                            ),
                            ListTile(
                              leading: Icon(Icons.video_library, color: primaryColor, size: 28),
                              title: Text(
                                'Pick Video',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: const Color(0xFF2D3748),
                                ),
                              ),
                              onTap: () async {
                                Navigator.pop(context);
                                await _pickMedia(true);
                              },
                            ),
                            SizedBox(height: 16),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    height: MediaQuery.of(context).size.width * 0.5,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _mediaFile == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo,
                                  size: 50,
                                  color: secondaryColor,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Tap to add image or video',
                                  style: GoogleFonts.poppins(
                                    color: secondaryColor,
                                    fontSize: 14,
                                  ),
                                  semanticsLabel: 'Tap to add image or video',
                                ),
                              ],
                            ),
                          )
                        : _mediaType == 'image'
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _mediaFile!.path != null
                                    ? Image.file(
                                        File(_mediaFile!.path!),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                        errorBuilder: (context, error, stackTrace) => Center(
                                          child: Icon(
                                            Icons.error,
                                            color: Colors.red[600],
                                            size: 50,
                                          ),
                                        ),
                                      )
                                    : Image.memory(
                                        _mediaFile!.bytes ?? Uint8List(0),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                        errorBuilder: (context, error, stackTrace) => Center(
                                          child: Icon(
                                            Icons.error,
                                            color: Colors.red[600],
                                            size: 50,
                                          ),
                                        ),
                                      ),
                              )
                            : _videoController != null && _videoController!.value.isInitialized
                                ? Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      AspectRatio(
                                        aspectRatio: _videoController!.value.aspectRatio,
                                        child: VideoPlayer(_videoController!),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                                          size: 48,
                                          color: accentColor.withOpacity(0.8),
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _videoController!.value.isPlaying
                                                ? _videoController!.pause()
                                                : _videoController!.play();
                                          });
                                        },
                                      ),
                                    ],
                                  )
                                : Center(
                                    child: CircularProgressIndicator(color: primaryColor),
                                  ),
                  ),
                ),
                SizedBox(height: 24),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    labelStyle: GoogleFonts.poppins(color: secondaryColor),
                    prefixIcon: Icon(Icons.title, color: secondaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: secondaryColor.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: secondaryColor.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryColor),
                    ),
                    filled: true,
                    fillColor: accentColor,
                  ),
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF2D3748),
                    fontSize: 14,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Please enter a title' : null,
                  // semanticsLabel: 'Post title',
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: GoogleFonts.poppins(color: secondaryColor),
                    prefixIcon: Icon(Icons.description, color: secondaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: secondaryColor.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: secondaryColor.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryColor),
                    ),
                    filled: true,
                    fillColor: accentColor,
                  ),
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF2D3748),
                    fontSize: 14,
                  ),
                  maxLines: 5,
                  validator: (value) => value == null || value.trim().isEmpty ? 'Please enter a description' : null,
                  // semanticsLabel: 'Post description',
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _tagsController,
                  decoration: InputDecoration(
                    labelText: 'Tags (comma separated)',
                    labelStyle: GoogleFonts.poppins(color: secondaryColor),
                    prefixIcon: Icon(Icons.tag, color: secondaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: secondaryColor.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: secondaryColor.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryColor),
                    ),
                    filled: true,
                    fillColor: accentColor,
                    hintText: 'e.g., acting, drama, comedy',
                    hintStyle: GoogleFonts.poppins(color: secondaryColor.withOpacity(0.5)),
                  ),
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF2D3748),
                    fontSize: 14,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Please enter at least one tag' : null,
                  // semanticsLabel: 'Post tags',
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _createPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: accentColor,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: accentColor)
                      : Text(
                          'Create Post',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}