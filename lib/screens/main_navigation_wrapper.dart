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

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Konfirmasi Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari sesi atlet ini?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onLogout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Keluar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(
        blockchainService: widget.blockchainService,
        aiCoachService: widget.aiCoachService,
      ),
      ProfileScreen(onLogout: widget.onLogout),
      const FeedbackScreen(),
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
            if (index == 3) {
              // Tab Logout memicu dialog konfirmasi
              _showLogoutDialog();
            } else {
              setState(() => _currentIndex = index);
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.rate_review_rounded),
              label: 'Saran & Kesan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.logout_rounded, color: Colors.redAccent),
              label: 'Logout',
            ),
          ],
        ),
      ),
    );
  }
}
