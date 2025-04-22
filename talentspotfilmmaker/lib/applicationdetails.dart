import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talentspotfilmmaker/filmmaker_home_page.dart';
import 'package:talentspotfilmmaker/filmmaker_jobs_page.dart';
import 'package:talentspotfilmmaker/filmmaker_profile_page.dart';
import 'package:talentspotfilmmaker/filmmaker_promotions_page.dart';
import 'package:talentspotfilmmaker/filmmaker_talent_search_page.dart';
import 'package:talentspotfilmmaker/login.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_cached_pdfview/flutter_cached_pdfview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

// Extension to add capitalize method to String
extension StringExtension on String {
  String capitalize() => "${this[0].toUpperCase()}${substring(1)}";
}

// PDF Viewer Screen with updated app bar
class PDFViewerScreen extends StatefulWidget {
  final String url;
  final String title;

  const PDFViewerScreen({super.key, required this.url, required this.title});

  @override
  _PDFViewerScreenState createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  final Completer<PDFViewController> _controller =
      Completer<PDFViewController>();
  int? _totalPages;
  int _currentPage = 0;
  bool _isReady = false;
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: GoogleFonts.poppins(
            fontSize: MediaQuery.of(context).size.width < 600 ? 18 : 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D3748),
          ),
        ),
        backgroundColor: Colors.white, // Matches accentColor
        elevation: 2,
        shadowColor: const Color(0x0D000000).withOpacity(0.05), // Subtle shadow
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.open_in_browser),
        //     onPressed: () async {
        //       final Uri uri = Uri.parse(widget.url);
        //       final String mimeType = _getMimeType(widget.url);
        //       if (await canLaunchUrl(uri)) {
        //         await launchUrl(
        //           uri,
        //           mode: LaunchMode.externalApplication,
        //           webViewConfiguration: WebViewConfiguration(
        //             headers: {'Content-Type': mimeType},
        //           ),
        //         );
        //       } else {
        //         ScaffoldMessenger.of(context).showSnackBar(
        //           SnackBar(content: Text('Could not launch ${widget.url}')),
        //         );
        //       }
        //     },
        //   ),
        // ],
      ),
      body: Stack(
        children: [
          PDF(
            enableSwipe: true,
            swipeHorizontal: true,
            autoSpacing: true,
            pageFling: true,
            defaultPage: _currentPage,
            onPageChanged: (page, total) {
              setState(() {
                _currentPage = page!;
                _totalPages = total;
              });
            },
            onViewCreated: (controller) {
              _controller.complete(controller);
              setState(() {
                _isReady = true;
              });
            },
            onError: (error) {
              setState(() {
                _hasError = true;
              });
              debugPrint('Error loading PDF: $error');
            },
            onRender: (pages) {
              setState(() {
                _totalPages = pages;
              });
            },
          ).cachedFromUrl(widget.url),
          if (_isReady && _totalPages != null)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Page ${_currentPage + 1} of $_totalPages',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          if (!_isReady && !_hasError) _buildLoadingWidget(),
          if (_hasError) _buildErrorWidget(),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4361EE)),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading document...',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            'Failed to load PDF',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.red.shade400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please check the URL or try again later',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _hasError = false;
                _isReady = false;
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4361EE),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMimeType(String url) {
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.endsWith('.pdf')) return 'application/pdf';
    if (lowerUrl.endsWith('.doc') || lowerUrl.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    return 'application/octet-stream';
  }
}

class ApplicationDetailPage extends StatefulWidget {
  final Map<String, dynamic> application;

  const ApplicationDetailPage({super.key, required this.application});

  @override
  State<ApplicationDetailPage> createState() => _ApplicationDetailPageState();
}

