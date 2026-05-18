import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/app_localizer.dart';
import '../services/gemini_service.dart';
import '../services/settings_service.dart';
import '../services/text_cleaner.dart';
import '../services/tts_service.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key, this.isRound = false});

  final bool isRound;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TtsService _ttsService = TtsService();
  final TextEditingController _promptController = TextEditingController();
  final FocusNode _promptFocusNode = FocusNode();

  late final AnimationController _orbitController;

  bool _isListening = false;
  bool _subtitlesEnabled = false;
  String _spokenText = '';
  String _replyText = '';

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
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ttsService.init();
      if (!mounted) return;
      final settings = Provider.of<SettingsService>(context, listen: false);
      await _ttsService.setLanguageCode(settings.language);
      setState(() {
        _replyText = _l10n().idleAssistantHint;
      });
    });
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _speech.stop();
    _ttsService.stop();
    _promptController.dispose();
    _promptFocusNode.dispose();
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
        });
      },
    );

    if (!available) return;

    setState(() {
      _isListening = true;
      _spokenText = '';
      _promptController.clear();
      _replyText = l10n.listening;
    });

    _speech.listen(
      onResult: (value) {
        if (!mounted) return;
        setState(() {
          _spokenText = value.recognizedWords;
          _promptController.text = value.recognizedWords;
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
    final prompt = TextCleaner.clean(_promptController.text);
    if (prompt.isNotEmpty) {
      await _askAssistant(prompt);
    }
  }

  Future<void> _submitTypedPrompt() async {
    final prompt = TextCleaner.clean(_promptController.text);
    if (prompt.isEmpty) return;
    await _askAssistant(prompt);
  }

  Future<void> _askAssistant(String prompt) async {
    final l10n = _l10n();
    final settings = Provider.of<SettingsService>(context, listen: false);
    final service = Provider.of<GeminiService>(context, listen: false);
    final cleanPrompt = TextCleaner.clean(prompt);
    if (cleanPrompt.isEmpty) {
      if (!mounted) return;
      setState(() {
        _replyText = l10n.idleAssistantHint;
      });
      return;
    }

    setState(() {
      _replyText = l10n.thinking;
    });

    try {
      final response = await service.askSingleMessage(
        cleanPrompt,
        modelName: settings.model,
      );
      final answer = TextCleaner.clean(response);
      final finalAnswer = answer.isEmpty ? l10n.noResponse : answer;

      if (_subtitlesEnabled) {
        await _ttsService.stop();
      } else {
        await _ttsService.setLanguageCode(settings.language);
        await _ttsService.speak(finalAnswer);
      }

      if (!mounted) return;
      setState(() {
        _promptController.clear();
        _replyText = finalAnswer;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _replyText = l10n.replyError;
      });
    }
  }

  void _toggleReplyMode() {
    setState(() {
      _subtitlesEnabled = !_subtitlesEnabled;
    });
    if (_subtitlesEnabled) {
      _ttsService.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gemini = Provider.of<GeminiService>(context);
    final settings = Provider.of<SettingsService>(context, listen: false);
    final modelName = settings.modelDisplayName.toUpperCase();
    final l10n = AppLocalizer.fromCode(settings.language);
    final onSurface = theme.colorScheme.onSurface;
    final accent = _accentColor(theme);
    final isThinking = gemini.isLoading;
    final thinkingPulse =
        0.55 + (math.sin(_orbitController.value * 2 * math.pi).abs() * 0.45);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          _buildBackdrop(theme),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                widget.isRound ? 20 : 12,
                widget.isRound ? 18 : 12,
                widget.isRound ? 20 : 12,
                widget.isRound ? 18 : 12,
              ),
              child: Column(
                children: [
                  Text(
                    modelName,
                    style: TextStyle(
                      color: accent.withOpacity(0.84),
                      fontSize: 11,
                      letterSpacing: 1.3,
                    ),
                  ),
                  if (isThinking) ...[
                    const SizedBox(height: 7),
                    Opacity(
                      opacity: thinkingPulse,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withOpacity(0.86),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: accent.withOpacity(0.45),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          l10n.thinkingForSeconds(gemini.thinkingSeconds),
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface.withOpacity(
                              0.86,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  _buildAnimatedLogo(),
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(
                      minHeight: 50,
                      maxHeight: 80,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.surface.withOpacity(0.94),
                          theme.colorScheme.surfaceContainerHighest.withOpacity(
                            0.36,
                          ),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.26),
                        width: 0.6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadowColor.withOpacity(0.14),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        _subtitlesEnabled
                            ? _replyText
                            : (_isListening ? _spokenText : _replyText),
                        style: TextStyle(
                          fontSize: 11,
                          color: _isListening
                              ? Colors.redAccent
                              : onSurface.withOpacity(0.88),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPromptInput(theme, l10n),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSideButton(
                        onPressed: _toggleReplyMode,
                        icon: _subtitlesEnabled
                            ? Icons.subtitles_rounded
                            : Icons.volume_up_rounded,
                        color: _subtitlesEnabled ? Colors.amber : accent,
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: FloatingActionButton(
                          elevation: 4,
                          onPressed: _isListening
                              ? _stopListening
                              : _startListening,
                          backgroundColor: _isListening ? Colors.red : accent,
                          shape: const CircleBorder(),
                          child: Icon(
                            _isListening
                                ? Icons.mic_off_rounded
                                : Icons.mic_rounded,
                            size: 28,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildSideButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icons.close_rounded,
                        color: onSurface.withOpacity(0.72),
                      ),
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
              top: -84,
              left: -42,
              child: _buildGlow(accent.withOpacity(isDark ? 0.26 : 0.18), 190),
            ),
            Positioned(
              bottom: -88,
              right: -48,
              child: _buildGlow(
                accentAlt.withOpacity(isDark ? 0.24 : 0.14),
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
            BoxShadow(color: color, blurRadius: size * 0.36, spreadRadius: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptInput(ThemeData theme, AppLocalizer l10n) {
    final accent = _accentColor(theme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface.withOpacity(0.95),
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.38),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.26)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _promptController,
              focusNode: _promptFocusNode,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.chatPromptHint,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submitTypedPrompt(),
            ),
          ),
          SizedBox(
            width: 30,
            height: 30,
            child: FloatingActionButton(
              heroTag: 'assistant_send',
              mini: true,
              backgroundColor: accent,
              onPressed: _submitTypedPrompt,
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

  Widget _buildSideButton({
    required void Function() onPressed,
    required IconData icon,
    required dynamic color,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.18), color.withOpacity(0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.12), blurRadius: 8)],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: color),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    final theme = Theme.of(context);
    final accent = _accentColor(theme);
    return SizedBox(
      width: 140,
      height: 140,
      child: AnimatedBuilder(
        animation: _orbitController,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              _buildOrbitDot(0, 48, 8),
              _buildOrbitDot(1, 56, 10),
              _buildOrbitDot(2, 64, 7),
              if (_isListening)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1.0, end: 1.3),
                  duration: const Duration(milliseconds: 600),
                  builder: (context, value, child) {
                    return Container(
                      width: 80 * value,
                      height: 80 * value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.red.shade400.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                    );
                  },
                ),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.35),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrbitDot(int index, double radius, double size) {
    final theme = Theme.of(context);
    final accent = _accentColor(theme);
    final speed = 1.0 + (index * 0.2);
    final angleOffset = (2 * math.pi / 3) * index;
    final angle = (_orbitController.value * 2 * math.pi * speed) + angleOffset;
    final dx = math.cos(angle) * radius;
    final dy = math.sin(angle) * radius;
    final center = 70.0;

    return Positioned(
      left: center + dx - (size / 2),
      top: center + dy - (size / 2),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _isListening ? Colors.redAccent : accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (_isListening ? Colors.red : accent).withOpacity(0.5),
              blurRadius: 10,
            ),
          ],
        ),
      ),
    );
  }
}
