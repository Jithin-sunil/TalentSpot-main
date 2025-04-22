import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talentspot/jobapplication.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';

class JobDetailPage extends StatefulWidget {
  final String jobId;

  const JobDetailPage({super.key, required this.jobId});

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  final supabase = Supabase.instance.client;
  bool _hasApplied = false;
  bool _isLoading = true;
  Map<String, dynamic> _jobDetails = {};
  String? _categoryName;
  File? _bioDataFile;
  File? _demoVideoFile;
  String? _bioDataUrl;
  String? _demoVideoUrl;

  @override
  void initState() {
    super.initState();
    _fetchJobDetails();
    _checkApplicationStatus();
  }

  Future<void> _fetchJobDetails() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('tbl_job')
          .select('*, tbl_category(category_name), tbl_filmmakers(filmmaker_name)')
          .eq('job_id', widget.jobId)
          .single();
      debugPrint('Job details: $response');
      if (mounted) {
        setState(() {
          _jobDetails = response;
          _categoryName = response['tbl_category']['category_name'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching job details: $e');
      if (mounted) {
        setState(() {
          _jobDetails = {};
          _categoryName = null;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load job details'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  Future<void> _checkApplicationStatus() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('tbl_jobapplication')
          .select()
          .eq('job_id', widget.jobId)
          .eq('user_id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() => _hasApplied = response != null);
      }
    } catch (e) {
      debugPrint('Error checking application status: $e');
    }
  }

  Future<void> _pickFile(String type) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: type == 'bio' ? FileType.custom : FileType.video,
      allowedExtensions: type == 'bio' ? ['pdf', 'doc', 'docx'] : null,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        if (type == 'bio') {
          _bioDataFile = File(result.files.single.path!);
        } else {
          _demoVideoFile = File(result.files.single.path!);
        }
      });
    }
  }

  Future<String?> _uploadFile(File file, String folder, String userId, String jobId, String type) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final extension = file.path.split('.').last;
      final fileName = '${userId}_${jobId}_${type}_$timestamp.$extension';

      await supabase.storage.from('job-applications').upload('$folder/$fileName', file);
      return supabase.storage.from('job-applications').getPublicUrl('$folder/$fileName');
    } catch (e) {
      debugPrint('Error uploading file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload $type file'),
          backgroundColor: Colors.red[600],
        ),
      );
      return null;
    }
  }

  Future<void> _applyForJob() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please log in to apply'),
          backgroundColor: Colors.red[600],
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFF8F9FA),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'Apply for Job',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2D3748),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton(
                onPressed: () async {
                  await _pickFile('bio');
                  setDialogState(() {});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4361EE),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  _bioDataFile == null
                      ? 'Upload Bio Data (Required)'
                      : 'Bio Data: ${_bioDataFile!.path.split('/').last}',
                  style: GoogleFonts.poppins(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await _pickFile('video');
                  setDialogState(() {});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4361EE),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  _demoVideoFile == null
                      ? 'Upload Demo Video (Optional)'
                      : 'Video: ${_demoVideoFile!.path.split('/').last}',
                  style: GoogleFonts.poppins(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _bioDataFile = null;
                  _demoVideoFile = null;
                });
                Navigator.pop(context);
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF64748B),
                  fontSize: 14,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _bioDataFile == null
                  ? null
                  : () async {
                      Navigator.pop(context);
                      await _submitApplication(userId);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4361EE),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Submit',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitApplication(String userId) async {
    setState(() => _isLoading = true);

    try {
      if (_bioDataFile == null) {
        throw Exception('Bio data is required');
      }
      _bioDataUrl = await _uploadFile(
        _bioDataFile!,
        'bio_data',
        userId,
        widget.jobId,
        'bio',
      );
      if (_bioDataUrl == null) {
        throw Exception('Failed to upload bio data');
      }

      if (_demoVideoFile != null) {
        _demoVideoUrl = await _uploadFile(
          _demoVideoFile!,
          'demo_videos',
          userId,
          widget.jobId,
          'demo',
        );
      }

      await supabase.from('tbl_jobapplication').insert({
        'job_id': widget.jobId,
        'user_id': userId,
        'bio_data': _bioDataUrl,
        'demo_video': _demoVideoUrl,
        'application_status': 0, // Pending, to align with MyApplicationsPage
      });

      if (mounted) {
        setState(() {
          _hasApplied = true;
          _isLoading = false;
          _bioDataFile = null;
          _demoVideoFile = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Application submitted successfully'),
            backgroundColor: Colors.green[600],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error applying for job: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply: ${e.toString().split(':').last.trim()}'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF4361EE);
    const Color secondaryColor = Color(0xFF64748B);
    const Color accentColor = Colors.white;
    const Color backgroundColor = Color(0xFFF8F9FA);

    final filmmaker = _jobDetails['tbl_filmmakers'] as Map<String, dynamic>? ?? {};

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
          'Job Details',
          style: GoogleFonts.poppins(
            color: accentColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        elevation: 2,
        shadowColor: Colors.black12,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.05,
                vertical: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: accentColor,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _jobDetails['job_title'] ?? 'Unknown Job',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2D3748),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 16,
                                color: secondaryColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Posted by: ${filmmaker['filmmaker_name'] ?? 'Unknown'}',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: secondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    color: accentColor,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Job Details',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2D3748),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildDetailRow(
                            Icons.category,
                            'Category',
                            _categoryName ?? 'N/A',
                          ),
                          _buildDetailRow(
                            Icons.location_on,
                            'Location',
                            _jobDetails['job_location'] ?? 'N/A',
                          ),
                          _buildDetailRow(
                            Icons.calendar_today,
                            'Deadline',
                            _jobDetails['job_lastdate']?.toString().substring(0, 10) ?? 'N/A',
                          ),
                          _buildDetailRow(
                            Icons.attach_money,
                            'Payment',
                            _jobDetails['job_amount']?.toString() ?? 'N/A',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    color: accentColor,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Description',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2D3748),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _jobDetails['job_description'] ?? 'No description available',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              height: 1.5,
                              color: secondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _hasApplied ? null : _applyForJob,
                      icon: Icon(_hasApplied ? Icons.check_circle : Icons.send, size: 20),
                      label: Text(
                        _hasApplied ? 'Already Applied' : 'Apply Now',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: accentColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        disabledBackgroundColor: primaryColor.withOpacity(0.5),
                        disabledForegroundColor: accentColor.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    const Color secondaryColor = Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: secondaryColor),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: secondaryColor,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: secondaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}