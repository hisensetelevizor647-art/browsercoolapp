import 'package:ai_watch/screens/home_screen.dart';
import 'package:ai_watch/services/chat_history_service.dart';
import 'package:ai_watch/services/gemini_service.dart';
import 'package:ai_watch/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Shows idle assistant prompt on home screen', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final settingsService = SettingsService();
    await settingsService.init();

    final chatHistoryService = ChatHistoryService();
    await chatHistoryService.init();

    final geminiService = GeminiService()
      ..init(settingsService.model, settingsService.language);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settingsService),
          ChangeNotifierProvider.value(value: chatHistoryService),
          ChangeNotifierProvider.value(value: geminiService),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.pump();
    expect(find.text('Tap to speak'), findsOneWidget);
  });
}
