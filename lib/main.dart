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

  final settingsService = SettingsService();
  await settingsService.init();

  final chatHistoryService = ChatHistoryService();
  await chatHistoryService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsService),
        ChangeNotifierProvider.value(value: chatHistoryService),
        ChangeNotifierProvider(
          create: (_) =>
              GeminiService()
                ..init(settingsService.model, settingsService.language),
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
          _ => '/',
        };

        return MaterialApp(
          title: 'OleksandrAI Watch',
          theme: WatchTheme.light(),
          darkTheme: WatchTheme.dark(),
          themeMode: settings.themeMode,
          initialRoute: initialRoute,
          routes: {
            '/': (_) => const WatchScreen(),
            '/start-chat': (_) => const WatchScreen(openKeyboardOnStart: true),
            '/assistant': (_) => const WatchScreen(assistantMode: true),
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
  });

  final bool openKeyboardOnStart;
  final bool assistantMode;

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
                      colors: [
                        Colors.blue.shade500.withOpacity(isDark ? 0.34 : 0.22),
                        Colors.red.shade500.withOpacity(isDark ? 0.3 : 0.2),
                        Colors.yellow.shade600.withOpacity(
                          isDark ? 0.24 : 0.16,
                        ),
                        Colors.green.shade500.withOpacity(isDark ? 0.3 : 0.2),
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.shade500.withOpacity(0.28),
                            Colors.red.shade500.withOpacity(0.24),
                            Colors.yellow.shade600.withOpacity(0.2),
                            Colors.green.shade500.withOpacity(0.24),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(34),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.25),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Image.asset(
                            'assets/icon/app_icon.png',
                            fit: BoxFit.cover,
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
