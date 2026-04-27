class AppLocalizer {
  const AppLocalizer(this.languageCode);

  final String languageCode;

  static const _supported = {'en', 'uk', 'sk'};

  factory AppLocalizer.fromCode(String code) {
    return AppLocalizer(_supported.contains(code) ? code : 'en');
  }

  String _t({required String en, required String uk, required String sk}) {
    return switch (languageCode) {
      'uk' => uk,
      'sk' => sk,
      _ => en,
    };
  }

  String get tapToSpeak =>
      _t(en: 'Tap to speak', uk: 'Натисни для голосу', sk: 'Klepni pre hlas');

  String get tapToWake => _t(
    en: 'Tap to wake',
    uk: 'Натисни, щоб увімкнути',
    sk: 'Klepni na zobudenie',
  );

  String get settings =>
      _t(en: 'Settings', uk: 'Налаштування', sk: 'Nastavenia');

  String get aiModel => _t(en: 'AI Model', uk: 'Модель AI', sk: 'AI model');

  String get darkMode =>
      _t(en: 'Dark Mode', uk: 'Темна тема', sk: 'Tmavy rezim');

  String get language => _t(en: 'Language', uk: 'Мова', sk: 'Jazyk');

  String get back => _t(en: 'Back', uk: 'Назад', sk: 'Späť');

  String get chatHistory =>
      _t(en: 'CHAT HISTORY', uk: 'ІСТОРІЯ ЧАТУ', sk: 'HISTÓRIA CHATU');

  String get noHistory =>
      _t(en: 'No History', uk: 'Історія порожня', sk: 'Bez histórie');

  String get close => _t(en: 'Close', uk: 'Закрити', sk: 'Zavrieť');

  String get newChat => _t(
    en: 'New chat started',
    uk: 'Новий чат створено',
    sk: 'Nový chat vytvorený',
  );

  String get micPermissionRequired => _t(
    en: 'Microphone permission required',
    uk: 'Потрібен доступ до мікрофона',
    sk: 'Povolenie mikrofónu je potrebné',
  );

  String get listening =>
      _t(en: 'Listening...', uk: 'Слухаю...', sk: 'Počúvam...');

  String get thinking =>
      _t(en: 'Thinking...', uk: 'Думаю...', sk: 'Premýšľam...');

  String get noResponse =>
      _t(en: 'No response', uk: 'Немає відповіді', sk: 'Bez odpovede');

  String get replyError => _t(
    en: 'Error while generating reply',
    uk: 'Помилка під час відповіді',
    sk: 'Chyba pri generovaní odpovede',
  );

  String get chatPromptHint => _t(
    en: 'Type message...',
    uk: 'Введи повідомлення...',
    sk: 'Napíš správu...',
  );

  String get devicePromptHint => _t(
    en: 'Type app to open...',
    uk: 'Введи назву додатка...',
    sk: 'Napíš aplikáciu na otvorenie...',
  );

  String get send => _t(en: 'Send', uk: 'Надіслати', sk: 'Odoslať');

  String get open => _t(en: 'Open', uk: 'Відкрити', sk: 'Otvoriť');

  String get deviceControl => _t(
    en: 'Device control',
    uk: 'Керування пристроєм',
    sk: 'Ovládanie zariadenia',
  );

  String get chatInput =>
      _t(en: 'Chat input', uk: 'Введення чату', sk: 'Vstup chatu');

  String appOpened(String appName) => _t(
    en: 'Opened: $appName',
    uk: 'Відкрито: $appName',
    sk: 'Otvorené: $appName',
  );

  String appNotFound(String prompt) => _t(
    en: 'App not found: $prompt',
    uk: 'Додаток не знайдено: $prompt',
    sk: 'Aplikácia sa nenašla: $prompt',
  );

  String appOpenFailed(String appName) => _t(
    en: 'Failed to open: $appName',
    uk: 'Не вдалося відкрити: $appName',
    sk: 'Nepodarilo sa otvoriť: $appName',
  );

  String get idleAssistantHint => _t(
    en: 'Tap mic to talk',
    uk: 'Натисни мікрофон, щоб говорити',
    sk: 'Klepni na mikrofón a hovor',
  );
}
