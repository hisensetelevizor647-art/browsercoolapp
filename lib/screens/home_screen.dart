import 'package:flutter/material.dart';
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
  static const Set<String> _appLaunchVerbs = {'open', 'launch', 'start', 'run'};
  static const Set<String> _appCommandNoise = {
    'app',
    'application',
    'the',
    'a',
    'please',
    'assistant',
    'voice',
    'super',
    'mode',
  };

  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextEditingController _chatController = TextEditingController();
  final FocusNode _chatFocusNode = FocusNode();
  final TextEditingController _deviceController = TextEditingController();
  final FocusNode _deviceFocusNode = FocusNode();
  final WatchAssistantService _watchAssistantService = WatchAssistantService();

  bool _isListening = false;
  bool _showHistory = false;
  bool _isLoadingApps = false;
  bool _isSuperVoiceMode = false;
  String _deviceStatus = '';
  String _superVoiceStatus = '';
  _PromptPanelMode _panelMode = _PromptPanelMode.none;
  _PromptPanelMode _listeningMode = _PromptPanelMode.chat;
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

  dynamic _accentColor(ThemeData theme) => theme.colorScheme.primary;

  dynamic _accentDarkColor(ThemeData theme) => theme.colorScheme.secondary;

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
      _isSuperVoiceMode = false;
      _chatController.clear();
      _deviceController.clear();
      _deviceStatus = l10n.newChat;
      _superVoiceStatus = '';
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
    final listeningMode = _panelMode == _PromptPanelMode.device
        ? _PromptPanelMode.device
        : _PromptPanelMode.chat;
    if (listeningMode == _PromptPanelMode.device && _apps.isEmpty) {
      await _loadApps();
    }

    if (!mounted) return;
    setState(() {
      _isListening = true;
      _listeningMode = listeningMode;
      _panelMode = listeningMode;
      _showHistory = false;
      if (listeningMode != _PromptPanelMode.device) {
        _isSuperVoiceMode = false;
      }
      if (listeningMode == _PromptPanelMode.device) {
        _deviceController.clear();
      } else {
        _chatController.clear();
        _superVoiceStatus = '';
      }
    });
    _speech.listen(
      onResult: (val) {
        if (!mounted) return;
        setState(() {
          if (_listeningMode == _PromptPanelMode.device) {
            _deviceController.text = val.recognizedWords;
          } else {
            _chatController.text = val.recognizedWords;
          }
        });
      },
    );
  }

  Future<void> _startSuperVoiceMode() async {
    if (_isListening && _listeningMode == _PromptPanelMode.device) {
      await _stopListening();
      return;
    }

    if (_apps.isEmpty) {
      await _loadApps();
    }
    if (!mounted) return;

    final l10n = _l10n(context);
    setState(() {
      _isSuperVoiceMode = true;
      _superVoiceStatus = l10n.superVoiceMode;
      _panelMode = _PromptPanelMode.device;
      _showHistory = false;
    });

    await _startListening();
  }

  Future<void> _stopListening() async {
    if (!_isListening) return;
    await _speech.stop();
    if (!mounted) return;

    final l10n = _l10n(context);
    final mode = _listeningMode;
    final wasSuperVoice = _isSuperVoiceMode && mode == _PromptPanelMode.device;
    final spoken = TextCleaner.clean(
      mode == _PromptPanelMode.device
          ? _deviceController.text
          : _chatController.text,
    );
    setState(() => _isListening = false);
    if (spoken.isEmpty) {
      if (wasSuperVoice) {
        setState(() {
          _isSuperVoiceMode = false;
          _superVoiceStatus = l10n.superVoiceMode;
        });
      }
      return;
    }

    if (mode == _PromptPanelMode.device) {
      final appQuery = _extractAppQueryFromCommand(spoken);
      if (appQuery.isEmpty) {
        if (wasSuperVoice) {
          setState(() {
            _isSuperVoiceMode = false;
            _superVoiceStatus = l10n.appNotFound(spoken);
          });
        }
        return;
      }
      if (mounted) {
        setState(() => _deviceController.text = appQuery);
      }
      await _openAppFromPrompt(appQuery);
      if (wasSuperVoice && mounted) {
        setState(() {
          _isSuperVoiceMode = false;
          _superVoiceStatus = _deviceStatus.isNotEmpty
              ? _deviceStatus
              : l10n.appNotFound(appQuery);
        });
      }
      return;
    }

    if (_looksLikeAppLaunchCommand(spoken)) {
      final appQuery = _extractAppQueryFromCommand(spoken);
      if (appQuery.isNotEmpty) {
        if (mounted) {
          setState(() {
            _panelMode = _PromptPanelMode.device;
            _showHistory = false;
            _deviceController.text = appQuery;
          });
        }
        await _openAppFromPrompt(appQuery);
        return;
      }
    }

    await _sendChatMessage(spoken);
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
      _isSuperVoiceMode = false;
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
    final query = _normalizeForMatch(_extractAppQueryFromCommand(prompt));
    if (query.isEmpty) return null;

    final compactQuery = query.replaceAll(' ', '');
    WatchAppInfo? bestApp;
    var bestScore = 0;
    final words = query.split(' ').where((w) => w.trim().isNotEmpty).toList();

    for (final app in _apps) {
      final appName = _normalizeForMatch(app.appName);
      final packageName = _normalizeForMatch(
        app.packageName.replaceAll(RegExp(r'[._-]+'), ' '),
      );
      final compactAppName = appName.replaceAll(' ', '');
      final compactPackage = packageName.replaceAll(' ', '');
      var score = 0;

      if (appName == query || packageName == query) {
        score += 80;
      }
      if (compactAppName == compactQuery || compactPackage == compactQuery) {
        score += 50;
      }
      if (appName.startsWith(query)) {
        score += 28;
      }
      if (packageName.startsWith(query)) {
        score += 18;
      }
      if (appName.contains(query) || packageName.contains(query)) {
        score += 22;
      }
      for (final word in words) {
        if (word.length < 2) continue;
        if (appName == word || packageName == word) score += 16;
        if (appName.startsWith(word)) score += 7;
        if (packageName.startsWith(word)) score += 4;
        if (appName.contains(word)) score += 5;
        if (packageName.contains(word)) score += 3;
      }
      if (score > bestScore) {
        bestScore = score;
        bestApp = app;
      }
    }

    return bestScore > 6 ? bestApp : null;
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

  Future<void> _openAppFromPrompt([String? promptOverride]) async {
    final l10n = _l10n(context);
    final rawPrompt = TextCleaner.clean(
      promptOverride ?? _deviceController.text,
    );
    final prompt = _extractAppQueryFromCommand(rawPrompt);
    if (prompt.isEmpty) {
      if (!mounted) return;
      setState(() {
        _deviceStatus = l10n.appNotFound(rawPrompt);
      });
      return;
    }

    if (_apps.isEmpty) {
      await _loadApps();
    }

    final match = _findBestApp(prompt);
    if (match == null) {
      if (!mounted) return;
      setState(() {
        _deviceStatus = l10n.appNotFound(prompt);
      });
      return;
    }
    await _openApp(match);
  }

  String _normalizeForMatch(String value) {
    final cleaned = TextCleaner.clean(value).toLowerCase();
    return cleaned
        .replaceAll(
          RegExp(r'[^0-9a-zа-яііїєґ._\-\s]+', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _looksLikeAppLaunchCommand(String prompt) {
    final normalized = _normalizeForMatch(prompt);
    if (normalized.isEmpty) return false;
    final tokens = normalized.split(' ').where((w) => w.isNotEmpty).toList();
    if (tokens.isEmpty) return false;
    final limit = tokens.length > 4 ? 4 : tokens.length;
    for (var i = 0; i < limit; i++) {
      if (_appLaunchVerbs.contains(tokens[i])) return true;
    }
    return false;
  }

  String _extractAppQueryFromCommand(String prompt) {
    final normalized = _normalizeForMatch(prompt);
    if (normalized.isEmpty) return '';

    final tokens = normalized.split(' ').where((w) => w.isNotEmpty).toList();
    if (tokens.isEmpty) return '';

    var start = 0;
    final limit = tokens.length > 4 ? 4 : tokens.length;
    for (var i = 0; i < limit; i++) {
      if (_appLaunchVerbs.contains(tokens[i])) {
        start = i + 1;
        break;
      }
    }

    final filtered = tokens
        .skip(start)
        .where((token) => !_appCommandNoise.contains(token))
        .toList();
    return filtered.join(' ').trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          _buildBackdrop(),
          _buildMainContent(),
          if (_showHistory) _buildHistoryOverlay(),
          if (_panelMode != _PromptPanelMode.none && !_isSuperVoiceMode)
            _buildPromptPanel(),
          if (_isSuperVoiceMode || _superVoiceStatus.isNotEmpty)
            _buildSuperVoiceBadge(),
          _buildTopControls(),
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildSuperVoiceBadge() {
    final theme = Theme.of(context);
    final l10n = _l10n(context);
    final text = _isSuperVoiceMode ? l10n.superVoiceMode : _superVoiceStatus;

    return Positioned(
      left: widget.isRound ? 18 : 10,
      right: widget.isRound ? 18 : 10,
      bottom: widget.isRound ? 86 : 74,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.88),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.4),
            ),
          ),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withOpacity(0.9),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackdrop() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade500.withOpacity(isDark ? 0.34 : 0.22),
              Colors.red.shade500.withOpacity(isDark ? 0.3 : 0.2),
              Colors.yellow.shade600.withOpacity(isDark ? 0.24 : 0.16),
              Colors.green.shade500.withOpacity(isDark ? 0.3 : 0.2),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -72,
              right: -24,
              child: _buildGlow(
                color: _accentColor(theme).withOpacity(isDark ? 0.3 : 0.2),
                size: 180,
              ),
            ),
            Positioned(
              bottom: -90,
              left: -44,
              child: _buildGlow(
                color: theme.colorScheme.secondary.withOpacity(
                  isDark ? 0.24 : 0.16,
                ),
                size: 220,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlow({required dynamic color, required double size}) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(color: color, blurRadius: size * 0.35, spreadRadius: 8),
          ],
        ),
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
            icon: Icons.graphic_eq_rounded,
            onPressed: _startSuperVoiceMode,
            onLongPress: () => _openPanel(_PromptPanelMode.device),
            isActive:
                _isSuperVoiceMode || _panelMode == _PromptPanelMode.device,
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
    void Function()? onLongPress,
    bool isActive = false,
    double size = 42,
  }) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final baseColor = theme.colorScheme.surface;
    final accent = _accentColor(theme);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: isActive
            ? LinearGradient(
                colors: [accent, _accentDarkColor(theme)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [
                  baseColor.withOpacity(isDark ? 0.78 : 0.94),
                  baseColor.withOpacity(isDark ? 0.64 : 0.82),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive
              ? accent.withOpacity(0.95)
              : onSurface.withOpacity(isDark ? 0.24 : 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(isDark ? 0.5 : 0.12),
            blurRadius: 10,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          onLongPress: onLongPress,
          child: Icon(
            icon,
            size: size * 0.5,
            color: isActive ? theme.colorScheme.onPrimary : onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildMicButton() {
    final theme = Theme.of(context);
    final accent = _accentColor(theme);
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
                      color: accent.withOpacity(0.5 * _pulseController.value),
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
            backgroundColor: _isListening ? Colors.redAccent : accent,
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
        final accent = _accentColor(theme);
        final accentDark = _accentDarkColor(theme);

        if (gemini.chatHistory.isEmpty && !gemini.isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withOpacity(0.2),
                        accentDark.withOpacity(0.2),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.3),
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
                  child: Column(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            accent.withOpacity(0.6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.thinkingForSeconds(gemini.thinkingSeconds),
                        style: TextStyle(
                          fontSize: 10,
                          color: onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
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
                          colors: [accent, accentDark],
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
                      color: theme.shadowColor.withOpacity(0.18),
                      blurRadius: 8,
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
    final accent = _accentColor(theme);
    final accentDark = _accentDarkColor(theme);
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
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surface.withOpacity(0.97),
              theme.colorScheme.surfaceContainerHighest.withOpacity(0.42),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.28),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.16),
              blurRadius: 14,
            ),
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
                    backgroundColor: accent,
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
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.surfaceContainerHighest
                                    .withOpacity(0.42),
                                accentDark.withOpacity(0.08),
                              ],
                            ),
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
        final accent = _accentColor(theme);

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.colorScheme.scrim.withOpacity(0.84),
                theme.colorScheme.scrim.withOpacity(0.74),
              ],
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 46),
              Text(
                l10n.chatHistory,
                style: TextStyle(
                  color: accent,
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
                                      ? accent.withOpacity(0.18)
                                      : theme.colorScheme.surface.withOpacity(
                                          0.74,
                                        ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isActive
                                        ? accent.withOpacity(0.52)
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
                                        color: accent,
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

  String _extractContentText(ChatMessage content) {
    final cleaned = TextCleaner.clean(content.content);
    return cleaned.isEmpty ? '...' : cleaned;
  }
}
