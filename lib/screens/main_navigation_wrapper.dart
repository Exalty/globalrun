import 'package:flutter/material.dart';
import '../services/blockchain_service.dart';
import '../services/ai_coach_service.dart';
import '../theme/duo_theme.dart';
import 'home_screen.dart';
import 'ai_coach_screen.dart';
import 'mini_game_screen.dart';
import 'feedback_screen.dart';
import 'profile_screen.dart';

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
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(
        blockchainService: widget.blockchainService,
        aiCoachService: widget.aiCoachService,
      ),
      AiCoachScreen(
        coachService: widget.aiCoachService,
      ),
      const MiniGameScreen(),
      const FeedbackScreen(),
      ProfileScreen(onLogout: widget.onLogout),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final palette = DuoColors.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
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
        padding: const EdgeInsets.only(top: 6, bottom: 8, left: 8, right: 8),
        child: SafeArea(
          top: false,
          child: Row(
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
                icon: Icons.psychology_outlined,
                activeIcon: Icons.psychology_rounded,
                label: 'COACH RANI',
                palette: palette,
              ),
              _buildDuoNavItem(
                index: 2,
                icon: Icons.sports_esports_outlined,
                activeIcon: Icons.sports_esports_rounded,
                label: 'MINI GAME',
                palette: palette,
              ),
              _buildDuoNavItem(
                index: 3,
                icon: Icons.rate_review_outlined,
                activeIcon: Icons.rate_review_rounded,
                label: 'SARAN',
                palette: palette,
              ),
              _buildDuoNavItem(
                index: 4,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
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

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? palette.primaryBlue.withOpacity(palette.isDark ? 0.16 : 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
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
                size: 22,
                color: isSelected ? palette.primaryBlue : palette.textMuted,
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                    color: isSelected ? palette.primaryBlue : palette.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
