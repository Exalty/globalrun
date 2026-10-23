import 'package:flutter/material.dart';
import '../services/blockchain_service.dart';
import '../services/ai_coach_service.dart';
import '../theme/duo_theme.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'feedback_screen.dart';

class MainNavigationWrapper extends StatefulWidget {
  final BlockchainService blockchainService;
  final AiCoachService aiCoachService;
  final VoidCallback onLogout;

  const MainNavigationWrapper({
    super.key,
    required this.blockchainService,
    required this.aiCoachService,
    required this.onLogout,
  });

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final palette = DuoColors.of(context);
    final List<Widget> screens = [
      HomeScreen(
        blockchainService: widget.blockchainService,
        aiCoachService: widget.aiCoachService,
      ),
      const FeedbackScreen(),
      ProfileScreen(onLogout: widget.onLogout),
    ];

    return Scaffold(
      backgroundColor: palette.background,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(
            top: BorderSide(color: palette.surfaceBorder, width: 2.0),
          ),
          boxShadow: [
            BoxShadow(
              color: palette.surfaceShadow.withOpacity(palette.isDark ? 1.0 : 0.4),
              offset: const Offset(0, -3),
              blurRadius: 6,
            ),
          ],
        ),
        padding: const EdgeInsets.only(top: 8, bottom: 12, left: 16, right: 16),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDuoNavItem(
                index: 0,
                icon: Icons.sports_score_rounded,
                activeIcon: Icons.sports_score_rounded,
                label: 'LOMBA',
                palette: palette,
              ),
              _buildDuoNavItem(
                index: 1,
                icon: Icons.rate_review_outlined,
                activeIcon: Icons.rate_review_rounded,
                label: 'SARAN',
                palette: palette,
              ),
              _buildDuoNavItem(
                index: 2,
                icon: Icons.face_rounded,
                activeIcon: Icons.face_rounded,
                label: 'PROFIL',
                palette: palette,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDuoNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required DuoColorPalette palette,
  }) {
    final bool isSelected = _currentIndex == index;

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? palette.primaryBlue.withOpacity(palette.isDark ? 0.16 : 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? palette.primaryBlue : Colors.transparent,
            width: 2.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 24,
              color: isSelected ? palette.primaryBlue : palette.textMuted,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
                color: isSelected ? palette.primaryBlue : palette.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
