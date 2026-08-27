import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wear/wear.dart';
import 'services/gemini_service.dart';
import 'services/settings_service.dart';
import 'services/chat_history_service.dart';
import 'services/app_localizer.dart';
import 'screens/assistant_screen.dart';
import 'screens/home_screen.dart';
import 'theme/watch_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ${details.exception}');
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Error loading screen\n${details.exception}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent, fontSize: 10),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  };

  final settingsService = SettingsService();
  try {
    await settingsService.init();
  } catch (e) {
    debugPrint('Failed to init settings: $e');
  }

  final chatHistoryService = ChatHistoryService();
  try {
    await chatHistoryService.init();
  } catch (e) {
    debugPrint('Failed to init chat history: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsService),
        ChangeNotifierProvider.value(value: chatHistoryService),
        ChangeNotifierProvider(
          create: (_) =>
              GeminiService()
                ..init(
                  settingsService.model,
                  settingsService.language,
                  settingsService.thinkingLevel,
                ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settings, child) {
        final defaultRoute =
            WidgetsBinding.instance.platformDispatcher.defaultRouteName;
        final initialRoute = switch (defaultRoute) {
          '/start-chat' => '/start-chat',
          '/assistant' => '/assistant',
          '/voice-mode' => '/voice-mode',
          _ => '/',
        };

        return MaterialApp(
          title: 'OleksandrAI Watch',
          debugShowCheckedModeBanner: false,
          color: Colors.black,
          theme: WatchTheme.light(),
          darkTheme: WatchTheme.dark(),
          themeMode: settings.themeMode,
          initialRoute: initialRoute,
          routes: {
            '/': (_) => const WatchScreen(),
            '/start-chat': (_) => const WatchScreen(openKeyboardOnStart: true),
            '/assistant': (_) => const WatchScreen(assistantMode: true),
            '/voice-mode': (_) => const WatchScreen(startInVoiceMode: true),
          },
        );
      },
    );
  }
}

class WatchScreen extends StatelessWidget {
  const WatchScreen({
    super.key,
    this.openKeyboardOnStart = false,
    this.assistantMode = false,
    this.startInVoiceMode = false,
  });

  final bool openKeyboardOnStart;
  final bool assistantMode;
  final bool startInVoiceMode;

  @override
  Widget build(BuildContext context) {
    return WatchShape(
      builder: (BuildContext context, WearShape shape, Widget? child) {
        final isRound = shape == WearShape.round;
        return AmbientMode(
          builder: (context, mode, child) {
            return mode == WearMode.active
                ? assistantMode
                    ? AssistantScreen(isRound: isRound)
                    : HomeScreen(
                        openKeyboardOnStart: openKeyboardOnStart,
                        startInVoiceMode: startInVoiceMode,
                        isRound: isRound,
                      )
                : const AmbientWatchFace();
          },
        );
      },
    );
  }
}

class AmbientWatchFace extends StatelessWidget {
  const AmbientWatchFace({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settings, _) {
        final l10n = AppLocalizer.fromCode(settings.language);
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: WatchTheme.getGradientColors(
                        settings.backgroundTheme,
                        isDark,
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.25),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/icon/app_icon.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.tapToWake,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.68),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
