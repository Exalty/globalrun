import 'package:flutter/material.dart';
import '../services/blockchain_service.dart';
import '../services/ai_coach_service.dart';
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
    final List<Widget> screens = [
      HomeScreen(
        blockchainService: widget.blockchainService,
        aiCoachService: widget.aiCoachService,
      ),
      const FeedbackScreen(),
      ProfileScreen(onLogout: widget.onLogout),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          border: Border(top: BorderSide(color: Colors.white12, width: 0.8)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: const Color(0xFF1E293B),
          selectedItemColor: Colors.cyanAccent,
          unselectedItemColor: Colors.white54,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            setState(() => _currentIndex = index);
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.rate_review_rounded),
              label: 'Saran & Kesan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

