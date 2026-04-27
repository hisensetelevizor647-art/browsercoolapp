import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart'
    show Content, TextPart;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/app_localizer.dart';
import '../services/chat_history_service.dart';
import '../services/gemini_service.dart';
import '../services/settings_service.dart';
import '../services/text_cleaner.dart';
import '../services/watch_assistant_service.dart';
import 'settings_screen.dart';

enum _PromptPanelMode { none, chat, device }

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
  final TextEditingController _chatController = TextEditingController();
  final FocusNode _chatFocusNode = FocusNode();
  final TextEditingController _deviceController = TextEditingController();
  final FocusNode _deviceFocusNode = FocusNode();
  final WatchAssistantService _watchAssistantService = WatchAssistantService();

  bool _isListening = false;
  bool _showHistory = false;
  bool _isLoadingApps = false;
  String _deviceStatus = '';
  _PromptPanelMode _panelMode = _PromptPanelMode.none;
  List<WatchAppInfo> _apps = const [];

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    if (widget.openKeyboardOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openPanel(_PromptPanelMode.chat);
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _chatController.dispose();
    _chatFocusNode.dispose();
    _deviceController.dispose();
    _deviceFocusNode.dispose();
    super.dispose();
  }

  AppLocalizer _l10n(BuildContext context) {
    final language = Provider.of<SettingsService>(
      context,
      listen: false,
    ).language;
    return AppLocalizer.fromCode(language);
  }

  Future<void> _startNewChat() async {
    final l10n = _l10n(context);
    final gemini = Provider.of<GeminiService>(context, listen: false);
    final history = Provider.of<ChatHistoryService>(context, listen: false);
    gemini.startNewChat();
    await history.createNewSession(title: l10n.newChat);
    if (!mounted) return;
    setState(() {
      _panelMode = _PromptPanelMode.none;
      _showHistory = false;
      _chatController.clear();
      _deviceController.clear();
      _deviceStatus = l10n.newChat;
    });
  }

  Future<void> _startListening() async {
    final l10n = _l10n(context);
    final micStatus = await Permission.microphone.request();
    if (micStatus != PermissionStatus.granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.micPermissionRequired)));
      return;
    }

    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'notListening' && _isListening) {
          _stopListening();
        }
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _isListening = false);
      },
    );

    if (!available) return;

    if (!mounted) return;
    setState(() {
      _isListening = true;
      _chatController.clear();
      _openPanel(_PromptPanelMode.chat, requestFocus: false);
    });
    _speech.listen(
      onResult: (val) {
        if (!mounted) return;
        setState(() {
          _chatController.text = val.recognizedWords;
        });
      },
    );
  }

  void _stopListening() {
    _speech.stop();
    if (!mounted) return;
    setState(() => _isListening = false);
    final spoken = _chatController.text.trim();
    if (spoken.isNotEmpty) {
      _sendChatMessage(spoken);
    }
  }

  Future<void> _sendChatMessage(String text) async {
    final cleanedText = TextCleaner.clean(text);
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
      _chatController.clear();
      _panelMode = _PromptPanelMode.none;
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
      _panelMode = _PromptPanelMode.none;
    });
  }

  Future<void> _loadApps() async {
    if (_isLoadingApps) return;
    setState(() => _isLoadingApps = true);
    try {
      final apps = await _watchAssistantService.getLaunchableApps();
      if (!mounted) return;
      setState(() {
        _apps = apps;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingApps = false);
      }
    }
  }

  void _openPanel(_PromptPanelMode mode, {bool requestFocus = true}) {
    setState(() {
      _panelMode = _panelMode == mode ? _PromptPanelMode.none : mode;
      _showHistory = false;
    });

    if (_panelMode == _PromptPanelMode.none) return;
    if (_panelMode == _PromptPanelMode.device && _apps.isEmpty) {
      _loadApps();
    }
    if (!requestFocus) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_panelMode == _PromptPanelMode.chat) {
        _chatFocusNode.requestFocus();
      } else if (_panelMode == _PromptPanelMode.device) {
        _deviceFocusNode.requestFocus();
      }
    });
  }

  WatchAppInfo? _findBestApp(String prompt) {
    final query = TextCleaner.clean(prompt).toLowerCase();
    if (query.isEmpty) return null;

    WatchAppInfo? bestApp;
    var bestScore = 0;
    final words = query.split(' ').where((w) => w.trim().isNotEmpty).toList();

    for (final app in _apps) {
      final appName = app.appName.toLowerCase();
      final packageName = app.packageName.toLowerCase();
      var score = 0;
      if (appName == query || packageName == query) {
        score += 50;
      }
      if (appName.contains(query) || packageName.contains(query)) {
        score += 20;
      }
      for (final word in words) {
        if (word.length < 2) continue;
        if (appName.contains(word)) score += 4;
        if (packageName.contains(word)) score += 2;
      }
      if (score > bestScore) {
        bestScore = score;
        bestApp = app;
      }
    }

    return bestScore > 0 ? bestApp : null;
  }

  Future<void> _openApp(WatchAppInfo app) async {
    final l10n = _l10n(context);
    final success = await _watchAssistantService.openApp(app.packageName);
    if (!mounted) return;
    setState(() {
      _deviceStatus = success
          ? l10n.appOpened(app.appName)
          : l10n.appOpenFailed(app.appName);
      if (success) {
        _panelMode = _PromptPanelMode.none;
        _deviceController.clear();
      }
    });
  }

  Future<void> _openAppFromPrompt() async {
    final l10n = _l10n(context);
    final prompt = _deviceController.text;
    final match = _findBestApp(prompt);
    if (match == null) {
      setState(() {
        _deviceStatus = l10n.appNotFound(prompt.trim());
      });
      return;
    }
    await _openApp(match);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          _buildMainContent(),
          if (_showHistory) _buildHistoryOverlay(),
          if (_panelMode != _PromptPanelMode.none) _buildPromptPanel(),
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
      left: widget.isRound ? 8 : 4,
      right: widget.isRound ? 8 : 4,
      child: Row(
        children: [
          _buildSmallButton(icon: Icons.add_rounded, onPressed: _startNewChat),
          Expanded(
            child: Center(
              child: _buildSmallButton(
                icon: Icons.history_rounded,
                onPressed: () => setState(() {
                  _showHistory = !_showHistory;
                  _panelMode = _PromptPanelMode.none;
                }),
                isActive: _showHistory,
              ),
            ),
          ),
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
    final bottomInset = widget.isRound ? 20.0 : 10.0;
    return Positioned(
      bottom: bottomInset,
      left: widget.isRound ? 8 : 4,
      right: widget.isRound ? 8 : 4,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSmallButton(
            icon: Icons.devices_rounded,
            onPressed: () => _openPanel(_PromptPanelMode.device),
            isActive: _panelMode == _PromptPanelMode.device,
            size: 40,
          ),
          const SizedBox(width: 14),
          _buildMicButton(),
          const SizedBox(width: 14),
          _buildSmallButton(
            icon: Icons.keyboard_rounded,
            onPressed: () => _openPanel(_PromptPanelMode.chat),
            isActive: _panelMode == _PromptPanelMode.chat,
            size: 40,
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
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final baseColor = theme.colorScheme.surface;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isActive
            ? _accentColor.withOpacity(0.22)
            : baseColor.withOpacity(
                theme.brightness == Brightness.dark ? 0.72 : 0.92,
              ),
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive
              ? _accentColor
              : onSurface.withOpacity(
                  theme.brightness == Brightness.dark ? 0.28 : 0.2,
                ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Icon(icon, size: size * 0.5, color: onSurface),
        ),
      ),
    );
  }

  Widget _buildMicButton() {
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;
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
              color: onPrimary,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainContent() {
    return Consumer2<GeminiService, SettingsService>(
      builder: (context, gemini, settings, _) {
        final l10n = AppLocalizer.fromCode(settings.language);
        final theme = Theme.of(context);
        final onSurface = theme.colorScheme.onSurface;

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
                  style: TextStyle(
                    color: onSurface.withOpacity(0.55),
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.tapToSpeak,
                  style: TextStyle(
                    color: onSurface.withOpacity(0.62),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(
            widget.isRound ? 22 : 14,
            widget.isRound ? 58 : 42,
            widget.isRound ? 22 : 14,
            widget.isRound ? 135 : 122,
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
            final text = _extractContentText(content);
            final modelBubble = theme.colorScheme.surface;

            return Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.82,
                ),
                decoration: BoxDecoration(
                  gradient: isUser
                      ? LinearGradient(
                          colors: [_accentColor, _accentDarkColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : LinearGradient(
                          colors: [
                            modelBubble.withOpacity(0.95),
                            modelBubble.withOpacity(0.86),
                          ],
                        ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withOpacity(0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    color: isUser ? theme.colorScheme.onPrimary : onSurface,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPromptPanel() {
    final settings = Provider.of<SettingsService>(context, listen: false);
    final l10n = AppLocalizer.fromCode(settings.language);
    final theme = Theme.of(context);
    final isDevice = _panelMode == _PromptPanelMode.device;
    final controller = isDevice ? _deviceController : _chatController;
    final focusNode = isDevice ? _deviceFocusNode : _chatFocusNode;

    return Positioned(
      left: widget.isRound ? 10 : 6,
      right: widget.isRound ? 10 : 6,
      bottom: widget.isRound ? 92 : 80,
      child: Container(
        constraints: BoxConstraints(
          minHeight: 80,
          maxHeight: isDevice ? 190 : 115,
        ),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.94),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(color: theme.shadowColor.withOpacity(0.2), blurRadius: 8),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isDevice ? l10n.deviceControl : l10n.chatInput,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: isDevice
                          ? l10n.devicePromptHint
                          : l10n.chatPromptHint,
                      hintStyle: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withOpacity(0.35),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => isDevice
                        ? _openAppFromPrompt()
                        : _sendChatMessage(controller.text),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 34,
                  height: 34,
                  child: FloatingActionButton(
                    heroTag: isDevice ? 'device_send' : 'chat_send',
                    mini: true,
                    onPressed: isDevice
                        ? _openAppFromPrompt
                        : () => _sendChatMessage(controller.text),
                    backgroundColor: _accentColor,
                    child: Icon(
                      isDevice ? Icons.open_in_new_rounded : Icons.send_rounded,
                      size: 16,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (isDevice) ...[
              const SizedBox(height: 8),
              if (_isLoadingApps)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${l10n.deviceControl}...',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
              if (_deviceStatus.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    _deviceStatus,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withOpacity(0.85),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _apps.length > 6 ? 6 : _apps.length,
                  itemBuilder: (context, index) {
                    final app = _apps[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: InkWell(
                        onTap: () => _openApp(app),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withOpacity(0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  app.appName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.open_in_new_rounded,
                                size: 12,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.7,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryOverlay() {
    return Consumer2<ChatHistoryService, SettingsService>(
      builder: (context, historyService, settings, _) {
        final l10n = AppLocalizer.fromCode(settings.language);
        final sessions = historyService.sessions;
        final theme = Theme.of(context);

        return Container(
          color: theme.colorScheme.scrim.withOpacity(0.74),
          child: Column(
            children: [
              const SizedBox(height: 46),
              Text(
                l10n.chatHistory,
                style: TextStyle(
                  color: _accentColor,
                  fontSize: 12,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: sessions.isEmpty
                    ? Center(
                        child: Text(
                          l10n.noHistory,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
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
                                      : theme.colorScheme.surface.withOpacity(
                                          0.74,
                                        ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isActive
                                        ? _accentColor.withOpacity(0.5)
                                        : theme.colorScheme.outline.withOpacity(
                                            0.25,
                                          ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        TextCleaner.clean(session.title),
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface,
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
                child: Text(
                  l10n.close.toUpperCase(),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  String _extractContentText(Content content) {
    final rawText = content.parts.map((part) {
      if (part is TextPart) return part.text;
      return part.toString();
    }).join();
    final cleaned = TextCleaner.clean(rawText);
    return cleaned.isEmpty ? '...' : cleaned;
  }
}
