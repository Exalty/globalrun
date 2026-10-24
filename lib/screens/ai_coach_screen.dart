import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_coach_service.dart';
import '../theme/duo_theme.dart';

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
            ? 'Halo, aku Rani, pelatih lari dan nutrisi kamu. Ada yang ingin kamu diskusikan seputar strategi pace lomba, nutrisi, atau pemulihan fisik?'
            : 'Halo, aku Rani, pelatih lari kamu.\n\nAPI Key Gemini belum diatur. Silakan tambahkan di file `.env` atau klik tombol kunci di kanan atas agar aku bisa menjawab pertanyaanmu.',
        timestamp: DateTime.now(),
      ),
    );
  }

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
            text: 'Maaf, terjadi kendala saat memproses: $e',
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
    final palette = DuoColors.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: palette.surfaceBorder, width: 1.5),
          ),
          title: Text(
            'Konfigurasi Gemini API Key',
            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 17),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Masukkan Google Gemini API Key. Key yang disimpan di sini akan menimpa konfigurasi bawaan. Kosongkan lalu simpan untuk menghapusnya.',
                style: TextStyle(color: palette.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _apiKeyController,
                obscureText: true,
                style: TextStyle(color: palette.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'AIzaSy...',
                  hintStyle: TextStyle(color: palette.textMuted),
                  filled: true,
                  fillColor: palette.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: palette.surfaceBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: palette.surfaceBorder),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Batal', style: TextStyle(color: palette.textMuted)),
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
                        ? 'API Key berhasil disimpan'
                        : 'API Key berhasil dihapus'),
                    backgroundColor: key.isNotEmpty ? DuoColors.questGreen : DuoColors.streakGold,
                  ),
                );
                setState(() {});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  ({String label, Color color}) _statusBadge(DuoColorPalette palette) {
    switch (widget.coachService.lastSourceUsed) {
      case 'gemini':
        return (label: 'Gemini Live', color: DuoColors.questGreen);
      case 'local':
        return (label: 'Mode Offline', color: DuoColors.streakGold);
      default:
        return _hasApiKey
            ? (label: 'Siap', color: palette.primaryBlue)
            : (label: 'Tanpa API Key', color: DuoColors.streakGold);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = DuoColors.of(context);
    final badge = _statusBadge(palette);

    return Scaffold(
      backgroundColor: palette.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          'COACH RANI',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            fontSize: 18,
            color: palette.textPrimary,
          ),
        ),
        backgroundColor: palette.surface,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: palette.surfaceBorder, width: 2)),
        actions: [
          Center(
            child: InkWell(
              onTap: _showApiKeyDialog,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badge.color.withOpacity(palette.isDark ? 0.20 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: badge.color, width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fiber_manual_record, size: 7, color: badge.color),
                    const SizedBox(width: 4),
                    Text(
                      badge.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: badge.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: const EdgeInsets.all(6),
            icon: Icon(Icons.refresh_rounded, color: palette.textSecondary, size: 20),
            onPressed: _resetChat,
            tooltip: 'Mulai percakapan baru',
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: const EdgeInsets.all(6),
            icon: Icon(Icons.key_rounded, color: palette.textSecondary, size: 20),
            onPressed: _showApiKeyDialog,
            tooltip: 'Atur Gemini API Key',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // Banner telemetri aktivitas (Responsif potret tanpa overflow)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: palette.surface,
              border: Border(bottom: BorderSide(color: palette.surfaceBorder, width: 1.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatBadge(
                    Icons.directions_run_rounded,
                    '${widget.currentDistanceKm.toStringAsFixed(1)} KM',
                    palette,
                  ),
                ),
                Container(width: 1, height: 18, color: palette.surfaceBorder),
                Expanded(
                  child: _buildStatBadge(
                    Icons.speed_rounded,
                    '${widget.currentSpeedKmh.toStringAsFixed(1)} km/h',
                    palette,
                  ),
                ),
                Container(width: 1, height: 18, color: palette.surfaceBorder),
                Expanded(
                  child: _buildStatBadge(
                    Icons.directions_walk_rounded,
                    '${widget.currentSteps} Steps',
                    palette,
                  ),
                ),
              ],
            ),
          ),

          // Daftar pesan chat
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _buildMessageBubble(_messages[index], palette),
            ),
          ),

          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: palette.primaryBlue),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Rani sedang berpikir...',
                    style: TextStyle(color: palette.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

          // Preset prompt chips (tanpa emoji, material icons rapi)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _buildPromptChip(
                    Icons.restaurant_rounded,
                    'Rekomendasi Nutrisi',
                    'Beri saya rekomendasi nutrisi dan hidrasi lomba',
                    palette,
                  ),
                  _buildPromptChip(
                    Icons.insights_rounded,
                    'Analisis Performa',
                    'Analisis performa pace dan ritme lari saya saat ini',
                    palette,
                  ),
                  _buildPromptChip(
                    Icons.timer_outlined,
                    'Taktik Negative Split',
                    'Bagaimana strategi negative split untuk sisa lomba?',
                    palette,
                  ),
                  _buildPromptChip(
                    Icons.healing_rounded,
                    'Tips Cegah Kram',
                    'Bagaimana cara mencegah kram otot betis saat race?',
                    palette,
                  ),
                ],
              ),
            ),
          ),

          // Input field bawah
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: palette.surface,
              border: Border(top: BorderSide(color: palette.surfaceBorder, width: 1.5)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: palette.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.surfaceBorder),
                      ),
                      child: TextField(
                        controller: _textController,
                        style: TextStyle(color: palette.textPrimary, fontSize: 14),
                        textInputAction: TextInputAction.send,
                        decoration: InputDecoration(
                          hintText: 'Tanya Rani seputar pace, nutrisi, atau recovery...',
                          hintStyle: TextStyle(color: palette.textMuted, fontSize: 13),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.send_rounded,
                      color: _isLoading ? palette.textMuted.withOpacity(0.4) : palette.primaryBlue,
                    ),
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

  Widget _buildMessageBubble(AiMessage msg, DuoColorPalette palette) {
    final isUser = msg.sender == 'user';
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: screenWidth * 0.82),
        decoration: BoxDecoration(
          color: isUser ? palette.primaryBlue : palette.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(3),
            bottomRight: isUser ? const Radius.circular(3) : const Radius.circular(16),
          ),
          border: isUser ? null : Border.all(color: palette.surfaceBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: isUser ? palette.primaryBlueShadow : palette.surfaceShadow,
              offset: const Offset(0, 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUser ? Icons.person_rounded : Icons.psychology_rounded,
                  size: 15,
                  color: isUser ? Colors.white70 : palette.primaryBlue,
                ),
                const SizedBox(width: 6),
                Text(
                  isUser ? 'Anda' : 'Rani',
                  style: TextStyle(
                    color: isUser ? Colors.white70 : palette.primaryBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (!isUser) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: palette.primaryBlue.withOpacity(palette.isDark ? 0.22 : 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'AI Coach',
                      style: TextStyle(
                        color: palette.primaryBlue,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            if (isUser)
              Text(
                msg.text,
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.45),
              )
            else
              MarkdownBody(
                data: msg.text,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(color: palette.textPrimary, fontSize: 14, height: 1.45),
                  strong: TextStyle(color: palette.primaryBlue, fontWeight: FontWeight.bold),
                  em: TextStyle(color: palette.textPrimary, fontStyle: FontStyle.italic),
                  listBullet: TextStyle(color: palette.textSecondary),
                  h1: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                  h2: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                  h3: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                  code: TextStyle(
                    color: DuoColors.streakGold,
                    backgroundColor: palette.background,
                    fontSize: 13,
                  ),
                  tableBody: TextStyle(color: palette.textPrimary, fontSize: 13),
                  tableHead: TextStyle(color: palette.primaryBlue, fontWeight: FontWeight.bold),
                  tableBorder: TableBorder.all(color: palette.surfaceBorder),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String text, DuoColorPalette palette) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: palette.primaryBlue, size: 16),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPromptChip(
    IconData icon,
    String label,
    String prompt,
    DuoColorPalette palette,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: _isLoading ? null : () => _sendMessage(prompt),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.surfaceBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: palette.surfaceShadow,
                offset: const Offset(0, 2),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: palette.primaryBlue),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
