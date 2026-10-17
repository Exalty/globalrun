import 'package:flutter/material.dart';
import '../services/ai_coach_service.dart';

class AiCoachScreen extends StatefulWidget {
  final AiCoachService coachService;
  final double currentDistanceKm;
  final int currentSteps;
  final double currentSpeedKmh;
  final int durationSeconds;

  const AiCoachScreen({
    super.key,
    required this.coachService,
    this.currentDistanceKm = 0.0,
    this.currentSteps = 0,
    this.currentSpeedKmh = 0.0,
    this.durationSeconds = 0,
  });

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final List<AiMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _apiKeyController.text = widget.coachService.apiKey ?? '';
    // Welcome initial prompt
    _messages.add(
      AiMessage(
        sender: 'ai',
        text: 'Halo Atlet! Saya Coach AI Anda. Saya dapat membantu menganalisis pace balapan, memberi rekomendasi nutrisi carbo-loading / hidrasi, serta taktik interval lari atau sepeda. Apa yang ingin Anda konsultasikan?',
        timestamp: DateTime.now(),
      ),
    );
  }

  void _sendMessage([String? presetText]) async {
    final query = presetText ?? _textController.text.trim();
    if (query.isEmpty) return;

    _textController.clear();
    setState(() {
      _messages.add(AiMessage(sender: 'user', text: query, timestamp: DateTime.now()));
      _isLoading = true;
    });

    try {
      final answer = await widget.coachService.askCoach(
        query: query,
        currentDistanceKm: widget.currentDistanceKm,
        steps: widget.currentSteps,
        avgSpeedKmh: widget.currentSpeedKmh,
        durationSeconds: widget.durationSeconds,
        sportType: 'Lari / Sepeda Virtual',
      );

      setState(() {
        _messages.add(AiMessage(sender: 'ai', text: answer, timestamp: DateTime.now()));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(AiMessage(sender: 'ai', text: 'Maaf, terjadi kesalahan: $e', timestamp: DateTime.now()));
        _isLoading = false;
      });
    }
  }

  void _showApiKeyDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Konfigurasi Gemini API Key', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Opsional: Masukkan Google Gemini API Key untuk respon LLM cloud live. Jika kosong, sistem otomatis memakai AI Sports Science bawaan offline.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'AIzaSy...',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                widget.coachService.apiKey = _apiKeyController.text.trim();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('API Key berhasil disimpan!')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('AI Virtual Coach', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.key_rounded),
            onPressed: _showApiKeyDialog,
            tooltip: 'Atur Gemini API Key',
          )
        ],
      ),
      body: Column(
        children: [
          // Current live telemetry context banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF1E293B),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatBadge(Icons.directions_run_rounded, '${widget.currentDistanceKm.toStringAsFixed(1)} KM'),
                _buildStatBadge(Icons.speed_rounded, '${widget.currentSpeedKmh.toStringAsFixed(1)} km/h'),
                _buildStatBadge(Icons.directions_walk_rounded, '${widget.currentSteps} Steps'),
              ],
            ),
          ),

          // Message chat list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg.sender == 'user';

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(14),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                        bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                      ),
                      border: isUser ? null : Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isUser ? Icons.person_rounded : Icons.smart_toy_rounded,
                              size: 16,
                              color: isUser ? Colors.white70 : Colors.cyanAccent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isUser ? 'Anda' : 'AI Coach',
                              style: TextStyle(
                                color: isUser ? Colors.white70 : Colors.cyanAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          msg.text,
                          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent)),
                  SizedBox(width: 10),
                  Text('Coach sedang memproses strategi...', style: TextStyle(color: Colors.white60, fontSize: 13)),
                ],
              ),
            ),

          // Preset prompt chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                _buildPromptChip('🥗 Rekomendasi Nutrisi', 'Beri saya rekomendasi nutrisi dan hidrasi lomba'),
                _buildPromptChip('⚡ Analisis Performa', 'Analisis performa pace dan ritme lari saya saat ini'),
                _buildPromptChip('⏱️ Taktik Negative Split', 'Bagaimana taktik negative split untuk sisa race?'),
                _buildPromptChip('⚠️ Tips Cegah Kram', 'Bagaimana cara mencegah kram otot betis saat race?'),
              ],
            ),
          ),

          // Input field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Tanya coach virtual (nutrisi, pace, tips)...',
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (val) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.cyanAccent),
                  onPressed: () => _sendMessage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.cyanAccent, size: 18),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildPromptChip(String label, String prompt) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        backgroundColor: const Color(0xFF334155),
        label: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        onPressed: () => _sendMessage(prompt),
      ),
    );
  }
}
