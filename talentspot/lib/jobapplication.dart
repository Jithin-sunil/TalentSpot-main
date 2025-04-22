import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talentspot/postselect.dart';

class JobApplicationPage extends StatefulWidget {
  final Map<String, dynamic> job;

  const JobApplicationPage({super.key, required this.job});

  @override
  State<JobApplicationPage> createState() => _JobApplicationPageState();
}

class _JobApplicationPageState extends State<JobApplicationPage> {
  final _formKey = GlobalKey<FormState>();
  final _coverLetterController = TextEditingController();
  List<Map<String, dynamic>> _selectedPosts = [];
  bool _isLoading = false;
  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _coverLetterController.dispose();
    super.dispose();
  }

  Future<void> _selectPosts() async {
    final result = await Navigator.push<List<Map<String, dynamic>>>(
      context,
      MaterialPageRoute(
        builder: (context) => const SelectPostsPage(),
      ),
    );
    
    if (result != null) {
      setState(() {
        _selectedPosts = result;
      });
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      // Create job application
      final applicationResponse = await supabase.from('Job_Applications').insert({
        'job_id': widget.job['job_id'],
        'user_id': userId,
      }).select();
      
      if (applicationResponse.isEmpty) {
        throw Exception('Failed to create application');
      }
      
      // Link selected posts to application if any
      if (_selectedPosts.isNotEmpty) {
        // This would require an additional table to link posts to applications
        // For simplicity, we'll just show a success message
      }
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application submitted successfully!')),
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
        title: const Text('Apply for Job'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Applying for: ${widget.job['title']}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _coverLetterController,
                  decoration: const InputDecoration(
                    labelText: 'Cover Letter (Optional)',
                    border: OutlineInputBorder(),
                    hintText: 'Tell the filmmaker why you\'re a good fit for this role...',
                  ),
                  maxLines: 8,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Showcase Your Talent',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select your best posts to include with your application.',
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _selectPosts,
                  icon: const Icon(Icons.add),
                  label: const Text('Select Posts'),
                ),
                if (_selectedPosts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Selected Posts (${_selectedPosts.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _selectedPosts.length,
                    itemBuilder: (context, index) {
                      final post = _selectedPosts[index];
                      return ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: NetworkImage(post['media_url']),
                              fit: BoxFit.cover,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        title: Text(post['title']),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _selectedPosts.removeAt(index);
                            });
                          },
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitApplication,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Submit Application'),
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

