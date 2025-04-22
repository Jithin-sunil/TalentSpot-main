import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:talentspotfilmmaker/filmmaker_applications_page.dart';

class QuickActionsSection extends StatelessWidget {
  final VoidCallback onPostJob;
  final VoidCallback onFindTalent;

  const QuickActionsSection({
    super.key,
    required this.onPostJob,
    required this.onFindTalent,
  });

  static const Color primaryColor = Color(0xFF6200EE);
  static const Color textPrimaryColor = Color(0xFF1D1D1D);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textPrimaryColor,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildActionCard(
              'Post a Job',
              Icons.add_circle_outline,
              const Color(0xFF4CAF50),
              onPostJob,
            ),
            const SizedBox(width: 12),
            _buildActionCard(
              'Find Talent',
              Icons.search,
              const Color(0xFF2196F3),
              onFindTalent,
            ),
            const SizedBox(width: 12),
            _buildActionCard(
              'View Applications',
              Icons.description_outlined,
              const Color(0xFFFF9800),
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FilmmakerApplicationsPage(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textPrimaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
