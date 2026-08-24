import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/app_localizer.dart';
import '../services/chat_history_service.dart';
import '../services/gemini_service.dart';
import '../services/settings_service.dart';
import '../services/text_cleaner.dart';
import '../services/tts_service.dart';
import '../theme/watch_theme.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key, this.isRound = false});

  final bool isRound;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _TranscriptLine {
  const _TranscriptLine({
    required this.label,
    required this.text,
    required this.isUser,
  });

  final String label;
  final String text;
  final bool isUser;
}

class _AssistantScreenState extends State<AssistantScreen>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TtsService _ttsService = TtsService();
  final ScrollController _subtitleController = ScrollController();

  late final AnimationController _ringController;

  bool _isListening = false;
  bool _isSpeakingAnswer = false;
  bool _voiceOutputEnabled = true;
  String _liveHeardText = '';
  String _statusText = '';
  List<_TranscriptLine> _transcriptLines = const [];

  AppLocalizer _l10n() {
    final language = Provider.of<SettingsService>(
      context,
      listen: false,
    ).language;
    return AppLocalizer.fromCode(language);
  }

  dynamic _accentColor(ThemeData theme) => theme.colorScheme.primary;

  dynamic _accentAltColor(ThemeData theme) => theme.colorScheme.secondary;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ttsService.init();
      if (!mounted) return;

      final l10n = _l10n();
      final settings = Provider.of<SettingsService>(context, listen: false);
      await _ttsService.setLanguageCode(settings.language);
      if (!mounted) return;

      final history = Provider.of<ChatHistoryService>(context, listen: false);
      if (history.currentSessionId == null) {
        await history.createNewSession(title: l10n.voiceSessionTitle);
      }
      if (!mounted) return;

      _loadTranscriptFromStorage(history.voiceTranscriptText);
      if (!mounted) return;
      setState(() {
        _statusText = l10n.idleAssistantHint;
      });
    });
  }

  @override
  void dispose() {
    _ringController.dispose();
    _speech.stop();
    _ttsService.stop();
    _subtitleController.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    final l10n = _l10n();
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
        setState(() {
          _isListening = false;
          _statusText = l10n.replyError;
        });
      },
    );

    if (!available || !mounted) {
      return;
    }

    setState(() {
      _isListening = true;
      _liveHeardText = '';
      _statusText = l10n.listening;
    });

    _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        onDevice: true,
        partialResults: true,
      ),
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _liveHeardText = TextCleaner.clean(result.recognizedWords);
        });
      },
    );
  }

  Future<void> _stopListening() async {
    if (!_isListening) return;
    await _speech.stop();
    if (!mounted) return;

    setState(() {
      _isListening = false;
    });

    final prompt = TextCleaner.clean(_liveHeardText);
    if (prompt.isEmpty) {
      setState(() {
        _statusText = _l10n().idleAssistantHint;
      });
      return;
    }

    await _askAssistant(prompt);
  }

  Future<void> _askAssistant(String prompt) async {
    final l10n = _l10n();
    final settings = Provider.of<SettingsService>(context, listen: false);
    final service = Provider.of<GeminiService>(context, listen: false);
    final history = Provider.of<ChatHistoryService>(context, listen: false);
    final cleanPrompt = TextCleaner.clean(prompt);
    if (cleanPrompt.isEmpty) {
      if (!mounted) return;
      setState(() {
        _statusText = l10n.idleAssistantHint;
      });
      return;
    }

    await history.addMessageToCurrentSession('user', cleanPrompt);
    await history.appendVoiceTranscript(role: 'USER', content: cleanPrompt);
    _appendTranscriptLine(
      _TranscriptLine(label: l10n.youLabel, text: cleanPrompt, isUser: true),
    );

    if (!mounted) return;
    setState(() {
      _statusText = l10n.thinking;
      _liveHeardText = cleanPrompt;
    });

    final response = await service.sendMessage(cleanPrompt);
    final answer = TextCleaner.clean(response ?? '');
    final hasError = answer.startsWith('Error:');
    final finalAnswer = hasError
        ? l10n.replyError
        : (answer.isEmpty ? l10n.noResponse : answer);

    await history.addMessageToCurrentSession('model', finalAnswer);
    await history.appendVoiceTranscript(
      role: 'ASSISTANT',
      content: finalAnswer,
    );
    if (mounted) {
      _appendTranscriptLine(
        _TranscriptLine(label: l10n.aiLabel, text: finalAnswer, isUser: false),
      );
    }

    if (_voiceOutputEnabled && !hasError) {
      if (mounted) {
        setState(() {
          _isSpeakingAnswer = true;
          _statusText = finalAnswer;
        });
      }
      await _ttsService.setLanguageCode(settings.language);
      await _ttsService.speak(finalAnswer);
      if (mounted) {
        setState(() {
          _isSpeakingAnswer = false;
        });
      }
    }

    if (!mounted) return;
    setState(() {
      _statusText = hasError ? l10n.replyError : l10n.idleAssistantHint;
    });
  }

  Future<void> _toggleVoiceOutput() async {
    setState(() {
      _voiceOutputEnabled = !_voiceOutputEnabled;
    });
    if (!_voiceOutputEnabled) {
      await _ttsService.stop();
      if (!mounted) return;
      setState(() {
        _isSpeakingAnswer = false;
      });
    }
  }

  void _appendTranscriptLine(_TranscriptLine line) {
    if (!mounted) return;
    final next = List<_TranscriptLine>.from(_transcriptLines)..add(line);
    final trimmed = next.length > 80 ? next.sublist(next.length - 80) : next;
    setState(() {
      _transcriptLines = trimmed;
    });
    _scrollSubtitlesToBottom();
  }

  void _loadTranscriptFromStorage(String transcriptText) {
    final lines = transcriptText
        .split('\n')
        .map(TextCleaner.clean)
        .where((line) => line.isNotEmpty)
        .toList();

    final parsed = lines.map(_parseTranscriptLine).toList();
    setState(() {
      _transcriptLines = parsed.length > 80
          ? parsed.sublist(parsed.length - 80)
          : parsed;
    });
    _scrollSubtitlesToBottom();
  }

  _TranscriptLine _parseTranscriptLine(String rawLine) {
    final match = RegExp(
      r'^\[[^\]]+\]\s+([A-Z_]+):\s*(.*)$',
    ).firstMatch(rawLine);
    final role = match?.group(1) ?? 'ASSISTANT';
    final text = TextCleaner.clean(match?.group(2) ?? rawLine);
    final isUser = role == 'USER';
    final l10n = _l10n();

    return _TranscriptLine(
      label: isUser ? l10n.youLabel : l10n.aiLabel,
      text: text,
      isUser: isUser,
    );
  }

  void _scrollSubtitlesToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_subtitleController.hasClients) return;
      _subtitleController.animateTo(
        _subtitleController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = Provider.of<SettingsService>(context, listen: false);
    final l10n = AppLocalizer.fromCode(settings.language);
    final gemini = Provider.of<GeminiService>(context);
    final accent = _accentColor(theme);
    final onSurface = theme.colorScheme.onSurface;
    final ringActive = _isListening || _isSpeakingAnswer || gemini.isLoading;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          _buildBackdrop(theme),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                widget.isRound ? 28 : 12,
                widget.isRound ? 28 : 12,
                widget.isRound ? 28 : 12,
                widget.isRound ? 24 : 12,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildTopButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icons.arrow_back,
                      ),
                      const Spacer(),
                      Text(
                        settings.modelDisplayName.toUpperCase(),
                        style: TextStyle(
                          color: accent.withOpacity(0.88),
                          fontSize: 10,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const Spacer(),
                      _buildTopButton(
                        onPressed: () {},
                        icon: Icons.graphic_eq_rounded,
                        isDecorative: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildVoiceLogo(ringActive: ringActive),
                        const SizedBox(height: 10),
                        Text(
                          _statusText.isEmpty
                              ? l10n.idleAssistantHint
                              : _statusText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: _isListening
                                ? Colors.red.shade300
                                : onSurface.withOpacity(0.88),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildSubtitlesCard(theme),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildControlButton(
                        icon: _voiceOutputEnabled
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        label: _voiceOutputEnabled
                            ? l10n.voiceOn
                            : l10n.voiceOff,
                        active: _voiceOutputEnabled,
                        onPressed: _toggleVoiceOutput,
                      ),
                      const SizedBox(width: 14),
                      _buildMicButton(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackdrop(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final accent = _accentColor(theme);
    final accentAlt = _accentAltColor(theme);

    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: WatchTheme.getGradientColors(
              Provider.of<SettingsService>(context, listen: false).backgroundTheme,
              isDark,
            ),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -84,
              left: -40,
              child: _buildGlow(accent.withOpacity(isDark ? 0.24 : 0.16), 190),
            ),
            Positioned(
              bottom: -90,
              right: -44,
              child: _buildGlow(
                accentAlt.withOpacity(isDark ? 0.24 : 0.16),
                220,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlow(dynamic color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color, blurRadius: size * 0.35, spreadRadius: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceLogo({required bool ringActive}) {
    final theme = Theme.of(context);
    final accent = _accentColor(theme);

    return SizedBox(
      width: 146,
      height: 146,
      child: AnimatedBuilder(
        animation: _ringController,
        builder: (context, _) {
          final wave =
              0.78 + math.sin(_ringController.value * 2 * math.pi) * 0.22;
          final secondWave =
              0.74 +
              math.sin((_ringController.value * 2 * math.pi) + 1.3) * 0.2;

          return Stack(
            alignment: Alignment.center,
            children: [
              if (ringActive)
                Container(
                  width: 118 * wave,
                  height: 118 * wave,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (_isListening ? Colors.red.shade400 : accent).withOpacity(
                        0.5,
                      ),
                      width: 2.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening ? Colors.red.shade400 : accent).withOpacity(
                          0.3,
                        ),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              if (ringActive)
                Container(
                  width: 138 * secondWave,
                  height: 138 * secondWave,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (_isListening ? Colors.red.shade400 : accent).withOpacity(
                        0.25,
                      ),
                      width: 1.4,
                    ),
                  ),
                ),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accent.withOpacity(0.28),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.28),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSubtitlesCard(ThemeData theme) {
    final liveLine = _isListening && _liveHeardText.isNotEmpty
        ? _TranscriptLine(
            label: _l10n().youLabel,
            text: _liveHeardText,
            isUser: true,
          )
        : null;
    final items = <_TranscriptLine>[
      ..._transcriptLines,
      ...?(liveLine == null ? null : [liveLine]),
    ];

    return Container(
      height: widget.isRound ? 112 : 128,
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface.withOpacity(0.95),
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.36),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
      ),
      child: items.isEmpty
          ? Center(
              child: Text(
                _l10n().subtitlesPlaceholder,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withOpacity(0.58),
                ),
              ),
            )
          : ListView.builder(
              controller: _subtitleController,
              padding: EdgeInsets.zero,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final line = items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${line.label}: ',
                          style: TextStyle(
                            fontSize: 11,
                            color: line.isUser
                                ? theme.colorScheme.primary
                                : theme.colorScheme.secondary,
                          ),
                        ),
                        TextSpan(
                          text: line.text,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withOpacity(
                              0.88,
                            ),
                          ),
                        ),
                      ],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool active,
    required void Function() onPressed,
  }) {
    final theme = Theme.of(context);
    final accent = _accentColor(theme);
    final color = active
        ? accent
        : theme.colorScheme.onSurface.withOpacity(0.68);

    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withOpacity(0.42)),
          backgroundColor: active
              ? accent.withOpacity(0.14)
              : theme.colorScheme.surface.withOpacity(0.72),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: color),
        label: Text(
          label,
          style: TextStyle(fontSize: 10, color: color, letterSpacing: 0.3),
        ),
      ),
    );
  }

  Widget _buildMicButton() {
    final theme = Theme.of(context);
    final accent = _accentColor(theme);

    return SizedBox(
      width: 58,
      height: 58,
      child: FloatingActionButton(
        elevation: 4,
        onPressed: _isListening ? _stopListening : _startListening,
        backgroundColor: _isListening ? Colors.redAccent : accent,
        shape: const CircleBorder(),
        child: Icon(
          _isListening ? Icons.mic_off_rounded : Icons.mic_rounded,
          size: 28,
          color: theme.colorScheme.onPrimary,
        ),
      ),
    );
  }

  Widget _buildTopButton({
    required void Function() onPressed,
    required IconData icon,
    bool isDecorative = false,
  }) {
    final theme = Theme.of(context);
    final accent = _accentColor(theme);

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surface.withOpacity(0.82),
        border: Border.all(color: accent.withOpacity(0.2)),
      ),
      child: IconButton(
        onPressed: isDecorative ? null : onPressed,
        icon: Icon(
          icon,
          size: 16,
          color: theme.colorScheme.onSurface.withOpacity(0.78),
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
