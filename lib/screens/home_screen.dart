import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart'
    show Content, TextPart;
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../services/gemini_service.dart';
import '../services/settings_service.dart';
import '../services/chat_history_service.dart';
import '../services/text_cleaner.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.openKeyboardOnStart = false,
    this.isRound = false,
  });

  final bool openKeyboardOnStart;
  final bool isRound;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static final _accentColor = Colors.blueAccent.shade400;
  static final _accentDarkColor = Colors.blue.shade700;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _promptText = "";
  final TextEditingController _controller = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  bool _showKeyboard = false;
  bool _showHistory = false;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _showKeyboard = widget.openKeyboardOnStart;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    if (_showKeyboard) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _textFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _controller.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    final micStatus = await Permission.microphone.request();
    if (micStatus != PermissionStatus.granted) return;

    final available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (val) {
          setState(() {
            _promptText = val.recognizedWords;
            _controller.text = _promptText;
          });
        },
      );
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
    if (_promptText.isNotEmpty) {
      _sendMessage(_promptText);
    }
  }

  Future<void> _sendMessage(String text) async {
    final settings = Provider.of<SettingsService>(context, listen: false);
    final cleanedText = TextCleaner.clean(
      text,
      disallowCjk: settings.language != 'zh',
    );
    if (cleanedText.isEmpty) return;

    final gemini = Provider.of<GeminiService>(context, listen: false);
    final history = Provider.of<ChatHistoryService>(context, listen: false);
    await history.addMessageToCurrentSession('user', cleanedText);
    final reply = await gemini.sendMessage(cleanedText);
    if (reply != null && !reply.startsWith('Error:')) {
      await history.addMessageToCurrentSession('model', reply);
    }

    if (!mounted) return;
    setState(() {
      _promptText = "";
      _controller.clear();
      _showKeyboard = false;
    });
  }

  Future<void> _loadChatSession(ChatSession session) async {
    final gemini = Provider.of<GeminiService>(context, listen: false);
    final history = Provider.of<ChatHistoryService>(context, listen: false);
    gemini.loadHistoryFromSession(session.messages);
    await history.setCurrentSession(session.id);
    if (!mounted) return;
    setState(() {
      _showHistory = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildMainContent(),
          if (_showHistory) _buildHistoryOverlay(),
          _buildTopControls(),
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildTopControls() {
    final topInset = widget.isRound ? 22.0 : 10.0;
    return Positioned(
      top: topInset,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSmallButton(
            icon: Icons.history_rounded,
            onPressed: () => setState(() => _showHistory = !_showHistory),
            isActive: _showHistory,
          ),
          const SizedBox(width: 25),
          _buildSmallButton(
            icon: Icons.settings_rounded,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    final bottomInset = widget.isRound ? 22.0 : 10.0;
    return Positioned(
      bottom: bottomInset,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSmallButton(
            icon: Icons.add_rounded,
            onPressed: () => setState(() {
              _showKeyboard = true;
              _textFocusNode.requestFocus();
            }),
            isActive: _showKeyboard,
          ),
          const SizedBox(width: 15),
          _buildMicButton(),
          const SizedBox(width: 15),
          _buildSmallButton(
            icon: Icons.assistant_rounded,
            onPressed: () => Navigator.pushNamed(context, '/assistant'),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallButton({
    required IconData icon,
    required void Function() onPressed,
    bool isActive = false,
    double size = 42,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isActive
            ? _accentColor.withOpacity(0.3)
            : Colors.grey.shade900.withOpacity(0.5),
        shape: BoxShape.circle,
        border: isActive ? Border.all(color: _accentColor, width: 1) : null,
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Icon(icon, size: size * 0.5, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildMicButton() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: _isListening
                ? [
                    BoxShadow(
                      color: _accentColor.withOpacity(
                        0.5 * _pulseController.value,
                      ),
                      blurRadius: 15 * _pulseController.value,
                      spreadRadius: 5 * _pulseController.value,
                    ),
                  ]
                : [],
          ),
          child: FloatingActionButton(
            heroTag: "mic",
            elevation: 4,
            onPressed: _isListening ? _stopListening : _startListening,
            backgroundColor: _isListening ? Colors.redAccent : _accentColor,
            shape: const CircleBorder(),
            child: Icon(
              _isListening ? Icons.mic_off_rounded : Icons.mic_rounded,
              size: 28,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainContent() {
    return Consumer2<GeminiService, SettingsService>(
      builder: (context, gemini, settings, _) {
        if (gemini.chatHistory.isEmpty && !gemini.isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _accentColor.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  settings.modelDisplayName.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Tap to speak",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(
            widget.isRound ? 22 : 14,
            widget.isRound ? 56 : 40,
            widget.isRound ? 22 : 14,
            widget.isRound ? 132 : 120,
          ),
          itemCount: gemini.chatHistory.length + (gemini.isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == gemini.chatHistory.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        _accentColor.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              );
            }
            final content = gemini.chatHistory[index];
            final isUser = content.role != 'model';
            final text = _extractContentText(content, settings.language);

            return Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                ),
                decoration: BoxDecoration(
                  gradient: isUser
                      ? LinearGradient(
                          colors: [_accentColor, _accentDarkColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : LinearGradient(
                          colors: [Colors.grey[850]!, Colors.grey[900]!],
                        ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Text(
                  text,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryOverlay() {
    return Consumer<ChatHistoryService>(
      builder: (context, historyService, _) {
        final sessions = historyService.sessions;

        return Container(
          color: Colors.black.withOpacity(0.9),
          child: Column(
            children: [
              const SizedBox(height: 50),
              Text(
                "CHAT HISTORY",
                style: TextStyle(
                  color: _accentColor,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: sessions.isEmpty
                    ? const Center(
                        child: Text(
                          "No History",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: sessions.length,
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          final isActive =
                              session.id == historyService.currentSessionId;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: InkWell(
                              onTap: () => _loadChatSession(session),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? _accentColor.withOpacity(0.15)
                                      : Colors.grey.shade900.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(12),
                                  border: isActive
                                      ? Border.all(
                                          color: _accentColor.withOpacity(0.5),
                                        )
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        TextCleaner.clean(
                                          session.title,
                                          disallowCjk: true,
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isActive)
                                      Icon(
                                        Icons.check_circle,
                                        color: _accentColor,
                                        size: 14,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              TextButton(
                onPressed: () => setState(() => _showHistory = false),
                child: const Text(
                  "CLOSE",
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  String _extractContentText(Content content, String languageCode) {
    final rawText = content.parts.map((part) {
      if (part is TextPart) return part.text;
      return part.toString();
    }).join();
    final cleaned = TextCleaner.clean(
      rawText,
      disallowCjk: languageCode != 'zh',
    );
    return cleaned.isEmpty ? '...' : cleaned;
  }
}
