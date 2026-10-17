import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class MiniGameScreen extends StatefulWidget {
  const MiniGameScreen({super.key});

  @override
  State<MiniGameScreen> createState() => _MiniGameScreenState();
}

class Obstacle {
  double x; // 1.0 (right) to -1.0 (left)
  final double width;
  final double height;
  final IconData icon;

  Obstacle({
    required this.x,
    this.width = 40,
    this.height = 40,
    required this.icon,
  });
}

class _MiniGameScreenState extends State<MiniGameScreen> with SingleTickerProviderStateMixin {
  // Runner state
  static const double groundY = 0.5; // Normalized screen position
  double runnerY = groundY;
  double velocityY = 0.0;
  final double gravity = -0.0028;
  final double jumpStrength = 0.055;
  bool isJumping = false;

  // Game state
  bool isPlaying = false;
  bool isGameOver = false;
  int score = 0;
  int highScore = 0;
  Timer? gameLoopTimer;
  Timer? obstacleSpawnerTimer;

  final List<Obstacle> obstacles = [];
  final Random random = Random();

  @override
  void initState() {
    super.initState();
  }

  void startGame() {
    setState(() {
      isPlaying = true;
      isGameOver = false;
      score = 0;
      runnerY = groundY;
      velocityY = 0.0;
      isJumping = false;
      obstacles.clear();
    });

    gameLoopTimer?.cancel();
    obstacleSpawnerTimer?.cancel();

    // Loop 60 FPS
    gameLoopTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _updateGamePhysics();
    });

    // Spawner every 1.5 - 2.5s
    _scheduleNextObstacle();
  }

  void _scheduleNextObstacle() {
    if (!isPlaying || isGameOver) return;
    final delayMs = 1400 + random.nextInt(1200);
    obstacleSpawnerTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!isPlaying || isGameOver) return;
      final icons = [Icons.warning_amber_rounded, Icons.sports_volleyball, Icons.electric_bolt];
      obstacles.add(Obstacle(x: 1.2, icon: icons[random.nextInt(icons.length)]));
      _scheduleNextObstacle();
    });
  }

  void jump() {
    if (!isPlaying) {
      startGame();
      return;
    }
    if (!isJumping) {
      setState(() {
        isJumping = true;
        velocityY = jumpStrength;
      });
    }
  }

  void _updateGamePhysics() {
    if (!isPlaying || isGameOver) return;

    setState(() {
      // Runner physics
      if (isJumping) {
        runnerY -= velocityY;
        velocityY += gravity;

        if (runnerY >= groundY) {
          runnerY = groundY;
          velocityY = 0;
          isJumping = false;
        }
      }

      // Move obstacles
      const double speed = 0.018;
      for (int i = obstacles.length - 1; i >= 0; i--) {
        obstacles[i].x -= speed;

        // Collision check
        // Runner x is fixed around -0.6
        const runnerX = -0.6;
        final obs = obstacles[i];
        if ((obs.x - runnerX).abs() < 0.12 && runnerY > (groundY - 0.22)) {
          _handleGameOver();
          return;
        }

        // Out of screen
        if (obs.x < -1.2) {
          obstacles.removeAt(i);
          score += 10;
          if (score > highScore) {
            highScore = score;
          }
        }
      }
    });
  }

  void _handleGameOver() {
    gameLoopTimer?.cancel();
    obstacleSpawnerTimer?.cancel();
    setState(() {
      isPlaying = false;
      isGameOver = true;
    });
  }

  @override
  void dispose() {
    gameLoopTimer?.cancel();
    obstacleSpawnerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Virtual Dash Mini-Game', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: jump,
        child: Column(
          children: [
            // Score Board
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: const Color(0xFF1E293B),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.stars_rounded, color: Colors.amber, size: 24),
                      const SizedBox(width: 8),
                      Text('Score: $score', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.emoji_events_rounded, color: Colors.orangeAccent, size: 24),
                      const SizedBox(width: 8),
                      Text('High: $highScore', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),

            // Game Canvas Area
            Expanded(
              child: Stack(
                children: [
                  // Sky & Background Stars/Track
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),

                  // Distance track line
                  Align(
                    alignment: const Alignment(0, 0.65),
                    child: Container(
                      height: 6,
                      color: Colors.cyanAccent.withOpacity(0.6),
                    ),
                  ),
                  Align(
                    alignment: const Alignment(0, 0.9),
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.cyan.withOpacity(0.15), Colors.transparent],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),

                  // Obstacles
                  for (final obs in obstacles)
                    Align(
                      alignment: Alignment(obs.x, groundY),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.85),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 10, spreadRadius: 2),
                          ],
                        ),
                        child: Icon(obs.icon, color: Colors.white, size: 22),
                      ),
                    ),

                  // Runner Avatar
                  Align(
                    alignment: Alignment(-0.6, runnerY),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.cyanAccent.withOpacity(0.6), blurRadius: 14, spreadRadius: 3),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.directions_run_rounded, color: Colors.black87, size: 36),
                      ),
                    ),
                  ),

                  // Tap to Start / Game Over Overlay
                  if (!isPlaying)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withOpacity(0.95),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.cyanAccent, width: 1.5),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isGameOver ? '💥 GAME OVER!' : '🏃‍♂️ ENDLESS RUNNER',
                              style: TextStyle(
                                color: isGameOver ? Colors.redAccent : Colors.cyanAccent,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isGameOver ? 'Skor Anda: $score' : 'Lompat melewati rintangan race virtual!',
                              style: const TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: startGame,
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: Text(isGameOver ? 'Main Lagi' : 'Mulai Lari'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.cyanAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text('Ketuk layar mana saja untuk melompat', style: TextStyle(color: Colors.white38, fontSize: 12)),
                          ],
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
