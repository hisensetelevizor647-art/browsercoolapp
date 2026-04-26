import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:webview_flutter/webview_flutter.dart';

import 'src/ai/ai_service.dart';
import 'src/ai/model_catalog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OlewserApp());
}

class OlewserApp extends StatefulWidget {
  const OlewserApp({super.key});

  @override
  State<OlewserApp> createState() => _OlewserAppState();
}

class _OlewserAppState extends State<OlewserApp> {
  static const String _prefThemeMode = 'theme_mode';
  static const String _prefAccentColor = 'accent_color';
  static const Color _defaultAccent = Color(0xFF2457FF);

  ThemeMode _themeMode = ThemeMode.system;
  Color _accentColor = _defaultAccent;

  @override
  void initState() {
    super.initState();
    _loadUiPreferences();
  }

  Future<void> _loadUiPreferences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String rawTheme = prefs.getString(_prefThemeMode) ?? 'system';
    final int rawColor =
        prefs.getInt(_prefAccentColor) ?? _defaultAccent.toARGB32();
    if (!mounted) {
      return;
    }
    setState(() {
      _themeMode = _themeModeFromString(rawTheme);
      _accentColor = Color(rawColor);
    });
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) {
      return;
    }
    setState(() {
      _themeMode = mode;
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefThemeMode, _themeModeToString(mode));
  }

  Future<void> _setAccentColor(Color color) async {
    if (_accentColor.toARGB32() == color.toARGB32()) {
      return;
    }
    setState(() {
      _accentColor = color;
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefAccentColor, color.toARGB32());
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme lightScheme = ColorScheme.fromSeed(
      seedColor: _accentColor,
    );
    final ColorScheme darkScheme = ColorScheme.fromSeed(
      seedColor: _accentColor,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Olewser',
      themeMode: _themeMode,
      theme: ThemeData(colorScheme: lightScheme, useMaterial3: true),
      darkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true),
      home: BrowserHomePage(
        currentThemeMode: _themeMode,
        currentAccentColor: _accentColor,
        onThemeModeChanged: _setThemeMode,
        onAccentColorChanged: _setAccentColor,
      ),
    );
  }
}

class BrowserHomePage extends StatefulWidget {
  const BrowserHomePage({
    super.key,
    required this.currentThemeMode,
    required this.currentAccentColor,
    required this.onThemeModeChanged,
    required this.onAccentColorChanged,
  });

  final ThemeMode currentThemeMode;
  final Color currentAccentColor;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<Color> onAccentColorChanged;

  @override
  State<BrowserHomePage> createState() => _BrowserHomePageState();
}

class _BrowserHomePageState extends State<BrowserHomePage> {
  static const String _defaultHomePage = 'https://www.google.com';
  static const String _aiTopIconAsset = 'assets/icons/ai-open-icon.png';
  static const List<_AccentChoice> _accentChoices = <_AccentChoice>[
    _AccentChoice('Blue', Color(0xFF2457FF)),
    _AccentChoice('Emerald', Color(0xFF14B86A)),
    _AccentChoice('Violet', Color(0xFF6C4CFF)),
    _AccentChoice('Orange', Color(0xFFFF7A18)),
    _AccentChoice('Rose', Color(0xFFEC3D77)),
    _AccentChoice('Slate', Color(0xFF546177)),
  ];

  static const String _prefHomePage = 'home_page';
  static const String _prefSearchEngine = 'search_engine';
  static const String _prefAggressiveAdBlock = 'aggressive_adblock';
  static const String _prefPanelVisibleDefault = 'panel_visible_default';
  static const String _prefAttachPageContext = 'attach_page_context';
  static const String _prefOpenTabs = 'open_tabs';
  static const String _prefActiveTabIndex = 'active_tab_index';
  static const String _prefHistory = 'browser_history';
  static const String _prefSavedSites = 'saved_sites';
  static const String _prefAiSessions = 'ai_sessions';
  static const String _prefAiActiveSessionIndex = 'ai_active_session_index';
  static const String _prefAiLanguage = 'ai_language';

  static const List<String> _baseBlockedHostParts = <String>[
    'doubleclick.net',
    'googlesyndication.com',
    'googleadservices.com',
    'adservice.google.',
    'adnxs.com',
    'taboola.com',
    'outbrain.com',
    'mgid.com',
    'adskeeper.',
    'popads.',
    'propellerads.',
    'adsterra.',
    'adtraffic.',
    'adnxs.',
    'smartadserver.com',
    'criteo.com',
    'casalemedia.com',
    'serving-sys.com',
    'moatads.com',
    'scorecardresearch.com',
    'hotjar.com',
    'facebook.net',
    'facebook.com/tr',
    'clarity.ms',
    'branch.io',
    'appsflyer.com',
    'adjust.com',
    'taboola',
    'outbrain',
    'adform.net',
    'googletagmanager.com',
    'googletagservices.com',
    'amazon-adsystem.com',
    'unityads.',
    'vungle.com',
    'ironsrc.',
    'applovin.',
    'mintegral.',
    'adsrvr.org',
    'quantserve.com',
    'mathtag.com',
    'zedo.com',
  ];

  static const List<String> _aggressiveBlockedHostParts = <String>[
    'teads.tv',
    'imasdk.googleapis.com',
    'pubmatic.com',
    'rubiconproject.com',
    'openx.net',
    'creativecdn.com',
    'trafficjunky.net',
    'exoclick.com',
    'yadro.ru',
    'adriver.ru',
    'directadvert.ru',
    'adfox.',
    'banner.',
    'ads.',
    'popunder',
    'reklama',
    'adscript',
    'adnimation',
    'adbro',
    'adpush',
    'adsafeprotected',
    'adsystem',
    'adtarget',
    'adclick',
    'adtrack',
    'adroll',
    'bidder',
    'prebid',
    'bidgear',
    'rtb',
    'banner',
    'analytics',
    'pixel.',
    'tracking',
    'stats.',
    'metric',
    'telemetry',
    'push-notification',
    'onesignal',
    'nativeads',
    'promo',
    'recommendation-widget',
    'sentry-cdn.com',
    'cdn-taboola.com',
    'cdn-outbrain.com',
    'adcolony',
    'playwire',
  ];

  static const List<String> _baseAdSelectors = <String>[
    '[id*="ad-"]',
    '[id^="ad_"]',
    '[class*=" ad-"]',
    '[class^="ad-"]',
    '[class*="ads"]',
    '[id*="ads"]',
    '.adsbox',
    '.ad-banner',
    '.banner-ad',
    '.sponsored',
    '[data-ad]',
    'iframe[src*="ad"]',
    'iframe[id*="ad"]',
  ];

  static const List<String> _aggressiveAdSelectors = <String>[
    '.popup',
    '.modal-ad',
    '.adsbygoogle',
    '.branding',
    '.advert',
    '.adblock',
    '.pre-roll',
    '.overlay-ad',
    '[class*="promo"]',
    '[id*="promo"]',
    '[class*="popunder"]',
    '[id*="popunder"]',
    '[class*="sponsor"]',
    '[id*="sponsor"]',
    '[class*="tracking"]',
    '[id*="tracking"]',
    '[class*="recommend"]',
    '[id*="recommend"]',
    '.cookie-banner',
    '.consent-banner',
    '.video-ads',
    '.ad-slot',
    '.ad-container',
    '.ad-wrapper',
  ];