class _ApplicationDetailPageState extends State<ApplicationDetailPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = false;
  String _userName = '';
  String _profilePic = '';
  late VideoPlayerController _videoController;

  // Define colors statically
  static const Color primaryColor = Color(0xFF4361EE); // Blue
  static const Color secondaryColor = Color(0xFF64748B); // Gray
  static const Color accentColor = Colors.white; // White
  static const Color backgroundColor = Color(0xFFF8F9FA); // Light Gray

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initializeVideoController();
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final userData =
          await supabase
              .from('tbl_filmmakers')
              .select()
              .eq('filmmaker_id', userId)
              .single();
      if (mounted) {
        setState(() {
          _userName = userData['filmmaker_name'] ?? '';
          _profilePic = userData['filmmaker_photo'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  void _initializeVideoController() {
    final demoVideo = widget.application['demo_video'];
    if (demoVideo != null &&
        demoVideo.toString().toLowerCase().endsWith('.mp4')) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(demoVideo))
        ..initialize()
            .then((_) {
              if (mounted) setState(() {});
              _videoController.play();
              _videoController.setLooping(true);
            })
            .catchError((e) {
              debugPrint('Error initializing video: $e');
            });
    } else {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(''));
    }
  }

  Future<void> _updateApplicationStatus(String status) async {
    setState(() => _isLoading = true);
    try {
      int statusCode =
          status.toLowerCase() == 'accepted'
              ? 1
              : status.toLowerCase() == 'rejected'
              ? 2
              : 0;
      await supabase
          .from('tbl_jobapplication')
          .update({'application_status': statusCode})
          .eq('id', widget.application['id']);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Application ${status.capitalize()} successfully',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: primaryColor,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error updating application: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  void _showApplicationActionForm(String action) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: MediaQuery.of(context).size.width * 0.04,
              right: MediaQuery.of(context).size.width * 0.04,
              top: MediaQuery.of(context).size.height * 0.02,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Application Action',
                  style: GoogleFonts.poppins(
                    fontSize: MediaQuery.of(context).size.width < 600 ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                _buildDetailRow('Action', action.capitalize()),
                SizedBox(height: MediaQuery.of(context).size.height * 0.04),
                ElevatedButton(
                  onPressed:
                      _isLoading
                          ? null
                          : () => _updateApplicationStatus(action),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: EdgeInsets.symmetric(
                      vertical: MediaQuery.of(context).size.height * 0.02,
                      horizontal: MediaQuery.of(context).size.width * 0.1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child:
                      _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                            action.capitalize(),
                            style: GoogleFonts.poppins(
                              fontSize:
                                  MediaQuery.of(context).size.width < 600
                                      ? 14
                                      : 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.02),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.application['tbl_user'] as Map<String, dynamic>;
    final job = widget.application['tbl_job'] as Map<String, dynamic>;
    final status =
        widget.application['application_status'] == 0
            ? 'Pending'
            : widget.application['application_status'] == 1
            ? 'Accepted'
            : 'Rejected';
    final bioData = widget.application['bio_data'];
    final demoVideo = widget.application['demo_video'];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Application Details',
          style: GoogleFonts.poppins(
            fontSize: MediaQuery.of(context).size.width < 600 ? 18 : 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D3748),
          ),
        ),
        backgroundColor: accentColor,
        elevation: 2,
        shadowColor: const Color(0x0D000000).withOpacity(0.05),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: primaryColor,
          onRefresh: () async {
            // Refresh logic if needed
          },
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width * 0.05,
              vertical: MediaQuery.of(context).size.height * 0.02,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _isLoading
                    ? Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    )
                    : Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        padding: EdgeInsets.all(
                          MediaQuery.of(context).size.width * 0.04,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title Section
                            Text(
                              user['user_name'] ?? 'Unknown Applicant',
                              style: GoogleFonts.poppins(
                                fontSize:
                                    MediaQuery.of(context).size.width < 600
                                        ? 16
                                        : 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2D3748),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.01,
                            ),

                            // Details Section
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (user['user_photo'] != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: user['user_photo'],
                                      height:
                                          MediaQuery.of(context).size.height *
                                          0.3,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      placeholder:
                                          (context, url) => Center(
                                            child: CircularProgressIndicator(
                                              color: primaryColor,
                                            ),
                                          ),
                                      errorWidget:
                                          (context, url, error) =>
                                              const Icon(Icons.error, size: 40),
                                    ),
                                  ),
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.02,
                                ),
                                _buildDetailRow(
                                  'Applicant ID',
                                  user['user_id'] ?? 'Not specified',
                                ),
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.01,
                                ),
                                _buildDetailRow(
                                  'Job Title',
                                  job['job_title'] ?? 'Not specified',
                                ),
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.01,
                                ),
                                _buildDetailRow(
                                  'Applied On',
                                  widget.application['apply_date']
                                          ?.toString()
                                          .substring(0, 10) ??
                                      'Not set',
                                ),
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.01,
                                ),
                                _buildDetailRow(
                                  'Budget',
                                  job['job_amount'] ?? 'Not specified',
                                ),
                                if (bioData != null &&
                                    bioData.toString().toLowerCase().endsWith(
                                      '.pdf',
                                    ))
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 8),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) => PDFViewerScreen(
                                                    url: bioData,
                                                    title:
                                                        'Bio Data - ${user['user_name'] ?? 'Applicant'}',
                                                  ),
                                            ),
                                          );
                                        },
                                        child: Text(
                                          'View Bio Data',
                                          style: GoogleFonts.poppins(
                                            fontSize:
                                                MediaQuery.of(
                                                          context,
                                                        ).size.width <
                                                        600
                                                    ? 14
                                                    : 16,
                                            color: primaryColor,
                                            fontWeight: FontWeight.w600,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                if (demoVideo != null &&
                                    demoVideo.toString().toLowerCase().endsWith(
                                      '.mp4',
                                    ))
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildDetailRow(
                                        'Demo Video',
                                        'Video Available',
                                      ),
                                      SizedBox(
                                        height:
                                            MediaQuery.of(context).size.height *
                                            0.01,
                                      ),
                                      SizedBox(
                                        height:
                                            MediaQuery.of(context).size.height *
                                            0.3,
                                        child:
                                            _videoController.value.isInitialized
                                                ? VideoPlayer(_videoController)
                                                : Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: primaryColor,
                                                      ),
                                                ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),

                            // Status and Actions
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.01,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (widget
                                            .application['application_status'] ==
                                        0) ...[
                                      IconButton(
                                        icon: const Icon(
                                          Icons.check,
                                          color: Colors.green,
                                        ),
                                        onPressed:
                                            () => _showApplicationActionForm(
                                              'accepted',
                                            ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.red,
                                        ),
                                        onPressed:
                                            () => _showApplicationActionForm(
                                              'rejected',
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  status,
                                  style: GoogleFonts.poppins(
                                    fontSize:
                                        MediaQuery.of(context).size.width < 600
                                            ? 12
                                            : 14,
                                    color:
                                        status == 'Accepted'
                                            ? Colors.green
                                            : status == 'Rejected'
                                            ? Colors.red
                                            : Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ],
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

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width * 0.05,
        vertical: MediaQuery.of(context).size.height * 0.02,
      ),
      decoration: BoxDecoration(
        color: accentColor,
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $_userName',
                style: GoogleFonts.poppins(
                  fontSize: MediaQuery.of(context).size.width < 600 ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D3748),
                ),
              ),
              Text(
                'Manage Your Applications',
                style: GoogleFonts.poppins(
                  fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
                  color: secondaryColor,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.notifications_outlined, color: primaryColor),
                onPressed: () {},
              ),
              SizedBox(width: MediaQuery.of(context).size.width * 0.02),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FilmmakerProfilePage(),
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: MediaQuery.of(context).size.width * 0.05,
                  backgroundColor: const Color(0xFFE2E8F0),
                  backgroundImage:
                      _profilePic.isNotEmpty
                          ? CachedNetworkImageProvider(_profilePic)
                          : null,
                  child:
                      _profilePic.isEmpty
                          ? Icon(Icons.person, color: secondaryColor)
                          : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
            color: primaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(width: MediaQuery.of(context).size.width * 0.02),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
              color: secondaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
