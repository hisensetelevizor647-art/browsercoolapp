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
      _t(en: 'Tap to speak', uk: 'Natysni dlia holosu', sk: 'Klepni pre hlas');

  String get tapToWake => _t(
    en: 'Tap to wake',
    uk: 'Natysni shchob uvimknuty',
    sk: 'Klepni na zobudenie',
  );

  String get settings =>
      _t(en: 'Settings', uk: 'Nalashtuvannia', sk: 'Nastavenia');

  String get aiModel => _t(en: 'AI Model', uk: 'Model AI', sk: 'AI model');

  String get darkMode =>
      _t(en: 'Dark Mode', uk: 'Temna tema', sk: 'Tmavy rezim');

  String get language => _t(en: 'Language', uk: 'Mova', sk: 'Jazyk');

  String get back => _t(en: 'Back', uk: 'Nazad', sk: 'Spat');

  String get chatHistory =>
      _t(en: 'CHAT HISTORY', uk: 'ISTORIYA CHATU', sk: 'HISTORIA CHATU');

  String get noHistory =>
      _t(en: 'No History', uk: 'Istoriya porozhnia', sk: 'Bez historie');

  String get close => _t(en: 'Close', uk: 'Zakryty', sk: 'Zavriet');

  String get newChat => _t(
    en: 'New chat started',
    uk: 'Novyi chat stvoreno',
    sk: 'Novy chat vytvoreny',
  );

  String get micPermissionRequired => _t(
    en: 'Microphone permission required',
    uk: 'Potreben dostup do mikrofona',
    sk: 'Povolenie mikrofonu je potrebne',
  );

  String get listening =>
      _t(en: 'Listening...', uk: 'Slukhayu...', sk: 'Pocuvam...');

  String get thinking =>
      _t(en: 'Thinking...', uk: 'Dumayu...', sk: 'Premyslam...');

  String get noResponse =>
      _t(en: 'No response', uk: 'Bez vidpovidi', sk: 'Bez odpovede');

  String get replyError => _t(
    en: 'Error while generating reply',
    uk: 'Pomylka pid chas vidpovidi',
    sk: 'Chyba pri generovani odpovede',
  );

  String get chatPromptHint => _t(
    en: 'Type message...',
    uk: 'Vvedy povidomlennia...',
    sk: 'Napis spravu...',
  );

  String get devicePromptHint => _t(
    en: 'Type app to open...',
    uk: 'Vvedy nazvu dodatku...',
    sk: 'Napis aplikaciu na otvorenie...',
  );

  String get send => _t(en: 'Send', uk: 'Nadislaty', sk: 'Odoslat');

  String get open => _t(en: 'Open', uk: 'Vidkryty', sk: 'Otvorit');

  String get deviceControl => _t(
    en: 'Device control',
    uk: 'Keruvannia pryistroyem',
    sk: 'Ovladanie zariadenia',
  );

  String get chatInput =>
      _t(en: 'Chat input', uk: 'Vvedennia chatu', sk: 'Vstup chatu');

  String appOpened(String appName) => _t(
    en: 'Opened: $appName',
    uk: 'Vidkryto: $appName',
    sk: 'Otvorene: $appName',
  );

  String appNotFound(String prompt) => _t(
    en: 'App not found: $prompt',
    uk: 'Dodatok ne znaideno: $prompt',
    sk: 'Aplikacia sa nenasla: $prompt',
  );

  String appOpenFailed(String appName) => _t(
    en: 'Failed to open: $appName',
    uk: 'Ne vdalosya vidkryty: $appName',
    sk: 'Nepodarilo sa otvorit: $appName',
  );

  String get idleAssistantHint => _t(
    en: 'Tap mic to talk',
    uk: 'Natysni mikrophon shchob hovoryty',
    sk: 'Klepni na mikrofon a hovor',
  );
}
