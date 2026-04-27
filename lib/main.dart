import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wear/wear.dart';
import 'services/gemini_service.dart';
import 'services/settings_service.dart';
import 'services/chat_history_service.dart';
import 'services/app_localizer.dart';
import 'screens/assistant_screen.dart';
import 'screens/home_screen.dart';

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
          title: 'CA',
          theme: ThemeData(
            brightness: Brightness.light,
            primarySwatch: Colors.blue,
            visualDensity: VisualDensity.compact,
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.grey.shade100,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.blue,
            visualDensity: VisualDensity.compact,
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.grey.shade900,
          ),
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
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.tapToWake,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.65),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
