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

  String get thinkingMode =>
      _t(en: 'Thinking Mode', uk: 'Режим мислення', sk: 'Režim premýšľania');

  String get thinkingOff =>
      _t(en: 'Off', uk: 'Вимкнено', sk: 'Vypnuté');
  String get thinkingLow =>
      _t(en: 'Low', uk: 'Швидкий', sk: 'Nízky');
  String get thinkingMedium =>
      _t(en: 'Medium', uk: 'Збалансований', sk: 'Stredný');
  String get thinkingHigh =>
      _t(en: 'High', uk: 'Глибокий', sk: 'Hlboký');

  String get darkMode =>
      _t(en: 'Dark Mode', uk: 'Темна тема', sk: 'Tmavy rezim');

  String get language => _t(en: 'Language', uk: 'Мова', sk: 'Jazyk');

  String get back => _t(en: 'Back', uk: 'Назад', sk: 'Späť');

  String get chatHistory =>
      _t(en: 'CHAT HISTORY', uk: 'ІСТОРІЯ ЧАТУ', sk: 'HISTÓRIA CHATU');

  String get noHistory =>
      _t(en: 'No History', uk: 'Історія порожня', sk: 'Bez histórie');

  String get searchHistory =>
      _t(en: 'Search chats...', uk: 'Пошук чатів...', sk: 'Hľadať chaty...');

  String get deleteChat =>
      _t(en: 'Delete', uk: 'Видалити', sk: 'Vymazať');

  String get close => _t(en: 'Close', uk: 'Закрити', sk: 'Zavrieť');

  String get stop => _t(en: 'Stop', uk: 'Стоп', sk: 'Stop');

  String get stopRecording =>
      _t(en: 'Stop & Send', uk: 'Стоп і відправити', sk: 'Stop a odoslať');

  String get stopGeneration =>
      _t(en: 'Stop generation', uk: 'Зупинити генерацію', sk: 'Zastaviť generovanie');

  String get newChat => _t(
    en: 'New chat',
    uk: 'Новий чат',
    sk: 'Nový chat',
  );

  String get micPermissionRequired => _t(
    en: 'Microphone permission required',
    uk: 'Потрібен доступ до мікрофона',
    sk: 'Povolenie mikrofónu je potrebné',
  );

  String get listening =>
      _t(en: 'Listening...', uk: 'Слухаю...', sk: 'Počúvam...');

  String get transcribing =>
      _t(en: 'Processing...', uk: 'Розпізнавання...', sk: 'Spracovanie...');

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
    uk: 'Введіть повідомлення...',
    sk: 'Napíšte správu...',
  );

  String get devicePromptHint => _t(
    en: 'Type app to open...',
    uk: 'Введіть додаток...',
    sk: 'Napíšte aplikáciu...',
  );

  String get send => _t(en: 'Send', uk: 'Надіслати', sk: 'Odoslať');

  String get open => _t(en: 'Open', uk: 'Відкрити', sk: 'Otvoriť');

  String get deviceControl => _t(
    en: 'Device control',
    uk: 'Керування пристроєм',
    sk: 'Ovládanie zariadenia',
  );

  String get chatInput =>
      _t(en: 'Prompt input', uk: 'Панель вводу', sk: 'Vstup promptu');

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
    uk: 'Натисни мікрофон',
    sk: 'Klepni na mikrofón',
  );

  String thinkingForSeconds(int seconds) => _t(
    en: 'Thinking: ${seconds}s',
    uk: 'Мислення: $secondsс',
    sk: 'Premýšľanie: ${seconds}s',
  );

  String get superVoiceMode => _t(
    en: 'Super Voice Mode',
    uk: 'Супер Голосовий Режим',
    sk: 'Super Hlasový Režim',
  );

  String get setDefaultAssistant => _t(
    en: 'Set OleksandrAI as assistant',
    uk: 'Встановити як асистента за замовчуванням',
    sk: 'Nastaviť ako predvoleného asistenta',
  );

  String get assistantSettingsOpened => _t(
    en: 'Assistant settings opened',
    uk: 'Налаштування асистента відкрито',
    sk: 'Nastavenia asistenta otvorené',
  );

  String get assistantSettingsUnavailable => _t(
    en: 'Assistant settings unavailable',
    uk: 'Налаштування асистента недоступні',
    sk: 'Nastavenia asistenta nedostupné',
  );

  String get voiceSessionTitle =>
      _t(en: 'Voice chat', uk: 'Голосовий чат', sk: 'Hlasový chat');

  String get subtitlesPlaceholder => _t(
    en: 'Subtitles will appear here',
    uk: 'Тут зʼявляться субтитри',
    sk: 'Titulky sa zobrazia tu',
  );

  String get youLabel => _t(en: 'You', uk: 'Ви', sk: 'Vy');

  String get aiLabel => _t(en: 'AI', uk: 'AI', sk: 'AI');

  String get voiceOn => _t(en: 'VOICE ON', uk: 'ГОЛОС ON', sk: 'HLAS ON');

  String get voiceOff => _t(en: 'VOICE OFF', uk: 'ГОЛОС OFF', sk: 'HLAS OFF');
}
