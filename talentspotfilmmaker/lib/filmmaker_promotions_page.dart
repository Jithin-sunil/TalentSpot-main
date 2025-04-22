import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:talentspotfilmmaker/filmmaker_home_page.dart';
import 'package:talentspotfilmmaker/filmmaker_jobs_page.dart';
import 'package:talentspotfilmmaker/filmmaker_profile_page.dart';

class PromotionsPage extends StatefulWidget {
  const PromotionsPage({super.key});

  @override
  State<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends State<PromotionsPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _promotions = [];
  bool _isLoading = true;
  String? _currentUserId;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();
  PlatformFile? _posterImage;
  String? _posterUrl;
  Map<String, dynamic>? _editingPromotion;
  DateTime? _selectedReleaseDate;

  String _userName = '';
  String _profilePic = '';
  int _selectedIndex = 2;

  static const Color primaryColor = Color(0xFF4361EE);
  static const Color secondaryColor = Color(0xFF64748B);
  static const Color accentColor = Colors.white;
  static const Color backgroundColor = Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _currentUserId = supabase.auth.currentUser!.id;
    _loadUserData();
    _fetchPromotions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
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

  Future<void> _fetchPromotions() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('tbl_promotion')
          .select()
          .eq('filmmaker_id', supabase.auth.currentUser!.id)
          .order('created_at', ascending: false);
      debugPrint('Fetch promotions response: $response');
      if (mounted) {
        setState(() {
          _promotions = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching promotions: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _posterImage = result.files.first;
          debugPrint('Picked image: ${_posterImage!.name}');
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Poster image selected successfully')),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No image selected')));
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  Future<String?> _uploadPoster(String promotionId) async {
    if (_posterImage == null) {
      debugPrint('No poster image selected for upload');
      return null;
    }

    final fileName = '$promotionId-${_posterImage!.name}';
    try {
      // Handle web (bytes) and mobile (file path)
      if (_posterImage!.bytes != null) {
        // Web: Use bytes
        await supabase.storage
            .from('posters')
            .uploadBinary(fileName, _posterImage!.bytes!);
      } else if (_posterImage!.path != null) {
        // Mobile: Use file path
        final file = File(_posterImage!.path!);
        await supabase.storage.from('posters').upload(fileName, file);
      } else {
        throw Exception('No valid image data or path found');
      }

      final url = supabase.storage.from('posters').getPublicUrl(fileName);
      debugPrint('Uploaded poster URL: $url');
      return url;
    } catch (e) {
      debugPrint('Error uploading poster: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading poster: $e')));
      return null;
    }
  }

  Future<void> _savePromotion() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final promotionData = {
        'movie_title': _nameController.text.trim(),
        'movie_description': _descriptionController.text.trim(),
        'movie_releasedate': _selectedReleaseDate?.toIso8601String(),
        'movie_poster':
            _posterImage != null
                ? await _uploadPoster(
                  _editingPromotion != null
                      ? _editingPromotion!['promotion_id'].toString()
                      : DateTime.now().millisecondsSinceEpoch.toString(),
                )
                : _editingPromotion?['movie_poster'],
        'movie_duration': _durationController.text.trim(),
      };

      debugPrint('Promotion data: $promotionData');

      if (_editingPromotion != null) {
        // Update existing promotion
        await supabase
            .from('tbl_promotion')
            .update(promotionData)
            .eq('promotion_id', _editingPromotion!['promotion_id']);
      } else {
        // Insert new promotion, let database handle promotion_id
        await supabase.from('tbl_promotion').insert({
          ...promotionData,
          'filmmaker_id': _currentUserId,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Promotion saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
      _resetForm();
      _fetchPromotions();
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error saving promotion: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePromotion(String promotionId) async {
    try {
      await supabase
          .from('tbl_promotion')
          .delete()
          .eq('promotion_id', promotionId);
      _fetchPromotions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Promotion deleted successfully')),
      );
    } catch (e) {
      debugPrint('Error deleting promotion: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting promotion: $e')));
    }
  }

  void _resetForm() {
    _nameController.clear();
    _descriptionController.clear();
    _durationController.clear();
    setState(() {
      _posterImage = null;
      _posterUrl = null;
      _editingPromotion = null;
      _selectedReleaseDate = null;
    });
  }

  void _editPromotion(Map<String, dynamic> promotion) {
    setState(() {
      _editingPromotion = promotion;
      _nameController.text = promotion['movie_title']?.toString() ?? '';
      _descriptionController.text =
          promotion['movie_description']?.toString() ?? '';
      _selectedReleaseDate =
          promotion['movie_releasedate'] != null
              ? DateTime.tryParse(promotion['movie_releasedate'].toString())
              : null;
      _durationController.text = promotion['movie_duration']?.toString() ?? '';
      _posterUrl = promotion['movie_poster']?.toString();
      _posterImage = null; // Reset to allow new image upload
    });
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _pickReleaseDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedReleaseDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null && pickedDate != _selectedReleaseDate) {
      setState(() {
        _selectedReleaseDate = pickedDate;
      });
    }
  }

  void _showPromotionForm({Map<String, dynamic>? promotion}) {
    if (promotion != null) {
      _editPromotion(promotion);
    } else {
      _resetForm();
    }
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
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      promotion != null
                          ? 'Edit Promotion'
                          : 'Add New Promotion',
                      style: GoogleFonts.poppins(
                        fontSize:
                            MediaQuery.of(context).size.width < 600 ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    _buildTextField(
                      controller: _nameController,
                      label: 'Movie Title',
                      hint: 'e.g. The Great Escape',
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? 'Please enter movie title'
                                  : null,
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Description',
                      hint: 'Describe the movie',
                      maxLines: 5,
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? 'Please enter description'
                                  : null,
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    _buildTextField(
                      controller: _durationController,
                      label: 'Duration (mins)',
                      hint: 'e.g. 120',
                      keyboardType: TextInputType.number,
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? 'Please enter duration'
                                  : null,
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    InkWell(
                      onTap: () => _pickReleaseDate(context),
                      child: _buildDateField(
                        label: 'Release Date',
                        value:
                            _selectedReleaseDate != null
                                ? _formatDate(
                                  _selectedReleaseDate!.toIso8601String(),
                                )
                                : 'Select Date',
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.2,
                        decoration: BoxDecoration(
                          border: Border.all(color: secondaryColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child:
                            _posterImage != null
                                ? _posterImage!.bytes != null
                                    ? Image.memory(
                                      Uint8List.fromList(_posterImage!.bytes!),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    )
                                    : Image.file(
                                      File(_posterImage!.path!),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    )
                                : _posterUrl != null
                                ? CachedNetworkImage(
                                  imageUrl: _posterUrl!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorWidget:
                                      (context, url, error) =>
                                          const Icon(Icons.error),
                                )
                                : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.image,
                                        size: 40,
                                        color: secondaryColor,
                                      ),
                                      SizedBox(
                                        height:
                                            MediaQuery.of(context).size.height *
                                            0.01,
                                      ),
                                      Text(
                                        'Tap to upload poster',
                                        style: GoogleFonts.poppins(
                                          color: secondaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.04),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _savePromotion,
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
                              ? const CircularProgressIndicator(
                                color: accentColor,
                              )
                              : Text(
                                promotion != null
                                    ? 'Update Promotion'
                                    : 'Add Promotion',
                                style: GoogleFonts.poppins(
                                  fontSize:
                                      MediaQuery.of(context).size.width < 600
                                          ? 14
                                          : 16,
                                  fontWeight: FontWeight.w600,
                                  color: accentColor,
                                ),
                              ),
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                color: primaryColor,
                onRefresh: _fetchPromotions,
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
                            child: CircularProgressIndicator(
                              color: primaryColor,
                            ),
                          )
                          : _promotions.isEmpty
                          ? Center(
                            child: Text(
                              'No promotions available',
                              style: GoogleFonts.poppins(
                                fontSize:
                                    MediaQuery.of(context).size.width < 600
                                        ? 14
                                        : 16,
                                color: secondaryColor,
                              ),
                            ),
                          )
                          : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _promotions.length,
                            itemBuilder: (context, index) {
                              final promotion = _promotions[index];
                              return Container(
                                margin: EdgeInsets.only(
                                  bottom:
                                      MediaQuery.of(context).size.height * 0.02,
                                ),
                                child: Card(
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Movie Poster
                                        if (promotion['movie_poster'] != null)
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: CachedNetworkImage(
                                              imageUrl:
                                                  promotion['movie_poster'],
                                              height:
                                                  MediaQuery.of(
                                                    context,
                                                  ).size.height *
                                                  0.3,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              placeholder:
                                                  (context, url) => Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                          color: primaryColor,
                                                        ),
                                                  ),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      const Icon(
                                                        Icons.error,
                                                        size: 40,
                                                      ),
                                            ),
                                          ),
                                        SizedBox(
                                          height:
                                              MediaQuery.of(
                                                context,
                                              ).size.height *
                                              0.02,
                                        ),
                                        // Movie Title
                                        Text(
                                          promotion['movie_title'] ??
                                              'Untitled',
                                          style: GoogleFonts.poppins(
                                            fontSize:
                                                MediaQuery.of(
                                                          context,
                                                        ).size.width <
                                                        600
                                                    ? 16
                                                    : 18,
                                            fontWeight: FontWeight.bold,
                                            color: primaryColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(
                                          height:
                                              MediaQuery.of(
                                                context,
                                              ).size.height *
                                              0.01,
                                        ),
                                        // Details
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildDetailRow(
                                              'Description',
                                              promotion['movie_description'] ??
                                                  'Not specified',
                                            ),
                                            SizedBox(
                                              height:
                                                  MediaQuery.of(
                                                    context,
                                                  ).size.height *
                                                  0.01,
                                            ),
                                            _buildDetailRow(
                                              'Duration',
                                              '${promotion['movie_duration'] ?? 'N/A'} mins',
                                            ),
                                            SizedBox(
                                              height:
                                                  MediaQuery.of(
                                                    context,
                                                  ).size.height *
                                                  0.01,
                                            ),
                                            _buildDetailRow(
                                              'Release Date',
                                              _formatDate(
                                                promotion['movie_releasedate'],
                                              ),
                                            ),
                                            SizedBox(
                                              height:
                                                  MediaQuery.of(
                                                    context,
                                                  ).size.height *
                                                  0.01,
                                            ),
                                            _buildDetailRow(
                                              'Created At',
                                              _formatDate(
                                                promotion['created_at'],
                                              ),
                                            ),
                                            SizedBox(
                                              height:
                                                  MediaQuery.of(
                                                    context,
                                                  ).size.height *
                                                  0.01,
                                            ),
                                            _buildDetailRow(
                                              'Status',
                                              (promotion['movie_status'] == 1)
                                                  ? 'Active'
                                                  : 'Inactive',
                                            ),
                                          ],
                                        ),
                                        SizedBox(
                                          height:
                                              MediaQuery.of(
                                                context,
                                              ).size.height *
                                              0.01,
                                        ),
                                        // Action Buttons
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.edit,
                                                    color: primaryColor,
                                                  ),
                                                  onPressed:
                                                      () => _showPromotionForm(
                                                        promotion: promotion,
                                                      ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete,
                                                    color: Colors.red,
                                                  ),
                                                  onPressed:
                                                      () => _deletePromotion(
                                                        promotion['promotion_id']
                                                            .toString(),
                                                      ),
                                                ),
                                              ],
                                            ),
                                            Container(),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPromotionForm(),
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: accentColor),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width * 0.05,
        vertical: MediaQuery.of(context).size.height * 0.02,
      ),
      decoration: const BoxDecoration(
        color: accentColor,
        boxShadow: [
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
                  color: primaryColor,
                ),
              ),
              Text(
                'Manage Your Promotions',
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
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: primaryColor,
                ),
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
                          ? const Icon(Icons.person, color: secondaryColor)
                          : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: accentColor,
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavItemTapped,
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primaryColor,
        unselectedItemColor: secondaryColor,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: MediaQuery.of(context).size.width < 600 ? 10 : 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: MediaQuery.of(context).size.width < 600 ? 10 : 12,
          fontWeight: FontWeight.w500,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline_rounded),
            activeIcon: Icon(Icons.work_rounded),
            label: 'Jobs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.movie_outlined),
            activeIcon: Icon(Icons.movie_rounded),
            label: 'Promotions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const FilmmakerHomePage()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const FilmmakerJobsPage()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const FilmmakerProfilePage()),
        );
        break;
    }
    if (index != 2) {
      setState(() {
        _selectedIndex = 2;
      });
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
            fontWeight: FontWeight.w500,
            color: primaryColor,
          ),
        ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.01),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
              fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
              color: secondaryColor,
            ),
            filled: true,
            fillColor: accentColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.all(
              MediaQuery.of(context).size.width * 0.03,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDateField({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
            fontWeight: FontWeight.w500,
            color: primaryColor,
          ),
        ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.01),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.03,
            vertical: MediaQuery.of(context).size.height * 0.01,
          ),
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
                  color: secondaryColor,
                ),
              ),
              Icon(Icons.calendar_today, color: primaryColor),
            ],
          ),
        ),
      ],
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