  static const List<String> _blockedUrlHints = <String>[
    '/ads/',
    '/ad/',
    '/banner/',
    '/banners/',
    '/promo/',
    '/sponsor/',
    '/tracking/',
    '/analytics/',
    '/pixel',
    'popunder',
    'popup',
    'prebid',
    'googlesyndication',
    'doubleclick',
    'taboola',
    'outbrain',
    'adservice',
    'adserver',
    'nativeads',
    'recommendation',
  ];

  final AiService _aiService = AiService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final AppLinks _appLinks = AppLinks();

  late final WebViewController _webViewController;
  StreamSubscription<Uri>? _linkSub;

  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  final FocusNode _promptFocusNode = FocusNode();

  final List<_ChatMessage> _chat = <_ChatMessage>[];
  final List<_AiSession> _aiSessions = <_AiSession>[];

  final List<_MobileTab> _tabs = <_MobileTab>[
    const _MobileTab(title: 'New tab', url: _defaultHomePage),
  ];
  final List<_HistoryEntry> _history = <_HistoryEntry>[];
  final List<_SavedSite> _savedSites = <_SavedSite>[];

  bool _pageLoading = true;
  bool _thinking = false;
  bool _prefsLoaded = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _speechReady = false;
  bool _listening = false;
  bool _panelVisible = false;
  bool _panelVisibleDefault = false;
  bool _aggressiveAdBlock = true;
  bool _attachPageContext = true;
  bool _promptHasText = false;

  int _activeTabIndex = 0;
  int _activeAiSessionIndex = 0;
  String _currentUrl = _defaultHomePage;
  String _homePage = _defaultHomePage;
  _SearchEngine _searchEngine = _SearchEngine.google;
  _AiResponseLanguage _aiResponseLanguage = _AiResponseLanguage.auto;
  AiModel _selectedModel = AiModel.pro;

  Uri? _pendingIncomingUri;
  bool _manualStopRequested = false;

  @override
  void initState() {
    super.initState();
    _configureWebView();
    _initializeSpeech();
    _initializeIncomingLinks();
    _promptController.addListener(_handlePromptTextChanged);
    _seedInitialAiSession();
    _loadPreferencesAndStart();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _promptController.removeListener(_handlePromptTextChanged);
    _urlController.dispose();
    _promptController.dispose();
    _urlFocusNode.dispose();
    _promptFocusNode.dispose();
    _speech.stop();
    _aiService.dispose();
    super.dispose();
  }

  _MobileTab get _activeTab => _tabs[_activeTabIndex];

  _AiSession get _activeAiSession => _aiSessions[_activeAiSessionIndex];

  void _seedInitialAiSession() {
    if (_aiSessions.isNotEmpty) {
      return;
    }
    final _AiSession session = _AiSession(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: 'New chat',
      updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      messages: <_ChatMessage>[_ChatMessage.assistant(_welcomeText)],
    );
    _aiSessions.add(session);
    _chat
      ..clear()
      ..addAll(session.messages);
  }

  String get _welcomeText {
    switch (_aiResponseLanguage) {
      case _AiResponseLanguage.ukrainian:
        return 'Vitayu! Napyshit zapyt i ya dopomozhu.';
      case _AiResponseLanguage.english:
        return 'Hello! Send a prompt and I will help.';
      case _AiResponseLanguage.slovak:
        return 'Ahoj! Napiste poziadavku a pomozem.';
      case _AiResponseLanguage.auto:
        return 'Hello! Send a prompt and I will help.';
    }
  }

