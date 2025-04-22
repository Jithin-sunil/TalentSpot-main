import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppBarSection extends StatelessWidget {
  final String userName;
  final String profilePic;
  final bool isVerified;
  final VoidCallback onProfileTap;

  const AppBarSection({
    super.key,
    required this.userName,
    required this.profilePic,
    required this.isVerified,
    required this.onProfileTap,
  });

  static const Color primaryColor = Color(0xFF6200EE);
  static const Color textPrimaryColor = Color(0xFF1D1D1D);
  static const Color textSecondaryColor = Color(0xFF757575);

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        title: Row(
          children: [
            Text(
              'TalentSpot',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Filmmaker',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.notifications_outlined,
            color: textPrimaryColor,
          ),
          onPressed: () {},
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: GestureDetector(
            onTap: onProfileTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage:
                      profilePic.isNotEmpty ? NetworkImage(profilePic) : null,
                  backgroundColor: Colors.grey[200],
                  child:
                      profilePic.isEmpty
                          ? const Icon(
                            Icons.person,
                            size: 20,
                            color: textSecondaryColor,
                          )
                          : null,
                ),
                if (isVerified)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
