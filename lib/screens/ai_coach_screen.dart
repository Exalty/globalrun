import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final ScrollController _scrollController = ScrollController();
  final List<AiMessage> _messages = [];
  bool _isLoading = false;

  bool get _hasApiKey {
    final k = widget.coachService.apiKey;
    return k != null && k.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _loadSavedApiKey();
    _apiKeyController.text = widget.coachService.apiKey ?? '';
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _textController.dispose();
    _apiKeyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    _messages.add(
      AiMessage(
        sender: 'ai',
        text: _hasApiKey
            ? 'Halo! 👋 Aku Coach AI kamu. Mau ngobrol soal lari, nutrisi, '
                'recovery, atau cedera? Tanya aja, aku siap bantu. 🔥'
            : 'Halo! 👋 Aku Coach AI kamu.\n\n'
                '⚠️ API Key Gemini belum diatur. Tambahkan di file `.env` '
                'atau klik ikon 🔑 di kanan atas supaya aku bisa menjawab.',
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Key dari SharedPreferences hanya menimpa key .env jika user pernah menyimpannya.
  Future<void> _loadSavedApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKey = prefs.getString('gemini_api_key');
      if (savedKey != null && savedKey.trim().isNotEmpty) {
        widget.coachService.apiKey = savedKey.trim();
        _apiKeyController.text = savedKey.trim();
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? presetText]) async {
    final query = (presetText ?? _textController.text).trim();
    if (query.isEmpty || _isLoading) return;

    _textController.clear();
    setState(() {
      _messages.add(AiMessage(sender: 'user', text: query, timestamp: DateTime.now()));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final answer = await widget.coachService.askCoach(
        query: query,
        currentDistanceKm: widget.currentDistanceKm,
        steps: widget.currentSteps,
        avgSpeedKmh: widget.currentSpeedKmh,
        durationSeconds: widget.durationSeconds,
        sportType: 'Lari / Sepeda Virtual',
      );

      if (!mounted) return;
      setState(() {
        _messages.add(AiMessage(sender: 'ai', text: answer, timestamp: DateTime.now()));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(AiMessage(
            sender: 'ai',
            text: 'Maaf, terjadi kesalahan: $e',
            timestamp: DateTime.now()));
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  void _resetChat() {
    widget.coachService.clearHistory();
    setState(() {
      _messages.clear();
      _addWelcomeMessage();
    });
  }

  void _showApiKeyDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Konfigurasi Gemini API Key',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Masukkan Google Gemini API Key. Key yang disimpan di sini akan '
                'menimpa key dari file .env. Kosongkan lalu simpan untuk menghapusnya.',
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
              onPressed: () async {
                final key = _apiKeyController.text.trim();
                widget.coachService.apiKey = key;
                final nav = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final prefs = await SharedPreferences.getInstance();
                  if (key.isNotEmpty) {
                    await prefs.setString('gemini_api_key', key);
                  } else {
                    await prefs.remove('gemini_api_key');
                  }
                } catch (_) {}

                if (!mounted) return;
                nav.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(key.isNotEmpty
                        ? 'API Key disimpan ✅'
                        : 'API Key dihapus'),
                    backgroundColor: key.isNotEmpty ? Colors.green : Colors.orange,
                  ),
                );
                setState(() {});
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  /// Label & warna badge berdasarkan sumber respons terakhir (bukan sekadar ada key).
  ({String label, Color color}) _statusBadge() {
    switch (widget.coachService.lastSourceUsed) {
      case 'gemini':
        return (label: 'Gemini Live', color: Colors.greenAccent);
      case 'local':
        return (label: 'Mode Offline', color: Colors.amberAccent);
      default:
        return _hasApiKey
            ? (label: 'Siap', color: Colors.lightBlueAccent)
            : (label: 'Tanpa API Key', color: Colors.amberAccent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final badge = _statusBadge();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('AI Virtual Coach',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          Center(
            child: InkWell(
              onTap: _showApiKeyDialog,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badge.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badge.color, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: badge.color),
                    const SizedBox(width: 6),
                    Text(
                      badge.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: badge.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _resetChat,
            tooltip: 'Mulai percakapan baru',
          ),
          IconButton(
            icon: const Icon(Icons.key_rounded),
            onPressed: _showApiKeyDialog,
            tooltip: 'Atur Gemini API Key',
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner telemetri
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF1E293B),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatBadge(Icons.directions_run_rounded,
                    '${widget.currentDistanceKm.toStringAsFixed(1)} KM'),
                _buildStatBadge(Icons.speed_rounded,
                    '${widget.currentSpeedKmh.toStringAsFixed(1)} km/h'),
                _buildStatBadge(
                    Icons.directions_walk_rounded, '${widget.currentSteps} Steps'),
              ],
            ),
          ),

          // Daftar pesan
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.cyanAccent)),
                  SizedBox(width: 10),
                  Text('Coach sedang mengetik...',
                      style: TextStyle(color: Colors.white60, fontSize: 13)),
                ],
              ),
            ),

          // Preset prompt chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                _buildPromptChip('🥗 Rekomendasi Nutrisi',
                    'Beri saya rekomendasi nutrisi dan hidrasi lomba'),
                _buildPromptChip('⚡ Analisis Performa',
                    'Analisis performa pace dan ritme lari saya saat ini'),
                _buildPromptChip('⏱️ Taktik Negative Split',
                    'Bagaimana taktik negative split untuk sisa race?'),
                _buildPromptChip('⚠️ Tips Cegah Kram',
                    'Bagaimana cara mencegah kram otot betis saat race?'),
              ],
            ),
          ),

          // Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFF1E293B),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      textInputAction: TextInputAction.send,
                      decoration: const InputDecoration(
                        hintText: 'Tanya coach (nutrisi, pace, cedera, dll)...',
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send_rounded,
                        color: _isLoading ? Colors.white24 : Colors.cyanAccent),
                    onPressed: _isLoading ? null : () => _sendMessage(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AiMessage msg) {
    final isUser = msg.sender == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
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
            if (isUser)
              Text(
                msg.text,
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
              )
            else
              MarkdownBody(
                data: msg.text,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                  strong: const TextStyle(
                      color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                  em: const TextStyle(
                      color: Colors.white, fontStyle: FontStyle.italic),
                  listBullet: const TextStyle(color: Colors.white),
                  h1: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  h2: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  h3: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  code: const TextStyle(
                    color: Colors.amberAccent,
                    backgroundColor: Color(0xFF0F172A),
                    fontSize: 13,
                  ),
                  tableBody: const TextStyle(color: Colors.white, fontSize: 13),
                  tableHead: const TextStyle(
                      color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                  tableBorder: TableBorder.all(color: Colors.white24),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.cyanAccent, size: 18),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildPromptChip(String label, String prompt) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        backgroundColor: const Color(0xFF334155),
        label: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        onPressed: _isLoading ? null : () => _sendMessage(prompt),
      ),
    );
  }
}