import 'dart:async';
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
import '../theme/watch_theme.dart';
import 'settings_screen.dart';
import 'voice_live_screen.dart';

enum _PromptPanelMode { none, chat, device }

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.openKeyboardOnStart = false,
    this.startInVoiceMode = false,
    this.isRound = false,
  });

  final bool openKeyboardOnStart;
  final bool startInVoiceMode;
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
  final TextEditingController _historySearchController = TextEditingController();
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

  // Voice recording timer
  Timer? _recordTimer;
  int _recordSeconds = 0;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    if (widget.openKeyboardOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openPanel(_PromptPanelMode.chat);
      });
    } else if (widget.startInVoiceMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openVoiceLiveMode();
      });
    }
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _pulseController.dispose();
    _chatController.dispose();
    _chatFocusNode.dispose();
    _deviceController.dispose();
    _deviceFocusNode.dispose();
    _historySearchController.dispose();
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
        _stopRecordingTimer();
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
      _recordSeconds = 0;
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

    _startRecordingTimer();
    _pulseController.repeat(reverse: true);

    _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        onDevice: true,
        partialResults: true,
      ),
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

  void _startRecordingTimer() {
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _recordSeconds = timer.tick;
      });
    });
  }

  void _stopRecordingTimer() {
    _recordTimer?.cancel();
    _recordTimer = null;
    _pulseController.stop();
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

  Future<void> _openVoiceLiveMode() async {
    if (_isListening) {
      _stopRecordingTimer();
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
      await _speech.stop();
    }
    if (!mounted) return;

    setState(() {
      _isListening = false;
      _isSuperVoiceMode = false;
      _superVoiceStatus = '';
      _panelMode = _PromptPanelMode.none;
      _showHistory = false;
    });

    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            VoiceLiveScreen(isRound: widget.isRound),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _stopListening() async {
    if (!_isListening) return;
    _stopRecordingTimer();

    if (mounted) {
      setState(() => _isListening = false);
    }
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

    if (mounted) {
      setState(() {
        _chatController.clear();
        _panelMode = _PromptPanelMode.none;
      });
    }

    final reply = await gemini.sendMessage(cleanedText);
    if (reply != null && !reply.startsWith('Error:') && reply != 'Generation stopped') {
      await history.addMessageToCurrentSession('model', reply);
    }
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
          RegExp('[^0-9a-z\\u0400-\\u04FF._\\-\\s]+', caseSensitive: false),
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

  String _formatTimer(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gemini = Provider.of<GeminiService>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          _buildBackdrop(),
          _buildMainContent(),
          if (_isListening) _buildRecordingBanner(theme),
          if (_isSuperVoiceMode || _superVoiceStatus.isNotEmpty)
            _buildSuperVoiceBadge(),
          if (_showHistory) _buildHistoryOverlay(),
          if (_panelMode != _PromptPanelMode.none && !_isSuperVoiceMode)
            _buildCurvedPromptPanel(),
          if (_panelMode == _PromptPanelMode.none) ...[
            _buildTopControls(),
            _buildBottomControls(gemini),
          ],
        ],
      ),
    );
  }

  Widget _buildRecordingBanner(ThemeData theme) {
    return Positioned(
      top: widget.isRound ? 50 : 26,
      left: 20,
      right: 20,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.red.shade900.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.red.shade600.withOpacity(0.4),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTimer(_recordSeconds),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuperVoiceBadge() {
    final theme = Theme.of(context);
    final l10n = _l10n(context);
    final text = _isSuperVoiceMode ? l10n.superVoiceMode : _superVoiceStatus;

    return Positioned(
      left: widget.isRound ? 22 : 10,
      right: widget.isRound ? 22 : 10,
      bottom: widget.isRound ? 95 : 74,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.4),
            ),
          ),
          child: Text(
            text,
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
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

    return RepaintBoundary(
      child: Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: WatchTheme.getGradientColors(
                Provider.of<SettingsService>(
                  context,
                  listen: false,
                ).backgroundTheme,
                isDark,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    final topInset = widget.isRound ? 28.0 : 8.0;
    return Positioned(
      top: topInset,
      left: widget.isRound ? 14 : 4,
      right: widget.isRound ? 14 : 4,
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

  Widget _buildBottomControls(GeminiService gemini) {
    final bottomInset = widget.isRound ? 22.0 : 6.0;
    final isGenerating = gemini.isLoading;

    return Positioned(
      bottom: bottomInset,
      left: widget.isRound ? 14 : 4,
      right: widget.isRound ? 14 : 4,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSmallButton(
            icon: Icons.graphic_eq_rounded,
            onPressed: () => _openVoiceLiveMode(),
            onLongPress: () => _startSuperVoiceMode(),
            isActive:
                _isSuperVoiceMode || _panelMode == _PromptPanelMode.device,
            size: 38,
          ),
          const SizedBox(width: 14),
          _buildMicOrStopButton(),
          const SizedBox(width: 14),
          // If generating, show Stop button; otherwise show Keyboard button
          if (isGenerating)
            _buildSmallButton(
              icon: Icons.stop_rounded,
              onPressed: () => gemini.stopGeneration(),
              isActive: true,
              size: 38,
              customColor: Colors.redAccent,
            )
          else
            _buildSmallButton(
              icon: Icons.keyboard_rounded,
              onPressed: () => _openPanel(_PromptPanelMode.chat),
              isActive: _panelMode == _PromptPanelMode.chat,
              size: 38,
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
    double size = 38,
    Color? customColor,
  }) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final baseColor = theme.colorScheme.surface;
    final accent = customColor ?? _accentColor(theme);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: isActive
            ? LinearGradient(
                colors: [accent, customColor ?? _accentDarkColor(theme)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: isDark
                    ? const [
                        Color(0xFF181818),
                        Color(0xFF0E0E0E),
                      ]
                    : [
                        baseColor.withOpacity(0.94),
                        baseColor.withOpacity(0.82),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive
              ? accent.withOpacity(0.95)
              : isDark
                  ? const Color(0xFF2A2A2A)
                  : onSurface.withOpacity(0.14),
          width: isDark ? 1.0 : 0.8,
        ),
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
            size: size * 0.52,
            color: isActive ? theme.colorScheme.onPrimary : onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildMicOrStopButton() {
    final theme = Theme.of(context);
    final accent = _accentColor(theme);

    if (_isListening) {
      // Square stop recording button with timer
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.redAccent.shade200.withOpacity(0.5),
              blurRadius: 12,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _stopListening,
            child: const Icon(
              Icons.stop_rounded,
              size: 28,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 52,
      height: 52,
      child: FloatingActionButton(
        heroTag: "mic_main",
        elevation: 3,
        onPressed: _startListening,
        backgroundColor: accent,
        shape: const CircleBorder(),
        child: Icon(
          Icons.mic_rounded,
          size: 26,
          color: theme.colorScheme.onPrimary,
        ),
      ),
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
                const SizedBox(height: 12),
                // Properly sized, non-inverted watch logo container
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accent.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.25),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  settings.modelDisplayName.toUpperCase(),
                  style: TextStyle(
                    color: onSurface.withOpacity(0.65),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.tapToSpeak,
                  style: TextStyle(
                    color: onSurface.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(
            widget.isRound ? 24 : 10,
            widget.isRound ? 56 : 38,
            widget.isRound ? 24 : 10,
            widget.isRound ? 115 : 95,
          ),
          itemCount: gemini.chatHistory.length + (gemini.isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == gemini.chatHistory.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Column(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            accent.withOpacity(0.8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.thinkingForSeconds(gemini.thinkingSeconds),
                        style: TextStyle(
                          fontSize: 10,
                          color: onSurface.withOpacity(0.75),
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
            final isDark = theme.brightness == Brightness.dark;
            final modelBubble = isDark ? const Color(0xFF161616) : theme.colorScheme.surface;

            return Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.85,
                ),
                decoration: BoxDecoration(
                  gradient: isUser
                      ? LinearGradient(
                          colors: [accent, accentDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : LinearGradient(
                          colors: isDark
                              ? const [
                                  Color(0xFF161616),
                                  Color(0xFF111111),
                                ]
                              : [
                                  modelBubble.withOpacity(0.95),
                                  modelBubble.withOpacity(0.88),
                                ],
                        ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isUser
                        ? Colors.transparent
                        : isDark
                            ? const Color(0xFF262626)
                            : theme.colorScheme.outline.withOpacity(0.15),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withOpacity(isDark ? 0.35 : 0.12),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    color: isUser ? theme.colorScheme.onPrimary : onSurface,
                    fontSize: 11,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Semicircular bottom curved panel for prompt / keyboard input
  Widget _buildCurvedPromptPanel() {
    final settings = Provider.of<SettingsService>(context, listen: false);
    final l10n = AppLocalizer.fromCode(settings.language);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = _accentColor(theme);
    final isDevice = _panelMode == _PromptPanelMode.device;
    final controller = isDevice ? _deviceController : _chatController;
    final focusNode = isDevice ? _deviceFocusNode : _chatFocusNode;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          widget.isRound ? 20 : 12,
          10,
          widget.isRound ? 20 : 12,
          widget.isRound ? 24 : 12,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF0F0F0F)
              : theme.colorScheme.surface.withOpacity(0.98),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(
              color: isDark ? accent.withOpacity(0.6) : accent.withOpacity(0.4),
              width: 1.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.7 : 0.4),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  isDevice ? l10n.deviceControl : l10n.chatInput,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _panelMode = _PromptPanelMode.none),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.send,
                      autocorrect: false,
                      enableSuggestions: false,
                      enableInteractiveSelection: true,
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
                          fontSize: 10,
                          color: theme.colorScheme.onSurface.withOpacity(0.45),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                      onSubmitted: (_) => isDevice
                          ? _openAppFromPrompt()
                          : _sendChatMessage(controller.text),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: FloatingActionButton(
                    heroTag: isDevice ? 'device_send' : 'chat_send',
                    mini: true,
                    elevation: 1,
                    onPressed: isDevice
                        ? _openAppFromPrompt
                        : () => _sendChatMessage(controller.text),
                    backgroundColor: accent,
                    child: Icon(
                      isDevice ? Icons.open_in_new_rounded : Icons.send_rounded,
                      size: 15,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (isDevice && _apps.isNotEmpty) ...[
              const SizedBox(height: 6),
              SizedBox(
                height: 55,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _apps.length > 8 ? 8 : _apps.length,
                  itemBuilder: (context, index) {
                    final app = _apps[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(
                          app.appName,
                          style: const TextStyle(fontSize: 9),
                        ),
                        onPressed: () => _openApp(app),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
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

  // Searchable & Deletable Chat History Overlay
  Widget _buildHistoryOverlay() {
    return Consumer2<ChatHistoryService, SettingsService>(
      builder: (context, historyService, settings, _) {
        final l10n = AppLocalizer.fromCode(settings.language);
        final theme = Theme.of(context);
        final accent = _accentColor(theme);
        final searchQuery = _historySearchController.text;
        final sessions = historyService.filterSessions(searchQuery);

        final isDark = theme.brightness == Brightness.dark;

        return Container(
          color: isDark
              ? Colors.black.withOpacity(0.96)
              : theme.colorScheme.scrim.withOpacity(0.88),
          padding: EdgeInsets.fromLTRB(
            widget.isRound ? 16 : 8,
            widget.isRound ? 24 : 10,
            widget.isRound ? 16 : 8,
            widget.isRound ? 16 : 8,
          ),
          child: Column(
            children: [
              Text(
                l10n.chatHistory,
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              // Search input
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF141414)
                      : theme.colorScheme.surface.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2C2C2C)
                        : accent.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 13,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _historySearchController,
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: l10n.searchHistory,
                          hintStyle: TextStyle(
                            fontSize: 9,
                            color: theme.colorScheme.onSurface.withOpacity(0.45),
                          ),
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (_historySearchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(() => _historySearchController.clear()),
                        child: Icon(
                          Icons.close_rounded,
                          size: 13,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: sessions.isEmpty
                    ? Center(
                        child: Text(
                          l10n.noHistory,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 11,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: sessions.length,
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          final isActive =
                              session.id == historyService.currentSessionId;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? accent.withOpacity(0.2)
                                    : isDark
                                        ? const Color(0xFF141414)
                                        : theme.colorScheme.surface.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isActive
                                      ? accent.withOpacity(0.55)
                                      : isDark
                                          ? const Color(0xFF242424)
                                          : theme.colorScheme.outline.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => _loadChatSession(session),
                                      child: Text(
                                        session.title,
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface,
                                          fontSize: 10,
                                          fontWeight: isActive
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () async {
                                      await historyService.deleteSession(session.id);
                                    },
                                    child: Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.redAccent.shade100,
                                      size: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => setState(() => _showHistory = false),
                child: Text(
                  l10n.close.toUpperCase(),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
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