  void _configureWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            if (_isBlockedRequest(request.url)) {
              _showSnack('Blocked ad or tracker request');
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (String url) {
            if (!mounted) {
              return;
            }
            setState(() {
              _pageLoading = true;
              _currentUrl = url;
              _urlController.text = url;
              _tabs[_activeTabIndex] = _activeTab.copyWith(url: url);
            });
            _schedulePersistTabState();
          },
          onPageFinished: (String url) async {
            final String title =
                (await _webViewController.getTitle())?.trim() ?? 'Page';
            if (!mounted) {
              return;
            }
            setState(() {
              _pageLoading = false;
              _currentUrl = url;
              _urlController.text = url;
              _tabs[_activeTabIndex] = _activeTab.copyWith(
                url: url,
                title: title.isEmpty ? 'Page' : title,
              );
            });
            _pushHistory(url, title);
            _schedulePersistTabState();
            await _injectAdBlockDomCleaner();
            await _refreshNavigationControls();
          },
        ),
      );
  }

  Future<void> _loadPreferencesAndStart() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String savedHome = prefs.getString(_prefHomePage) ?? _defaultHomePage;
    final String savedEngine = prefs.getString(_prefSearchEngine) ?? 'google';
    final bool savedAggressive = prefs.getBool(_prefAggressiveAdBlock) ?? true;
    final bool savedPanelDefault =
        prefs.getBool(_prefPanelVisibleDefault) ?? false;
    final bool savedAttachContext =
        prefs.getBool(_prefAttachPageContext) ?? true;
    final String savedTabsRaw = prefs.getString(_prefOpenTabs) ?? '';
    final int savedTabIndex = prefs.getInt(_prefActiveTabIndex) ?? 0;
    final String savedHistoryRaw = prefs.getString(_prefHistory) ?? '';
    final String savedSitesRaw = prefs.getString(_prefSavedSites) ?? '';
    final String savedAiSessionsRaw = prefs.getString(_prefAiSessions) ?? '';
    final int savedAiSessionIndex =
        prefs.getInt(_prefAiActiveSessionIndex) ?? 0;
    final String savedAiLanguage = prefs.getString(_prefAiLanguage) ?? 'auto';

    if (!mounted) {
      return;
    }

    final String normalizedHome = _normalizeToUrl(savedHome);
    final List<_MobileTab> restoredTabs = _decodeTabs(
      savedTabsRaw,
      fallbackUrl: normalizedHome,
    );
    final List<_HistoryEntry> restoredHistory = _decodeHistory(savedHistoryRaw);
    final List<_SavedSite> restoredSavedSites = _decodeSavedSites(
      savedSitesRaw,
    );
    final List<_AiSession> restoredAiSessions = _decodeAiSessions(
      savedAiSessionsRaw,
    );
    final int normalizedTabIndex =
        (savedTabIndex < 0 || savedTabIndex >= restoredTabs.length)
        ? 0
        : savedTabIndex;
    final int normalizedAiSessionIndex =
        (savedAiSessionIndex < 0 ||
            savedAiSessionIndex >= restoredAiSessions.length)
        ? 0
        : savedAiSessionIndex;
    final String startupUrl = restoredTabs[normalizedTabIndex].url;

    setState(() {
      _homePage = normalizedHome;
      _searchEngine = _searchEngineFromKey(savedEngine);
      _aggressiveAdBlock = savedAggressive;
      _panelVisibleDefault = savedPanelDefault;
      _panelVisible = false;
      _attachPageContext = savedAttachContext;
      _aiResponseLanguage = _aiResponseLanguageFromKey(savedAiLanguage);
      _prefsLoaded = true;
      _tabs
        ..clear()
        ..addAll(restoredTabs);
      _history
        ..clear()
        ..addAll(restoredHistory);
      _savedSites
        ..clear()
        ..addAll(restoredSavedSites);
      _aiSessions
        ..clear()
        ..addAll(restoredAiSessions);
      _activeTabIndex = normalizedTabIndex;
      _activeAiSessionIndex = normalizedAiSessionIndex;
      _chat
        ..clear()
        ..addAll(_activeAiSession.messages);
      _currentUrl = startupUrl;
      _urlController.text = startupUrl;
    });

    await _loadUrlIntoCurrent(Uri.parse(startupUrl));

    final Uri? pending = _pendingIncomingUri;
    if (pending != null) {
      _pendingIncomingUri = null;
      await _openIncomingUri(pending);
    }
  }

  Future<void> _savePreferences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefHomePage, _homePage);
    await prefs.setString(_prefSearchEngine, _searchEngine.key);
    await prefs.setBool(_prefAggressiveAdBlock, _aggressiveAdBlock);
    await prefs.setBool(_prefPanelVisibleDefault, _panelVisibleDefault);
    await prefs.setBool(_prefAttachPageContext, _attachPageContext);
    await prefs.setString(_prefAiLanguage, _aiResponseLanguage.key);
  }

  void _handlePromptTextChanged() {
    final bool hasText = _promptController.text.trim().isNotEmpty;
    if (hasText == _promptHasText || !mounted) {
      return;
    }
    setState(() {
      _promptHasText = hasText;
    });
  }

  List<_MobileTab> _decodeTabs(String raw, {required String fallbackUrl}) {
    if (raw.trim().isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(raw);
        if (decoded is List) {
          final List<_MobileTab> parsed = decoded
              .map<_MobileTab?>((dynamic item) => _MobileTab.fromJson(item))
              .whereType<_MobileTab>()
              .toList();
          if (parsed.isNotEmpty) {
            return parsed;
          }
        }
      } catch (_) {}
    }
    return <_MobileTab>[_MobileTab(title: 'New tab', url: fallbackUrl)];
  }

  List<_HistoryEntry> _decodeHistory(String raw) {
    if (raw.trim().isEmpty) {
      return <_HistoryEntry>[];
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <_HistoryEntry>[];
      }
      return decoded
          .map<_HistoryEntry?>((dynamic item) => _HistoryEntry.fromJson(item))
          .whereType<_HistoryEntry>()
          .toList();
    } catch (_) {
      return <_HistoryEntry>[];
    }
  }

  List<_SavedSite> _decodeSavedSites(String raw) {
    if (raw.trim().isEmpty) {
      return <_SavedSite>[];
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <_SavedSite>[];
      }
      return decoded
          .map<_SavedSite?>((dynamic item) => _SavedSite.fromJson(item))
          .whereType<_SavedSite>()
          .toList();
    } catch (_) {
      return <_SavedSite>[];
    }
  }

  List<_AiSession> _decodeAiSessions(String raw) {
    if (raw.trim().isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(raw);
        if (decoded is List) {
          final List<_AiSession> parsed = decoded
              .map<_AiSession?>((dynamic item) => _AiSession.fromJson(item))
              .whereType<_AiSession>()
              .toList();
          if (parsed.isNotEmpty) {
            return parsed;
          }
        }
      } catch (_) {}
    }
    return <_AiSession>[
      _AiSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'New chat',
        updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
        messages: <_ChatMessage>[_ChatMessage.assistant(_welcomeText)],
      ),
    ];
  }

  Future<void> _persistTabState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefOpenTabs,
      jsonEncode(_tabs.map((t) => t.toJson()).toList(growable: false)),
    );
    await prefs.setInt(_prefActiveTabIndex, _activeTabIndex);
  }

  Future<void> _persistHistoryState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefHistory,
      jsonEncode(_history.map((h) => h.toJson()).toList(growable: false)),
    );
  }

  Future<void> _persistSavedSites() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefSavedSites,
      jsonEncode(_savedSites.map((s) => s.toJson()).toList(growable: false)),
    );
  }

  Future<void> _persistAiSessions() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefAiSessions,
      jsonEncode(_aiSessions.map((s) => s.toJson()).toList(growable: false)),
    );
    await prefs.setInt(_prefAiActiveSessionIndex, _activeAiSessionIndex);
  }

  void _schedulePersistTabState() => unawaited(_persistTabState());

  void _schedulePersistHistoryState() => unawaited(_persistHistoryState());

  void _schedulePersistSavedSites() => unawaited(_persistSavedSites());

  void _schedulePersistAiSessions() => unawaited(_persistAiSessions());

  Future<void> _initializeSpeech() async {
    final bool available = await _speech.initialize(
      onStatus: (String status) {
        if (!mounted) {
          return;
        }
        if (status == 'done' || status == 'notListening') {
          setState(() {
            _listening = false;
          });
        }
      },
      onError: (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _listening = false;
        });
      },
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _speechReady = available;
    });
  }

  Future<void> _initializeIncomingLinks() async {
    try {
      final Uri? initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleIncomingUri(initialLink);
      }
    } catch (_) {
      // Ignore malformed startup links.
    }

    _linkSub = _appLinks.uriLinkStream.listen(
      _handleIncomingUri,
      onError: (_) {},
    );
  }

  void _handleIncomingUri(Uri uri) {
    if (!_isAcceptableIncomingUri(uri)) {
      return;
    }
    if (!_prefsLoaded) {
      _pendingIncomingUri = uri;
      return;
    }
    _openIncomingUri(uri);
  }

  bool _isAcceptableIncomingUri(Uri uri) {
    final String scheme = uri.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https' || scheme == 'file';
  }

  Future<void> _openIncomingUri(Uri uri) async {
    if (!_isAcceptableIncomingUri(uri)) {
      return;
    }
    await _loadUrlIntoCurrent(uri);
    if (!mounted) {
      return;
    }
    setState(() {
      _currentUrl = uri.toString();
      _urlController.text = _currentUrl;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildTopBrowserBar(),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            WebViewWidget(controller: _webViewController),
            if (_pageLoading)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (_panelVisible) _buildAiPanel(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomDock(),
    );
  }

  PreferredSizeWidget _buildTopBrowserBar() {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return AppBar(
      titleSpacing: 6,
      toolbarHeight: 66,
      title: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            onPressed: _canGoBack
                ? () async {
                    await _webViewController.goBack();
                    await _refreshNavigationControls();
                  }
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_rounded),
            tooltip: 'Forward',
            onPressed: _canGoForward
                ? () async {
                    await _webViewController.goForward();
                    await _refreshNavigationControls();
                  }
                : null,
          ),
          Expanded(
            child: TextField(
              controller: _urlController,
              focusNode: _urlFocusNode,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _openTypedInput(),
              decoration: InputDecoration(
                hintText: 'Search or type URL',
                filled: true,
                fillColor: colors.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_upward_rounded),
            tooltip: 'Go',
            onPressed: _openTypedInput,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload',
            onPressed: () async {
              await _webViewController.reload();
              await _refreshNavigationControls();
            },
          ),
          const SizedBox(width: 4),
          _buildAiToggleButton(),
        ],
      ),
    );
  }

  Widget _buildAiToggleButton() {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool visible = _panelVisible;
    return Material(
      color: visible ? colors.primaryContainer : colors.surfaceContainerHighest,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          setState(() {
            _panelVisible = !_panelVisible;
          });
        },
        child: SizedBox(
          width: 42,
          height: 42,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Image.asset(
              _aiTopIconAsset,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) {
                return Icon(
                  visible ? Icons.smart_toy : Icons.smart_toy_outlined,
                  size: 18,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomDock() {
    return SafeArea(
      top: false,
      child: Material(
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          child: Row(
            children: <Widget>[
              _DockIconButton(
                icon: Icons.home_outlined,
                tooltip: 'Home',
                onPressed: _goHome,
              ),
              _DockIconButton(
                icon: Icons.layers_outlined,
                tooltip: 'Tabs',
                onPressed: _showTabsSheet,
                badge: _tabs.length > 1 ? _tabs.length.toString() : null,
              ),
              _DockIconButton(
                icon: Icons.bookmark_border_rounded,
                tooltip: 'Saved sites',
                onPressed: _openSavedSitesSheet,
                badge: _savedSites.isNotEmpty
                    ? _savedSites.length.toString()
                    : null,
              ),
              _DockIconButton(
                icon: Icons.add_circle_outline,
                tooltip: 'Browser menu',
                onPressed: _openWidgetsSheet,
              ),
              const Spacer(),
              _DockIconButton(
                icon: Icons.settings_outlined,
                tooltip: 'Settings',
                onPressed: _openSettingsSheet,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiPanel() {
    final Size size = MediaQuery.sizeOf(context);
    final bool compact = size.width < 460;
    final double panelWidth = compact ? size.width - 12 : 470;
    final double panelHeight = size.height < 760 ? 380 : 460;

    return Positioned(
      right: 6,
      left: compact ? 6 : null,
      bottom: 72,
      width: compact ? null : panelWidth,
      height: panelHeight,
      child: Card(
        elevation: 18,
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: <Widget>[
            Container(
              width: compact ? 116 : 132,
              padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Chats',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: _thinking ? null : _newChat,
                        icon: const Icon(Icons.add_rounded),
                        tooltip: 'New chat',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _aiSessions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (BuildContext context, int index) {
                        final _AiSession session = _aiSessions[index];
                        final bool active = index == _activeAiSessionIndex;
                        return Material(
                          color: active
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _switchAiSession(index),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      session.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: active
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _aiSessions.length <= 1
                                        ? null
                                        : () => _deleteAiSession(index),
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Delete',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: Theme.of(context).dividerColor,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(Icons.auto_awesome),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'OleksandrAi',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _panelVisible = false;
                            });
                          },
                          icon: const Icon(Icons.close),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: DropdownButtonFormField<AiModel>(
                            initialValue: _selectedModel,
                            onChanged: (AiModel? value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _selectedModel = value;
                              });
                            },
                            items: AiModel.values
                                .map(
                                  (AiModel model) => DropdownMenuItem<AiModel>(
                                    value: model,
                                    child: Text(model.label),
                                  ),
                                )
                                .toList(),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: _thinking ? null : _newChat,
                          child: const Text('New'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(10),
                          itemCount: _chat.length + (_thinking ? 1 : 0),
                          separatorBuilder: (_, int index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (BuildContext context, int index) {
                            if (_thinking && index == _chat.length) {
                              return const _ThinkingMessage();
                            }
                            final _ChatMessage message = _chat[index];
                            return _ChatBubble(message: message);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        IconButton.filledTonal(
                          onPressed: _thinking ? null : _openAiToolsSheet,
                          icon: const Icon(Icons.add_rounded),
                          tooltip: 'AI tools',
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _promptController,
                            focusNode: _promptFocusNode,
                            minLines: 1,
                            maxLines: 6,
                            textInputAction: TextInputAction.newline,
                            decoration: const InputDecoration(
                              hintText: 'Type prompt...',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _resolvePrimaryAiButtonEnabled()
                              ? _handlePrimaryAiAction
                              : null,
                          icon: Icon(_resolvePrimaryAiButtonIcon()),
                          tooltip: _resolvePrimaryAiButtonTooltip(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshNavigationControls() async {
    final bool canGoBack = await _webViewController.canGoBack();
    final bool canGoForward = await _webViewController.canGoForward();
    if (!mounted) {
      return;
    }
    setState(() {
      _canGoBack = canGoBack;
      _canGoForward = canGoForward;
    });
  }

  Future<void> _loadUrlIntoCurrent(Uri uri) async {
    await _webViewController.loadRequest(uri);
    if (!mounted) {
      return;
    }
    setState(() {
      _currentUrl = uri.toString();
      _urlController.text = _currentUrl;
      _tabs[_activeTabIndex] = _activeTab.copyWith(url: _currentUrl);
    });
    _schedulePersistTabState();
    await _refreshNavigationControls();
  }

  Future<void> _goHome() async {
    await _loadUrlIntoCurrent(Uri.parse(_homePage));
  }

  Future<void> _newTab([String? startUrl]) async {
    final String target = _normalizeToUrl(startUrl ?? _homePage);
    setState(() {
      _tabs.add(_MobileTab(title: 'New tab ${_tabs.length + 1}', url: target));
      _activeTabIndex = _tabs.length - 1;
    });
    _schedulePersistTabState();
    await _loadUrlIntoCurrent(Uri.parse(target));
  }

  Future<void> _switchTab(int index) async {
    if (index < 0 || index >= _tabs.length) {
      return;
    }
    setState(() {
      _activeTabIndex = index;
    });
    _schedulePersistTabState();
    await _loadUrlIntoCurrent(Uri.parse(_tabs[index].url));
  }

  void _closeTab(int index) {
    if (_tabs.length <= 1 || index < 0 || index >= _tabs.length) {
      return;
    }
    setState(() {
      _tabs.removeAt(index);
      if (_activeTabIndex >= _tabs.length) {
        _activeTabIndex = _tabs.length - 1;
      }
    });
    _schedulePersistTabState();
    _loadUrlIntoCurrent(Uri.parse(_activeTab.url));
  }

  Future<void> _showTabsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            children: <Widget>[
              ListTile(
                title: Text('Tabs (${_tabs.length})'),
                trailing: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _newTab();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('New'),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: _tabs.length,
                  itemBuilder: (BuildContext context, int index) {
                    final _MobileTab tab = _tabs[index];
                    final bool isActive = index == _activeTabIndex;
                    return ListTile(
                      selected: isActive,
                      title: Text(
                        tab.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        tab.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        _switchTab(index);
                      },
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            onPressed: () {
                              _saveCurrentSite(
                                url: tab.url,
                                title: tab.title,
                                toast: true,
                              );
                            },
                            icon: const Icon(Icons.bookmark_add_outlined),
                            tooltip: 'Save site',
                          ),
                          if (_tabs.length > 1)
                            IconButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _closeTab(index);
                              },
                              icon: const Icon(Icons.close),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openWidgetsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('New tab'),
                onTap: () {
                  Navigator.of(context).pop();
                  _newTab();
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open_outlined),
                title: const Text('Open file or photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  _openLocalFile();
                },
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_add_outlined),
                title: const Text('Save current site'),
                onTap: () {
                  Navigator.of(context).pop();
                  _saveCurrentSite();
                },
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_rounded),
                title: const Text('Saved sites'),
                onTap: () {
                  Navigator.of(context).pop();
                  _openSavedSitesSheet();
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('History'),
                onTap: () {
                  Navigator.of(context).pop();
                  _openHistorySheet();
                },
              ),
              SwitchListTile.adaptive(
                value: _aggressiveAdBlock,
                onChanged: (bool value) async {
                  setState(() {
                    _aggressiveAdBlock = value;
                  });
                  await _savePreferences();
                },
                secondary: const Icon(Icons.shield_outlined),
                title: const Text('Aggressive ad blocking'),
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.of(context).pop();
                  _openSettingsSheet();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openHistorySheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        if (_history.isEmpty) {
          return const SizedBox(
            height: 160,
            child: Center(child: Text('No history yet')),
          );
        }
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _history.length,
            itemBuilder: (BuildContext context, int index) {
              final _HistoryEntry entry = _history[index];
              return ListTile(
                title: Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  entry.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _loadUrlIntoCurrent(Uri.parse(entry.url));
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openSavedSitesSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        if (_savedSites.isEmpty) {
          return const SizedBox(
            height: 160,
            child: Center(child: Text('No saved sites yet')),
          );
        }
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _savedSites.length,
            itemBuilder: (BuildContext context, int index) {
              final _SavedSite site = _savedSites[index];
              return ListTile(
                leading: const Icon(Icons.bookmark_rounded),
                title: Text(
                  site.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  site.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _loadUrlIntoCurrent(Uri.parse(site.url));
                },
                trailing: IconButton(
                  onPressed: () => _removeSavedSite(index),
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Delete',
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _saveCurrentSite({String? url, String? title, bool toast = true}) {
    final String nextUrl = (url ?? _currentUrl).trim();
    final String nextTitle = (title ?? _activeTab.title).trim();
    if (nextUrl.isEmpty) {
      return;
    }
    final _SavedSite site = _SavedSite(
      title: nextTitle.isEmpty ? nextUrl : nextTitle,
      url: nextUrl,
      savedAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
    setState(() {
      _savedSites.removeWhere((s) => s.url == site.url);
      _savedSites.insert(0, site);
      if (_savedSites.length > 200) {
        _savedSites.removeRange(200, _savedSites.length);
      }
    });
    _schedulePersistSavedSites();
    if (toast) {
      _showSnack('Site saved');
    }
  }

  void _removeSavedSite(int index) {
    if (index < 0 || index >= _savedSites.length) {
      return;
    }
    setState(() {
      _savedSites.removeAt(index);
    });
    _schedulePersistSavedSites();
  }

  void _switchAiSession(int index) {
    if (index < 0 || index >= _aiSessions.length || _thinking) {
      return;
    }
    setState(() {
      _activeAiSessionIndex = index;
      _chat
        ..clear()
        ..addAll(_aiSessions[index].messages);
    });
    _schedulePersistAiSessions();
  }

  void _deleteAiSession(int index) {
    if (_aiSessions.length <= 1 || index < 0 || index >= _aiSessions.length) {
      return;
    }
    setState(() {
      _aiSessions.removeAt(index);
      if (_activeAiSessionIndex >= _aiSessions.length) {
        _activeAiSessionIndex = _aiSessions.length - 1;
      }
      _chat
        ..clear()
        ..addAll(_activeAiSession.messages);
    });
    _schedulePersistAiSessions();
  }

  void _syncActiveAiSessionFromChat() {
    if (_aiSessions.isEmpty || _activeAiSessionIndex >= _aiSessions.length) {
      return;
    }
    final int now = DateTime.now().millisecondsSinceEpoch;
    String title = 'New chat';
    for (final _ChatMessage message in _chat) {
      if (message.role == _ChatRole.user && message.text.trim().isNotEmpty) {
        title = message.text.trim();
        if (title.length > 28) {
          title = '${title.substring(0, 28)}...';
        }
        break;
      }
    }
    _aiSessions[_activeAiSessionIndex] = _activeAiSession.copyWith(
      title: title,
      updatedAtMillis: now,
      messages: List<_ChatMessage>.from(_chat),
    );
    _schedulePersistAiSessions();
  }

  Future<void> _openAiToolsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.analytics_outlined),
                title: const Text('Analyze open page'),
                onTap: () {
                  Navigator.of(context).pop();
                  _analyzeOpenPage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.summarize_outlined),
                title: const Text('Summarize page'),
                onTap: () {
                  Navigator.of(context).pop();
                  _summarizeOpenPage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.checklist_rounded),
                title: const Text('Extract key points'),
                onTap: () {
                  Navigator.of(context).pop();
                  _extractPageKeyPoints();
                },
              ),
              ListTile(
                leading: const Icon(Icons.translate_rounded),
                title: const Text('Translate to Ukrainian'),
                onTap: () {
                  Navigator.of(context).pop();
                  _translateOpenPageToUkrainian();
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open_outlined),
                title: const Text('Open file or photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  _openLocalFile();
                },
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_add_outlined),
                title: const Text('Save current site'),
                onTap: () {
                  Navigator.of(context).pop();
                  _saveCurrentSite();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  bool _resolvePrimaryAiButtonEnabled() {
    if (_thinking) {
      return true;
    }
    if (_promptHasText) {
      return true;
    }
    return _speechReady;
  }

  IconData _resolvePrimaryAiButtonIcon() {
    if (_thinking) {
      return Icons.stop_rounded;
    }
    if (_promptHasText) {
      return Icons.send_rounded;
    }
    return _listening ? Icons.mic_off_rounded : Icons.mic_rounded;
  }

  String _resolvePrimaryAiButtonTooltip() {
    if (_thinking) {
      return 'Stop generation';
    }
    if (_promptHasText) {
      return 'Send prompt';
    }
    return _listening ? 'Stop voice input' : 'Voice input';
  }

  Future<void> _handlePrimaryAiAction() async {
    if (_thinking) {
      _stopGeneration();
      return;
    }
    if (_promptHasText) {
      await _sendPrompt();
      return;
    }
    await _togglePromptVoiceInput();
  }

  void _pushHistory(String url, String title) {
    if (url.trim().isEmpty) {
      return;
    }
    final String safeTitle = title.trim().isEmpty ? url : title.trim();
    final _HistoryEntry entry = _HistoryEntry(title: safeTitle, url: url);
    setState(() {
      _history.removeWhere((e) => e.url == entry.url && e.title == entry.title);
      _history.insert(0, entry);
      if (_history.length > 120) {
        _history.removeRange(120, _history.length);
      }
    });
    _schedulePersistHistoryState();
  }

  bool _isBlockedRequest(String rawUrl) {
    final Uri? uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return false;
    }

    final String host = uri.host.toLowerCase();
    if (host.isEmpty) {
      return false;
    }

    final List<String> hostRules = _aggressiveAdBlock
        ? <String>[..._baseBlockedHostParts, ..._aggressiveBlockedHostParts]
        : _baseBlockedHostParts;

    if (hostRules.any(host.contains)) {
      return true;
    }

    final String full = rawUrl.toLowerCase();
    if (_blockedUrlHints.any(full.contains)) {
      return true;
    }
    if (_aggressiveAdBlock) {
      if (full.contains('xbet') ||
          full.contains('casino') ||
          full.contains('betting') ||
          full.contains('clickid=')) {
        return true;
      }
    }

    return false;
  }

  Future<void> _injectAdBlockDomCleaner() async {
    final List<String> selectors = _aggressiveAdBlock
        ? <String>[..._baseAdSelectors, ..._aggressiveAdSelectors]
        : _baseAdSelectors;
    final String selectorList = selectors
        .map((String value) => "'${value.replaceAll("'", "\\'")}'")
        .join(',');

    final String script =
        '''
      (() => {
        try {
          const blockPatterns = ${jsonEncode(_blockedUrlHints)};
          const selectors = [$selectorList];
          const hideAndRemove = () => {
            selectors.forEach((selector) => {
              document.querySelectorAll(selector).forEach((el) => {
                el.remove();
              });
            });

            document.querySelectorAll('iframe,script,link,img,video,source').forEach((el) => {
              const src = (el.src || el.href || '').toLowerCase();
              if (!src) return;
              if (blockPatterns.some((p) => src.includes(String(p).toLowerCase()))) {
                el.remove();
              }
            });
          };

          hideAndRemove();
          if (!document.getElementById('olewser-adblock-style')) {
            const style = document.createElement('style');
            style.id = 'olewser-adblock-style';
            style.textContent = selectors.map((sel) => sel + ' { display: none !important; visibility: hidden !important; }').join('\\n');
            document.head?.appendChild(style);
          }

          if (!window.__olewserAdblockPatched) {
            window.__olewserAdblockPatched = true;

            const originalOpen = window.open;
            window.open = function(url, ...rest) {
              try {
                const value = String(url || '').toLowerCase();
                if (blockPatterns.some((p) => value.includes(String(p).toLowerCase()))) {
                  return null;
                }
              } catch (_) {}
              return originalOpen.call(window, url, ...rest);
            };

            const observer = new MutationObserver(() => hideAndRemove());
            observer.observe(document.documentElement || document.body, {
              childList: true,
              subtree: true,
              attributes: false
            });

            setInterval(hideAndRemove, 1500);
          }
        } catch (_) {}
      })();
    ''';

    try {
      await _webViewController.runJavaScript(script);
    } catch (_) {
      // Ignore adblock injection errors on protected pages.
    }
  }

  Future<void> _openTypedInput() async {
    final String rawInput = _urlController.text.trim();
    if (rawInput.isEmpty) {
      return;
    }
    _urlFocusNode.unfocus();
    final Uri uri = _normalizeToUri(rawInput);
    await _loadUrlIntoCurrent(uri);
  }

  Uri _normalizeToUri(String input) {
    final bool hasScheme =
        input.startsWith('http://') ||
        input.startsWith('https://') ||
        input.startsWith('file://');
    if (hasScheme) {
      return Uri.parse(input);
    }
    if (input.contains(' ') || !input.contains('.')) {
      return _searchEngine.buildSearchUri(input);
    }
    return Uri.parse('https://$input');
  }

  String _normalizeToUrl(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return _defaultHomePage;
    }
    try {
      final Uri uri = _normalizeToUri(trimmed);
      return uri.toString();
    } catch (_) {
      return _defaultHomePage;
    }
  }

  Future<void> _openLocalFile() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: <String>[
        'html',
        'htm',
        'txt',
        'pdf',
        'png',
        'jpg',
        'jpeg',
        'webp',
        'gif',
      ],
    );

    if (result == null || result.files.isEmpty) {
      return;
    }
    final String? selectedPath = result.files.single.path;
    if (selectedPath == null || selectedPath.trim().isEmpty) {
      _showSnack('Could not read selected file path');
      return;
    }

    final File file = File(selectedPath);
    if (!await file.exists()) {
      _showSnack('Selected file does not exist');
      return;
    }

    await _loadUrlIntoCurrent(Uri.file(file.path));
  }

  Future<void> _analyzeOpenPage() async {
    _promptFocusNode.unfocus();
    final String contextSnippet = await _collectPageContextSnippet();
    final String prompt =
        '''
Analyze the currently open browser page.

$contextSnippet

Give:
1) short summary
2) important details
3) what I can do next
''';

    await _sendPrompt(
      promptOverride: prompt,
      userVisibleText: 'Analyze open page',
      includePageContext: false,
    );
  }

  Future<void> _summarizeOpenPage() async {
    final String contextSnippet = await _collectPageContextSnippet();
    final String prompt =
        '''
Summarize the open page in a compact and practical format.

$contextSnippet

Return:
1) one sentence summary
2) 5 key points
3) one warning or limitation if needed
''';
    await _sendPrompt(
      promptOverride: prompt,
      userVisibleText: 'Summarize page',
      includePageContext: false,
    );
  }

  Future<void> _extractPageKeyPoints() async {
    final String contextSnippet = await _collectPageContextSnippet();
    final String prompt =
        '''
Extract key points from the open page.

$contextSnippet

Return:
1) main topic
2) important facts (bullet list)
3) next practical actions
''';
    await _sendPrompt(
      promptOverride: prompt,
      userVisibleText: 'Key points',
      includePageContext: false,
    );
  }

  Future<void> _translateOpenPageToUkrainian() async {
    final String contextSnippet = await _collectPageContextSnippet();
    final String prompt =
        '''
Translate and adapt the open page content to Ukrainian.

$contextSnippet

Return:
1) short translated summary
2) translated key terms
3) translated call-to-action if present
''';
    await _sendPrompt(
      promptOverride: prompt,
      userVisibleText: 'Translate page to Ukrainian',
      includePageContext: false,
    );
  }

  Future<String> _collectPageContextSnippet() async {
    final String title = (await _webViewController.getTitle())?.trim() ?? '';
    final dynamic rawBody = await _webViewController
        .runJavaScriptReturningResult('''
      (() => {
        const text = document.body?.innerText ?? '';
        return JSON.stringify(text.slice(0, 2000));
      })();
    ''');

    final String bodyText = _decodeJsString(
      rawBody,
    ).replaceAll(RegExp(r'\\s+'), ' ').trim();

    return '''
URL: $_currentUrl
Title: ${title.isEmpty ? 'Unknown' : title}
Visible text excerpt:
$bodyText
''';
  }

  String _decodeJsString(dynamic rawBody) {
    if (rawBody == null) {
      return '';
    }
    if (rawBody is String) {
      final String trimmed = rawBody.trim();
      try {
        final dynamic decoded = jsonDecode(trimmed);
        if (decoded is String) {
          return decoded;
        }
      } catch (_) {
        return trimmed;
      }
      return trimmed;
    }
    return rawBody.toString();
  }

  Future<void> _togglePromptVoiceInput() async {
    if (_listening) {
      await _speech.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _listening = false;
      });
      return;
    }

    if (!_speechReady) {
      _showSnack('Microphone is unavailable');
      return;
    }

    final bool started = await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        if (!mounted) {
          return;
        }
        setState(() {
          _promptController.text = result.recognizedWords;
          _promptController.selection = TextSelection.fromPosition(
            TextPosition(offset: _promptController.text.length),
          );
        });
      },
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
      localeId: _aiResponseLanguage.speechLocaleId,
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _listening = started;
    });
  }

  void _stopGeneration() {
    if (!_thinking) {
      return;
    }
    _manualStopRequested = true;
    _aiService.cancelCurrent();
    setState(() {
      _thinking = false;
      _chat.add(_ChatMessage.assistant('Generation stopped.'));
    });
    _syncActiveAiSessionFromChat();
  }

  Future<void> _sendPrompt({
    String? promptOverride,
    String? userVisibleText,
    bool includePageContext = true,
  }) async {
    final String typedPrompt = _promptController.text.trim();
    String prompt = (promptOverride ?? typedPrompt).trim();
    if (prompt.isEmpty || _thinking) {
      return;
    }
    final String visibleText =
        (userVisibleText ?? (promptOverride == null ? typedPrompt : prompt))
            .trim();

    if (includePageContext && _attachPageContext && promptOverride == null) {
      final String pageContext = await _collectPageContextSnippet();
      prompt = '$prompt\n\nCurrent page context:\n$pageContext';
    }

    _manualStopRequested = false;
    setState(() {
      _thinking = true;
      _chat.add(
        _ChatMessage.user(visibleText.isEmpty ? 'Prompt' : visibleText),
      );
      if (promptOverride == null) {
        _promptController.clear();
      }
    });
    _syncActiveAiSessionFromChat();

    final List<_ChatMessage> recent = _chat.length > 12
        ? _chat.sublist(_chat.length - 12)
        : List<_ChatMessage>.from(_chat);

    String clip(String text, {int maxChars = 1800}) {
      final String clean = text.trim();
      if (clean.length <= maxChars) {
        return clean;
      }
      return '${clean.substring(0, maxChars)}...';
    }

    final List<AiChatMessage> messages = <AiChatMessage>[
      AiChatMessage(
        role: 'system',
        content:
            'You are OleksandrAi inside Olewser browser. Reply clearly and concise. ${_aiResponseLanguage.systemInstruction}',
      ),
      ...recent.map(
        (_ChatMessage message) => AiChatMessage(
          role: message.role == _ChatRole.user ? 'user' : 'assistant',
          content: clip(message.text),
        ),
      ),
      AiChatMessage(role: 'user', content: clip(prompt, maxChars: 2500)),
    ];

    try {
      final String result = await _aiService.complete(
        model: _selectedModel,
        messages: messages,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _chat.add(_ChatMessage.assistant(result));
      });
      _syncActiveAiSessionFromChat();
    } on AiRequestCanceledException {
      if (!mounted) {
        return;
      }
      if (!_manualStopRequested) {
        setState(() {
          _chat.add(_ChatMessage.assistant('Generation stopped.'));
        });
        _syncActiveAiSessionFromChat();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _chat.add(_ChatMessage.assistant('AI error: $error'));
      });
      _syncActiveAiSessionFromChat();
    } finally {
      if (mounted) {
        setState(() {
          _thinking = false;
        });
      }
    }
  }

  void _newChat() {
    if (_thinking) {
      return;
    }
    final _AiSession session = _AiSession(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: 'New chat',
      updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      messages: <_ChatMessage>[_ChatMessage.assistant(_welcomeText)],
    );
    setState(() {
      _aiSessions.insert(0, session);
      if (_aiSessions.length > 60) {
        _aiSessions.removeRange(60, _aiSessions.length);
      }
      _activeAiSessionIndex = 0;
      _chat
        ..clear()
        ..addAll(session.messages);
      _promptController.clear();
    });
    _schedulePersistAiSessions();
  }

  Future<void> _openSettingsSheet() async {
    final TextEditingController homeController = TextEditingController(
      text: _homePage,
    );
    ThemeMode draftTheme = widget.currentThemeMode;
    _SearchEngine draftEngine = _searchEngine;
    _AiResponseLanguage draftLanguage = _aiResponseLanguage;
    bool draftAggressive = _aggressiveAdBlock;
    bool draftAttachContext = _attachPageContext;
    Color draftAccent = widget.currentAccentColor;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setM) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Olewser Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<ThemeMode>(
                        initialValue: draftTheme,
                        decoration: const InputDecoration(
                          labelText: 'Theme',
                          border: OutlineInputBorder(),
                        ),
                        items: const <DropdownMenuItem<ThemeMode>>[
                          DropdownMenuItem<ThemeMode>(
                            value: ThemeMode.system,
                            child: Text('System'),
                          ),
                          DropdownMenuItem<ThemeMode>(
                            value: ThemeMode.light,
                            child: Text('Light'),
                          ),
                          DropdownMenuItem<ThemeMode>(
                            value: ThemeMode.dark,
                            child: Text('Dark'),
                          ),
                        ],
                        onChanged: (ThemeMode? mode) {
                          if (mode == null) {
                            return;
                          }
                          setM(() {
                            draftTheme = mode;
                          });
                          widget.onThemeModeChanged(mode);
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<_SearchEngine>(
                        initialValue: draftEngine,
                        decoration: const InputDecoration(
                          labelText: 'Default search engine',
                          border: OutlineInputBorder(),
                        ),
                        items: _SearchEngine.values
                            .map(
                              (_SearchEngine engine) =>
                                  DropdownMenuItem<_SearchEngine>(
                                    value: engine,
                                    child: Text(engine.label),
                                  ),
                            )
                            .toList(),
                        onChanged: (_SearchEngine? value) {
                          if (value == null) {
                            return;
                          }
                          setM(() {
                            draftEngine = value;
                          });
                          setState(() {
                            _searchEngine = value;
                          });
                          unawaited(_savePreferences());
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<_AiResponseLanguage>(
                        initialValue: draftLanguage,
                        decoration: const InputDecoration(
                          labelText: 'AI response language',
                          border: OutlineInputBorder(),
                        ),
                        items: _AiResponseLanguage.values
                            .map(
                              (_AiResponseLanguage language) =>
                                  DropdownMenuItem<_AiResponseLanguage>(
                                    value: language,
                                    child: Text(language.label),
                                  ),
                            )
                            .toList(),
                        onChanged: (_AiResponseLanguage? value) {
                          if (value == null) {
                            return;
                          }
                          setM(() {
                            draftLanguage = value;
                          });
                          setState(() {
                            _aiResponseLanguage = value;
                          });
                          unawaited(_savePreferences());
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: homeController,
                        onSubmitted: (String raw) async {
                          final String nextHome = _normalizeToUrl(raw);
                          setState(() {
                            _homePage = nextHome;
                          });
                          await _savePreferences();
                        },
                        decoration: const InputDecoration(
                          labelText: 'Home page',
                          hintText: 'https://example.com',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonal(
                          onPressed: () async {
                            final String nextHome = _normalizeToUrl(
                              homeController.text,
                            );
                            setState(() {
                              _homePage = nextHome;
                            });
                            await _savePreferences();
                            _showSnack('Home page updated');
                          },
                          child: const Text('Apply home page'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Accent color',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _accentChoices.map((choice) {
                          final bool selected =
                              draftAccent.toARGB32() == choice.color.toARGB32();
                          return InkWell(
                            borderRadius: BorderRadius.circular(30),
                            onTap: () {
                              setM(() {
                                draftAccent = choice.color;
                              });
                              widget.onAccentColorChanged(choice.color);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: selected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).dividerColor,
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: choice.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(choice.name),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Aggressive ad blocking'),
                        subtitle: const Text(
                          'Stronger ad filtering on heavy ad sites',
                        ),
                        value: draftAggressive,
                        onChanged: (bool value) {
                          setM(() {
                            draftAggressive = value;
                          });
                          setState(() {
                            _aggressiveAdBlock = value;
                          });
                          unawaited(_savePreferences());
                        },
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Attach page context to prompts'),
                        value: draftAttachContext,
                        onChanged: (bool value) {
                          setM(() {
                            draftAttachContext = value;
                          });
                          setState(() {
                            _attachPageContext = value;
                          });
                          unawaited(_savePreferences());
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          const Expanded(
                            child: Text(
                              'Changes are applied immediately.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    homeController.dispose();
  }

  void _showSnack(String message) {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    messenger?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}

String _themeModeToString(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
  }
}

ThemeMode _themeModeFromString(String value) {
  switch (value) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

enum _SearchEngine { google, duckduckgo, bing }

extension _SearchEngineX on _SearchEngine {
  String get key {
    switch (this) {
      case _SearchEngine.google:
        return 'google';
      case _SearchEngine.duckduckgo:
        return 'duckduckgo';
      case _SearchEngine.bing:
        return 'bing';
    }
  }

  String get label {
    switch (this) {
      case _SearchEngine.google:
        return 'Google';
      case _SearchEngine.duckduckgo:
        return 'DuckDuckGo';
      case _SearchEngine.bing:
        return 'Bing';
    }
  }

  Uri buildSearchUri(String query) {
    switch (this) {
      case _SearchEngine.google:
        return Uri.https('www.google.com', '/search', <String, String>{
          'q': query,
        });
      case _SearchEngine.duckduckgo:
        return Uri.https('duckduckgo.com', '/', <String, String>{'q': query});
      case _SearchEngine.bing:
        return Uri.https('www.bing.com', '/search', <String, String>{
          'q': query,
        });
    }
  }
}

_SearchEngine _searchEngineFromKey(String raw) {
  switch (raw) {
    case 'duckduckgo':
      return _SearchEngine.duckduckgo;
    case 'bing':
      return _SearchEngine.bing;
    default:
      return _SearchEngine.google;
  }
}

enum _AiResponseLanguage { auto, ukrainian, english, slovak }

extension _AiResponseLanguageX on _AiResponseLanguage {
  String get key {
    switch (this) {
      case _AiResponseLanguage.auto:
        return 'auto';
      case _AiResponseLanguage.ukrainian:
        return 'uk';
      case _AiResponseLanguage.english:
        return 'en';
      case _AiResponseLanguage.slovak:
        return 'sk';
    }
  }

  String get label {
    switch (this) {
      case _AiResponseLanguage.auto:
        return 'Auto';
      case _AiResponseLanguage.ukrainian:
        return 'Ukrainian';
      case _AiResponseLanguage.english:
        return 'English';
      case _AiResponseLanguage.slovak:
        return 'Slovak';
    }
  }

  String get systemInstruction {
    switch (this) {
      case _AiResponseLanguage.auto:
        return 'Reply in the same language as the user message.';
      case _AiResponseLanguage.ukrainian:
        return 'Always reply in Ukrainian.';
      case _AiResponseLanguage.english:
        return 'Always reply in English.';
      case _AiResponseLanguage.slovak:
        return 'Always reply in Slovak.';
    }
  }

  String? get speechLocaleId {
    switch (this) {
      case _AiResponseLanguage.ukrainian:
        return 'uk_UA';
      case _AiResponseLanguage.english:
        return 'en_US';
      case _AiResponseLanguage.slovak:
        return 'sk_SK';
      case _AiResponseLanguage.auto:
        return null;
    }
  }
}

_AiResponseLanguage _aiResponseLanguageFromKey(String raw) {
  switch (raw) {
    case 'uk':
      return _AiResponseLanguage.ukrainian;
    case 'en':
      return _AiResponseLanguage.english;
    case 'sk':
      return _AiResponseLanguage.slovak;
    default:
      return _AiResponseLanguage.auto;
  }
}

class _AccentChoice {
  const _AccentChoice(this.name, this.color);

  final String name;
  final Color color;
}

class _MobileTab {
  const _MobileTab({required this.title, required this.url});

  static _MobileTab? fromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final dynamic title = raw['title'];
    final dynamic url = raw['url'];
    if (title is! String || url is! String || url.trim().isEmpty) {
      return null;
    }
    return _MobileTab(
      title: title.trim().isEmpty ? 'Tab' : title.trim(),
      url: url.trim(),
    );
  }

  final String title;
  final String url;

  _MobileTab copyWith({String? title, String? url}) {
    return _MobileTab(title: title ?? this.title, url: url ?? this.url);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'title': title,
    'url': url,
  };
}

class _HistoryEntry {
  const _HistoryEntry({required this.title, required this.url});

  static _HistoryEntry? fromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final dynamic title = raw['title'];
    final dynamic url = raw['url'];
    if (title is! String || url is! String || url.trim().isEmpty) {
      return null;
    }
    return _HistoryEntry(
      title: title.trim().isEmpty ? url.trim() : title.trim(),
      url: url.trim(),
    );
  }

  final String title;
  final String url;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'title': title,
    'url': url,
  };
}

class _SavedSite {
  const _SavedSite({
    required this.title,
    required this.url,
    required this.savedAtMillis,
  });

  static _SavedSite? fromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final dynamic title = raw['title'];
    final dynamic url = raw['url'];
    final dynamic savedAtMillis = raw['savedAtMillis'];
    if (title is! String || url is! String || url.trim().isEmpty) {
      return null;
    }
    final int parsedSavedAt = savedAtMillis is int
        ? savedAtMillis
        : int.tryParse(savedAtMillis?.toString() ?? '') ?? 0;
    return _SavedSite(
      title: title.trim().isEmpty ? url.trim() : title.trim(),
      url: url.trim(),
      savedAtMillis: parsedSavedAt,
    );
  }

  final String title;
  final String url;
  final int savedAtMillis;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'title': title,
    'url': url,
    'savedAtMillis': savedAtMillis,
  };
}

class _AiSession {
  const _AiSession({
    required this.id,
    required this.title,
    required this.updatedAtMillis,
    required this.messages,
  });

  static _AiSession? fromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final dynamic id = raw['id'];
    final dynamic title = raw['title'];
    final dynamic updatedAtMillis = raw['updatedAtMillis'];
    final dynamic messages = raw['messages'];
    if (id is! String ||
        id.trim().isEmpty ||
        title is! String ||
        messages is! List) {
      return null;
    }
    final List<_ChatMessage> parsedMessages = messages
        .map<_ChatMessage?>((dynamic item) => _ChatMessage.fromJson(item))
        .whereType<_ChatMessage>()
        .toList();
    if (parsedMessages.isEmpty) {
      return null;
    }
    final int parsedUpdatedAt = updatedAtMillis is int
        ? updatedAtMillis
        : int.tryParse(updatedAtMillis?.toString() ?? '') ?? 0;
    return _AiSession(
      id: id.trim(),
      title: title.trim().isEmpty ? 'New chat' : title.trim(),
      updatedAtMillis: parsedUpdatedAt,
      messages: parsedMessages,
    );
  }

  final String id;
  final String title;
  final int updatedAtMillis;
  final List<_ChatMessage> messages;

  _AiSession copyWith({
    String? title,
    int? updatedAtMillis,
    List<_ChatMessage>? messages,
  }) {
    return _AiSession(
      id: id,
      title: title ?? this.title,
      updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
      messages: messages ?? this.messages,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'updatedAtMillis': updatedAtMillis,
    'messages': messages.map((m) => m.toJson()).toList(growable: false),
  };
}

class _DockIconButton extends StatelessWidget {
  const _DockIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badge,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final Widget button = IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      tooltip: tooltip,
    );
    if (badge == null) {
      return button;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        button,
        Positioned(
          right: 2,
          top: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              badge!,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _ChatRole { user, assistant }

class _ChatMessage {
  const _ChatMessage({required this.role, required this.text});

  static _ChatMessage? fromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final dynamic roleRaw = raw['role'];
    final dynamic textRaw = raw['text'];
    if (roleRaw is! String || textRaw is! String) {
      return null;
    }
    final _ChatRole role = roleRaw == 'assistant'
        ? _ChatRole.assistant
        : _ChatRole.user;
    final String text = textRaw.trim();
    if (text.isEmpty) {
      return null;
    }
    return _ChatMessage(role: role, text: text);
  }

  factory _ChatMessage.user(String text) {
    return _ChatMessage(role: _ChatRole.user, text: text);
  }

  factory _ChatMessage.assistant(String text) {
    return _ChatMessage(role: _ChatRole.assistant, text: text);
  }

  final _ChatRole role;
  final String text;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'role': role == _ChatRole.assistant ? 'assistant' : 'user',
    'text': text,
  };
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final bool isUser = message.role == _ChatRole.user;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isUser ? colors.primary : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(
              message.text,
              style: TextStyle(
                color: isUser ? colors.onPrimary : colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThinkingMessage extends StatefulWidget {
  const _ThinkingMessage();

  @override
  State<_ThinkingMessage> createState() => _ThinkingMessageState();
}

class _ThinkingMessageState extends State<_ThinkingMessage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 900),
    vsync: this,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              RotationTransition(
                turns: _controller,
                child: Icon(
                  Icons.autorenew_rounded,
                  size: 18,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 8),
              const Text('Thinking...'),
            ],
          ),
        ),
      ),
    );
  }
}
