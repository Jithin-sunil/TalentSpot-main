import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class EditPostPage extends StatefulWidget {
  final Map<String, dynamic> post;

  const EditPostPage({super.key, required this.post});

  @override
  State<EditPostPage> createState() => _EditPostPageState();
}

class _EditPostPageState extends State<EditPostPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _tagsController;
  late String _selectedCategory;
  File? _mediaFile;
  String? _currentMediaUrl;
  bool _isLoading = false;
  final supabase = Supabase.instance.client;

  final List<String> _categories = [
    'Acting', 'Singing', 'Dancing', 'Modeling', 'Music', 'Comedy', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post['title']);
    _descriptionController = TextEditingController(text: widget.post['description']);
    _tagsController = TextEditingController(text: widget.post['tags']);
    _selectedCategory = widget.post['category'];
    _currentMediaUrl = widget.post['media_url'];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final ImagePicker picker = ImagePicker();
    final XFile? media = await picker.pickImage(source: ImageSource.gallery);
    
    if (media != null) {
      setState(() {
        _mediaFile = File(media.path);
      });
    }
  }

  Future<String?> _uploadMedia() async {
    if (_mediaFile == null) return _currentMediaUrl;
    
    final fileExt = _mediaFile!.path.split('.').last;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final filePath = 'talent_posts/$fileName';
    
    try {
      await supabase.storage.from('media').upload(
        filePath,
        _mediaFile!,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );
      
      return supabase.storage.from('media').getPublicUrl(filePath);
    } catch (e) {
      debugPrint('Error uploading media: $e');
      return null;
    }
  }

  Future<void> _updatePost() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Upload new media if selected
      String? mediaUrl = _currentMediaUrl;
      if (_mediaFile != null) {
        mediaUrl = await _uploadMedia();
        if (mediaUrl == null) {
          throw Exception('Failed to upload media');
        }
      }
      
      // Update post
      await supabase.from('Talent_Posts').update({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'media_url': mediaUrl,
        'category': _selectedCategory,
        'tags': _tagsController.text.trim(),
        'approved': false, // Reset approval status
      }).eq('post_id', widget.post['post_id']);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post updated successfully! Waiting for approval.')),
      );
      
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
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
        title: const Text('Edit Post'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: _pickMedia,
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                      image: _mediaFile != null
                          ? DecorationImage(
                              image: FileImage(_mediaFile!),
                              fit: BoxFit.cover,
                            )
                          : _currentMediaUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(_currentMediaUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                    ),
                    child: _mediaFile == null && _currentMediaUrl == null
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, size: 50),
                                SizedBox(height: 10),
                                Text('Tap to add media'),
                              ],
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedCategory,
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                    });
                  },
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags (comma separated)',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., acting, drama, comedy',
                  ),
                ),
                const SizedBox(height: 25),
                ElevatedButton(
                  onPressed: _isLoading ? null : _updatePost,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Update Post'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

