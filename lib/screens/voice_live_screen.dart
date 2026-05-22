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

class VoiceLiveScreen extends StatefulWidget {
  const VoiceLiveScreen({super.key, this.isRound = false});

  final bool isRound;

  @override
  State<VoiceLiveScreen> createState() => _VoiceLiveScreenState();
}

class _VoiceLiveScreenState extends State<VoiceLiveScreen>
    with TickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TtsService _ttsService = TtsService();
  final ScrollController _subtitleController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();

  late final AnimationController _ringController;
  late final AnimationController _pulseController;
  late final AnimationController _bgController;

  bool _isListening = false;
  bool _isSpeakingAnswer = false;
  bool _voiceOutputEnabled = true;
  bool _micInputEnabled = true;
  bool _showTextInput = false;
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

  @override
  void initState() {
    super.initState();

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
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
      await _startListening();
    });
  }

  @override
  void dispose() {
    _ringController.dispose();
    _pulseController.dispose();
    _bgController.dispose();
    _speech.stop();
    _ttsService.stop();
    _subtitleController.dispose();
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  // ── Speech ──────────────────────────────────────────────

  Future<void> _startListening() async {
    if (!_micInputEnabled || _isListening) return;

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

    if (!available || !mounted) return;

    setState(() {
      _isListening = true;
      _liveHeardText = '';
      _statusText = l10n.listening;
      _showTextInput = false;
    });

    _speech.listen(
      listenMode: stt.ListenMode.dictation,
      onDevice: true,
      listenOptions: stt.SpeechListenOptions(partialResults: true),
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
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
    await _speech.stop();
    if (!mounted) return;

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

  Future<void> _toggleMicInput() async {
    final nextEnabled = !_micInputEnabled;
    if (!nextEnabled && _isListening) {
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
      await _speech.stop();
    }
    if (!mounted) return;

    final l10n = _l10n();
    setState(() {
      _micInputEnabled = nextEnabled;
      if (!nextEnabled) {
        _isListening = false;
        _liveHeardText = '';
      }
      _statusText = l10n.idleAssistantHint;
    });
  }

  Future<void> _exitLiveMode() async {
    if (_isListening) {
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
      await _speech.stop();
    }
    await _ttsService.stop();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _sendTextMessage() async {
    final text = TextCleaner.clean(_textController.text);
    if (text.isEmpty) return;
    _textController.clear();
    _textFocusNode.unfocus();
    setState(() {
      _showTextInput = false;
    });
    await _askAssistant(text);
  }

  // ── Transcript helpers ──────────────────────────────────

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

  // ── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = Provider.of<SettingsService>(context, listen: false);
    final l10n = AppLocalizer.fromCode(settings.language);
    final gemini = Provider.of<GeminiService>(context);
    final ringActive = _isListening || _isSpeakingAnswer || gemini.isLoading;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildAnimatedBackground(theme, settings),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                widget.isRound ? 24 : 10,
                widget.isRound ? 22 : 8,
                widget.isRound ? 24 : 10,
                widget.isRound ? 18 : 8,
              ),
              child: Column(
                children: [
                  // ── Top bar ──
                  _buildTopBar(theme, settings),
                  const SizedBox(height: 2),
                  // ── Center: logo + status ──
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildAnimatedLogo(theme, ringActive),
                        const SizedBox(height: 8),
                        _buildStatusText(theme, l10n),
                      ],
                    ),
                  ),
                  // ── Transcript ──
                  _buildTranscriptCard(theme),
                  const SizedBox(height: 6),
                  // ── Text input (conditionally) ──
                  if (_showTextInput) ...[
                    _buildTextInputPanel(theme, l10n),
                    const SizedBox(height: 6),
                  ],
                  // ── Bottom controls ──
                  _buildBottomControls(theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Animated Background ─────────────────────────────────

  Widget _buildAnimatedBackground(ThemeData theme, SettingsService settings) {
    final accent = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;

    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, _) {
        final angle = _bgController.value * 2 * math.pi;
        return Stack(
          children: [
            // Base gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: WatchTheme.getGradientColors(
                      settings.backgroundTheme,
                      true, // always dark-ish for live mode
                    ),
                  ),
                ),
              ),
            ),
            // Rotating glow 1
            Positioned(
              top: -70,
              left: -30,
              child: Transform.rotate(
                angle: angle,
                child: _buildGlow(accent.withOpacity(0.18), 160),
              ),
            ),
            // Rotating glow 2
            Positioned(
              bottom: -80,
              right: -40,
              child: Transform.rotate(
                angle: -angle * 0.7,
                child: _buildGlow(secondary.withOpacity(0.14), 200),
              ),
            ),
            // Pulsing center glow (reacts to state)
            if (_isListening || _isSpeakingAnswer)
              Center(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    final pulse = 0.08 + _pulseController.value * 0.12;
                    return Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (_isListening ? Colors.red : accent).withOpacity(
                          pulse,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildGlow(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color, blurRadius: size * 0.4, spreadRadius: 6),
          ],
        ),
      ),
    );
  }

  // ── Top Bar ─────────────────────────────────────────────

  Widget _buildTopBar(ThemeData theme, SettingsService settings) {
    final accent = theme.colorScheme.primary;
    final indicatorColor = !_micInputEnabled
        ? theme.colorScheme.onSurface.withOpacity(0.45)
        : (_isListening
              ? Colors.redAccent
              : (_isSpeakingAnswer ? Colors.greenAccent : accent));
    return Row(
      children: [
        // Live indicator dot
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: indicatorColor,
            boxShadow: [
              BoxShadow(color: indicatorColor.withOpacity(0.6), blurRadius: 6),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'LIVE',
          style: TextStyle(
            color: accent.withOpacity(0.9),
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
        ),
        const Spacer(),
        Text(
          settings.modelDisplayName.toUpperCase(),
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
            fontSize: 8,
            letterSpacing: 1.0,
          ),
        ),
        const Spacer(),
        // Equalizer icon
        Icon(Icons.equalizer_rounded, size: 14, color: accent.withOpacity(0.5)),
      ],
    );
  }

  // ── Animated Logo with Rings ────────────────────────────

  Widget _buildAnimatedLogo(ThemeData theme, bool ringActive) {
    final accent = theme.colorScheme.primary;
    final ringColor = _isListening ? Colors.red : accent;

    return SizedBox(
      width: 160,
      height: 160,
      child: AnimatedBuilder(
        animation: _ringController,
        builder: (context, _) {
          final t = _ringController.value * 2 * math.pi;
          final wave1 = 0.78 + math.sin(t) * 0.22;
          final wave2 = 0.74 + math.sin(t + 1.3) * 0.20;
          final wave3 = 0.70 + math.sin(t + 2.6) * 0.18;

          return Stack(
            alignment: Alignment.center,
            children: [
              // ── Ring 3 (outermost, very subtle) ──
              if (ringActive)
                Container(
                  width: 156 * wave3,
                  height: 156 * wave3,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ringColor.withOpacity(0.12),
                      width: 0.8,
                    ),
                  ),
                ),
              // ── Ring 2 ──
              if (ringActive)
                Container(
                  width: 140 * wave2,
                  height: 140 * wave2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ringColor.withOpacity(0.25),
                      width: 1.6,
                    ),
                  ),
                ),
              // ── Ring 1 (inner, strongest) ──
              if (ringActive)
                Container(
                  width: 118 * wave1,
                  height: 118 * wave1,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ringColor.withOpacity(0.45),
                      width: 2.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: ringColor.withOpacity(0.25),
                        blurRadius: 20,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
              // ── Idle subtle ring ──
              if (!ringActive)
                Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accent.withOpacity(0.15),
                      width: 1.0,
                    ),
                  ),
                ),
              // ── Logo circle ──
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: ringActive
                        ? ringColor.withOpacity(0.5)
                        : accent.withOpacity(0.2),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (ringActive ? ringColor : accent).withOpacity(
                        ringActive ? 0.35 : 0.15,
                      ),
                      blurRadius: ringActive ? 22 : 10,
                      spreadRadius: ringActive ? 3 : 1,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      fit: BoxFit.cover,
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

  // ── Status Text ─────────────────────────────────────────

  Widget _buildStatusText(ThemeData theme, AppLocalizer l10n) {
    final onSurface = theme.colorScheme.onSurface;
    final displayText = _statusText.isEmpty
        ? l10n.idleAssistantHint
        : _statusText;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        displayText,
        key: ValueKey(displayText),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          color: _isListening
              ? Colors.redAccent.shade100
              : (_isSpeakingAnswer
                    ? Colors.greenAccent.shade100
                    : onSurface.withOpacity(0.8)),
          fontWeight: FontWeight.w400,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  // ── Transcript Card ─────────────────────────────────────

  Widget _buildTranscriptCard(ThemeData theme) {
    final l10n = _l10n();
    final liveLine = _isListening && _liveHeardText.isNotEmpty
        ? _TranscriptLine(
            label: l10n.youLabel,
            text: _liveHeardText,
            isUser: true,
          )
        : null;
    final items = <_TranscriptLine>[
      ..._transcriptLines,
      ...?(liveLine == null ? null : [liveLine]),
    ];

    return Container(
      height: widget.isRound ? 82 : 100,
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface.withOpacity(0.12),
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.15)),
      ),
      child: items.isEmpty
          ? Center(
              child: Text(
                l10n.subtitlesPlaceholder,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
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
                  padding: const EdgeInsets.only(bottom: 4),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${line.label}: ',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: line.isUser
                                ? theme.colorScheme.primary.withOpacity(0.9)
                                : Colors.greenAccent.withOpacity(0.9),
                          ),
                        ),
                        TextSpan(
                          text: line.text,
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface.withOpacity(0.8),
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

  // ── Text Input Panel ────────────────────────────────────

  Widget _buildTextInputPanel(ThemeData theme, AppLocalizer l10n) {
    final accent = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _textFocusNode,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.chatPromptHint,
                hintStyle: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withOpacity(0.35),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onSubmitted: (_) => _sendTextMessage(),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 30,
            height: 30,
            child: FloatingActionButton(
              heroTag: 'live_send',
              mini: true,
              elevation: 0,
              onPressed: _sendTextMessage,
              backgroundColor: accent,
              child: Icon(
                Icons.send_rounded,
                size: 14,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Controls ─────────────────────────────────────

  Widget _buildBottomControls(ThemeData theme) {
    final accent = theme.colorScheme.primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Exit button
        _buildControlCircle(
          theme: theme,
          icon: Icons.close_rounded,
          size: 34,
          onPressed: _exitLiveMode,
          color: theme.colorScheme.onSurface.withOpacity(0.6),
          bgOpacity: 0.12,
        ),
        // Voice toggle
        _buildControlCircle(
          theme: theme,
          icon: _voiceOutputEnabled
              ? Icons.volume_up_rounded
              : Icons.volume_off_rounded,
          size: 34,
          onPressed: _toggleVoiceOutput,
          color: _voiceOutputEnabled
              ? accent
              : theme.colorScheme.onSurface.withOpacity(0.5),
          bgOpacity: _voiceOutputEnabled ? 0.18 : 0.12,
        ),
        // MIC button (large, center)
        _buildMicButton(theme),
        // Keyboard / text input toggle
        _buildControlCircle(
          theme: theme,
          icon: _showTextInput
              ? Icons.keyboard_hide_rounded
              : Icons.keyboard_rounded,
          size: 34,
          onPressed: () {
            setState(() {
              _showTextInput = !_showTextInput;
            });
            if (_showTextInput) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _textFocusNode.requestFocus();
              });
            }
          },
          color: _showTextInput
              ? accent
              : theme.colorScheme.onSurface.withOpacity(0.5),
          bgOpacity: _showTextInput ? 0.18 : 0.12,
        ),
        // Mic input toggle
        _buildControlCircle(
          theme: theme,
          icon: _micInputEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
          size: 34,
          onPressed: _toggleMicInput,
          color: _micInputEnabled
              ? accent
              : theme.colorScheme.error.withOpacity(0.92),
          bgOpacity: _micInputEnabled ? 0.12 : 0.2,
        ),
      ],
    );
  }

  Widget _buildControlCircle({
    required ThemeData theme,
    required IconData icon,
    required double size,
    required void Function()? onPressed,
    required Color color,
    double bgOpacity = 0.12,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: Colors.white.withOpacity(bgOpacity),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Center(
            child: Icon(icon, size: size * 0.5, color: color),
          ),
        ),
      ),
    );
  }

  Widget _buildMicButton(ThemeData theme) {
    final accent = theme.colorScheme.primary;
    final micColor = !_micInputEnabled
        ? theme.colorScheme.onSurface.withOpacity(0.35)
        : (_isListening ? Colors.redAccent : accent);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: !_micInputEnabled
                ? []
                : _isListening
                ? [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(
                        0.4 * _pulseController.value,
                      ),
                      blurRadius: 16 * _pulseController.value,
                      spreadRadius: 4 * _pulseController.value,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: accent.withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
          ),
          child: FloatingActionButton(
            heroTag: 'live_mic',
            elevation: 2,
            onPressed: !_micInputEnabled
                ? null
                : (_isListening ? _stopListening : _startListening),
            backgroundColor: micColor,
            shape: const CircleBorder(),
            child: Icon(
              !_micInputEnabled
                  ? Icons.mic_off_rounded
                  : (_isListening ? Icons.mic_off_rounded : Icons.mic_rounded),
              size: 26,
              color: _micInputEnabled
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        );
      },
    );
  }
}
