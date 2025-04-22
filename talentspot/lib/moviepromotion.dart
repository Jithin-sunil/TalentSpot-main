import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class MoviePromotionsPage extends StatefulWidget {
  const MoviePromotionsPage({super.key});

  @override
  State<MoviePromotionsPage> createState() => _MoviePromotionsPageState();
}

class _MoviePromotionsPageState extends State<MoviePromotionsPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _promotions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPromotions();
  }

  Future<void> _fetchPromotions() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('tbl_promotion')
          .select('*, tbl_filmmakers(filmmaker_name, filmmaker_photo)')
          .order('movie_releasedate', ascending: false);

      if (mounted) {
        setState(() {
          _promotions = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching promotions: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load promotions')),
      );
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? date) {
    if (date == null) return 'N/A';
    try {
      final parsedDate = DateTime.parse(date);
      return DateFormat('dd MMM yyyy').format(parsedDate);
    } catch (e) {
      return date;
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
        title: Text(
          'Movie Promotions',
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
            onPressed: _fetchPromotions,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: _fetchPromotions,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: primaryColor))
            : _promotions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.movie_filter,
                          size: 64,
                          color: secondaryColor.withOpacity(0.7),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No movie promotions available',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: secondaryColor,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Check back later for new releases',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: secondaryColor,
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: MediaQuery.of(context).size.width * 0.05,
                            vertical: 16,
                          ),
                          child: Text(
                            'Featured Releases',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2D3748),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 280,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.05),
                            itemCount: _promotions.length > 3 ? 3 : _promotions.length,
                            itemBuilder: (context, index) => _buildFeaturedCard(_promotions[index]),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: MediaQuery.of(context).size.width * 0.05,
                            vertical: 16,
                          ),
                          child: Text(
                            'All Movies',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2D3748),
                            ),
                          ),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.05),
                          itemCount: _promotions.length,
                          itemBuilder: (context, index) => _buildMovieListItem(_promotions[index]),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildFeaturedCard(Map<String, dynamic> promotion) {
    const Color primaryColor = Color(0xFF4361EE);
    const Color secondaryColor = Color(0xFF64748B);
    const Color accentColor = Colors.white;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MovieDetailsPage(promotion: promotion)),
      ),
      child: Container(
        width: 180,
        margin: EdgeInsets.only(right: 16),
        child: Card(
          color: accentColor,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'poster_${promotion['movie_id']}',
                child: CachedNetworkImage(
                  imageUrl: promotion['movie_poster'] ?? '',
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Center(child: CircularProgressIndicator(color: primaryColor)),
                  errorWidget: (context, url, error) => Icon(Icons.error, color: Colors.red),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      promotion['movie_title']?.trim().isNotEmpty ?? false
                          ? promotion['movie_title']
                          : 'Unknown Title',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2D3748),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Release: ${_formatDate(promotion['movie_releasedate'])}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: secondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMovieListItem(Map<String, dynamic> promotion) {
    const Color primaryColor = Color(0xFF4361EE);
    const Color secondaryColor = Color(0xFF64748B);
    const Color accentColor = Colors.white;

    final filmmaker = promotion['tbl_filmmakers'] as Map<String, dynamic>? ?? {};

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MovieDetailsPage(promotion: promotion)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Card(
          color: accentColor,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Hero(
                  tag: 'poster_${promotion['movie_id']}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: promotion['movie_poster'] ?? '',
                      width: 80,
                      height: 120,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Center(child: CircularProgressIndicator(color: primaryColor)),
                      errorWidget: (context, url, error) => Icon(Icons.error, color: Colors.red),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        promotion['movie_title']?.trim().isNotEmpty ?? false
                            ? promotion['movie_title']
                            : 'Unknown Title',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2D3748),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        filmmaker['filmmaker_name'] ?? 'Unknown Filmmaker',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: secondaryColor,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        promotion['movie_description']?.trim().isNotEmpty ?? false
                            ? promotion['movie_description']
                            : 'No description',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: secondaryColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Release: ${_formatDate(promotion['movie_releasedate'])}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: secondaryColor,
                            ),
                          ),
                          Text(
                            promotion['movie_duration']?.toString() ?? 'N/A',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: secondaryColor,
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
      ),
    );
  }
}

class MovieDetailsPage extends StatelessWidget {
  final Map<String, dynamic> promotion;

  const MovieDetailsPage({super.key, required this.promotion});

  String _formatDate(String? date) {
    if (date == null) return 'N/A';
    try {
      final parsedDate = DateTime.parse(date);
      return DateFormat('dd MMMM yyyy').format(parsedDate);
    } catch (e) {
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF4361EE);
    const Color secondaryColor = Color(0xFF64748B);
    const Color accentColor = Colors.white;
    const Color backgroundColor = Color(0xFFF8F9FA);

    final filmmaker = promotion['tbl_filmmakers'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          promotion['movie_title']?.trim().isNotEmpty ?? false
              ? promotion['movie_title']
              : 'Movie Details',
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'poster_${promotion['movie_id']}',
              child: CachedNetworkImage(
                imageUrl: promotion['movie_poster'] ?? '',
                height: 300,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(child: CircularProgressIndicator(color: primaryColor)),
                errorWidget: (context, url, error) => Icon(Icons.error, color: Colors.red),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.05,
                vertical: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    promotion['movie_title']?.trim().isNotEmpty ?? false
                        ? promotion['movie_title']
                        : 'Unknown Title',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2D3748),
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: filmmaker['filmmaker_photo'] != null
                            ? NetworkImage(filmmaker['filmmaker_photo'])
                            : null,
                        child: filmmaker['filmmaker_photo'] == null
                            ? Text(
                                filmmaker['filmmaker_name']?[0].toUpperCase() ?? 'F',
                                style: GoogleFonts.poppins(color: accentColor),
                              )
                            : null,
                        backgroundColor: primaryColor.withOpacity(0.1),
                      ),
                      SizedBox(width: 8),
                      Text(
                        filmmaker['filmmaker_name'] ?? 'Unknown Filmmaker',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: secondaryColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Release: ${_formatDate(promotion['movie_releasedate'])}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: secondaryColor,
                        ),
                      ),
                      Text(
                        'Duration: ${promotion['movie_duration']?.toString() ?? 'N/A'}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: secondaryColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Overview',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2D3748),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    promotion['movie_description']?.trim().isNotEmpty ?? false
                        ? promotion['movie_description']
                        : 'No description available',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: const Color(0xFF2D3748),
                    ),
                  ),
                  SizedBox(height: 24),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Trailer coming soon!')),
                        );
                      },
                      icon: Icon(Icons.play_arrow, color: accentColor),
                      label: Text(
                        'Watch Trailer',
                        style: GoogleFonts.poppins(color: accentColor),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
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