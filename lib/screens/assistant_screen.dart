import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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
  static const String _assistantModel = 'gemini-3.1-flash-lite-preview';
  static const String _idleHint = 'Tap mic to talk';
  static final _accentColor = Colors.blueAccent.shade400;

  final stt.SpeechToText _speech = stt.SpeechToText();
  final TtsService _ttsService = TtsService();

  late final AnimationController _orbitController;
  late final GenerativeModel _assistantModelClient;

  bool _isListening = false;
  bool _subtitlesEnabled = false;

  String _spokenText = '';
  String _replyText = _idleHint;

  @override
  void initState() {
    super.initState();
    _assistantModelClient = GenerativeModel(
      model: _assistantModel,
      apiKey: GeminiService.apiKey,
    );
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ttsService.init();
      if (!mounted) return;
      final settings = Provider.of<SettingsService>(context, listen: false);
      await _ttsService.setLanguageCode(settings.language);
    });
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _speech.stop();
    _ttsService.stop();
    super.dispose();
  }

  Future<void> _startListening() async {
    final micStatus = await Permission.microphone.request();
    if (micStatus != PermissionStatus.granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission required')),
      );
      return;
    }

    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'notListening' && _isListening) {
          setState(() {
            _isListening = false;
          });
          _askAssistant(_spokenText);
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
      _replyText = 'Listening...';
    });

    _speech.listen(
      onResult: (value) {
        if (!mounted) return;
        setState(() {
          _spokenText = value.recognizedWords;
        });
      },
    );
  }

  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListening = false;
    });
    _askAssistant(_spokenText);
  }

  Future<void> _askAssistant(String prompt) async {
    final settings = Provider.of<SettingsService>(context, listen: false);
    final languageCode = settings.language;
    final cleanPrompt = TextCleaner.clean(
      prompt,
      disallowCjk: languageCode != 'zh',
    );
    if (cleanPrompt.isEmpty) {
      if (!mounted) return;
      setState(() {
        _replyText = _idleHint;
      });
      return;
    }

    setState(() {
      _replyText = 'Thinking...';
    });

    try {
      final response = await _assistantModelClient.generateContent([
        Content.text(GeminiService.buildLanguageInstruction(languageCode)),
        Content.text(cleanPrompt),
      ]);
      final answer = TextCleaner.clean(
        response.text ?? '',
        disallowCjk: languageCode != 'zh',
      );
      final finalAnswer = answer.isEmpty ? 'No response' : answer;

      if (_subtitlesEnabled) {
        await _ttsService.stop();
      } else {
        await _ttsService.setLanguageCode(languageCode);
        await _ttsService.speak(finalAnswer);
      }

      if (!mounted) return;
      setState(() {
        _replyText = finalAnswer;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _replyText = 'Error while generating reply';
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
    final modelName = Provider.of<SettingsService>(
      context,
      listen: false,
    ).modelDisplayName.toUpperCase();
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            widget.isRound ? 20 : 12,
            widget.isRound ? 18 : 12,
            widget.isRound ? 20 : 12,
            widget.isRound ? 18 : 12,
          ),
          child: Column(
            children: [
              // Top Model Name
              Text(
                modelName,
                style: TextStyle(
                  color: _accentColor.withOpacity(0.7),
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),

              // Animated Logo with Orbiting Dots
              _buildAnimatedLogo(),

              const SizedBox(height: 12),

              // Content / Status area
              Container(
                constraints: const BoxConstraints(minHeight: 50, maxHeight: 80),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 0.5,
                  ),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _subtitlesEnabled
                        ? _replyText
                        : (_isListening ? _spokenText : _replyText),
                    style: TextStyle(
                      fontSize: 11,
                      color: _isListening ? Colors.redAccent : Colors.white70,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Bottom Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Subtitles / Voice Toggle
                  _buildSideButton(
                    onPressed: _toggleReplyMode,
                    icon: _subtitlesEnabled
                        ? Icons.subtitles_rounded
                        : Icons.volume_up_rounded,
                    color: _subtitlesEnabled ? Colors.amber : _accentColor,
                  ),
                  const SizedBox(width: 12),
                  // Centered Mic Button
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: FloatingActionButton(
                      elevation: 4,
                      onPressed: _isListening
                          ? _stopListening
                          : _startListening,
                      backgroundColor: _isListening ? Colors.red : _accentColor,
                      shape: const CircleBorder(),
                      child: Icon(
                        _isListening
                            ? Icons.mic_off_rounded
                            : Icons.mic_rounded,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Close Assistant / Go Home
                  _buildSideButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icons.close_rounded,
                    color: Colors.grey,
                  ),
                ],
              ),
            ],
          ),
        ),
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
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: color),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return SizedBox(
      width: 140,
      height: 140,
      child: AnimatedBuilder(
        animation: _orbitController,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Orbiting circles (Voice visualization)
              _buildOrbitDot(0, 48, 8),
              _buildOrbitDot(1, 56, 10),
              _buildOrbitDot(2, 64, 7),

              // Pulse effect when listening
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

              // Central App Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: _accentColor.withOpacity(0.3),
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
    final speed = 1.0 + (index * 0.2); // Different speeds for each dot
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
          color: _isListening ? Colors.redAccent : _accentColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (_isListening ? Colors.red : _accentColor).withOpacity(
                0.5,
              ),
              blurRadius: 10,
            ),
          ],
        ),
      ),
    );
  }
}
