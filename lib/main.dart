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

  final List<_ChatMessage> _chat = <_ChatMessage>[
    _ChatMessage.assistant(
      'Hi! I am OleksandrAi in Olewser. Open a page and ask anything.',
    ),
  ];

  final List<_MobileTab> _tabs = <_MobileTab>[
    const _MobileTab(title: 'New tab', url: _defaultHomePage),
  ];
  final List<_HistoryEntry> _history = <_HistoryEntry>[];

  bool _pageLoading = true;
  bool _thinking = false;
  bool _prefsLoaded = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _speechReady = false;
  bool _listening = false;
  bool _panelVisible = true;
  bool _panelVisibleDefault = true;
  bool _aggressiveAdBlock = true;
  bool _attachPageContext = true;

  int _activeTabIndex = 0;
  String _currentUrl = _defaultHomePage;
  String _homePage = _defaultHomePage;
  _SearchEngine _searchEngine = _SearchEngine.google;
  AiModel _selectedModel = AiModel.pro;

  Uri? _pendingIncomingUri;
  bool _manualStopRequested = false;

  @override
  void initState() {
    super.initState();
    _configureWebView();
    _initializeSpeech();
    _initializeIncomingLinks();
    _loadPreferencesAndStart();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _urlController.dispose();
    _promptController.dispose();
    _urlFocusNode.dispose();
    _promptFocusNode.dispose();
    _speech.stop();
    _aiService.dispose();
    super.dispose();
  }

  _MobileTab get _activeTab => _tabs[_activeTabIndex];

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
        prefs.getBool(_prefPanelVisibleDefault) ?? true;
    final bool savedAttachContext =
        prefs.getBool(_prefAttachPageContext) ?? true;

    if (!mounted) {
      return;
    }

    final String normalizedHome = _normalizeToUrl(savedHome);
    setState(() {
      _homePage = normalizedHome;
      _searchEngine = _searchEngineFromKey(savedEngine);
      _aggressiveAdBlock = savedAggressive;
      _panelVisibleDefault = savedPanelDefault;
      _panelVisible = savedPanelDefault;
      _attachPageContext = savedAttachContext;
      _prefsLoaded = true;
      _currentUrl = normalizedHome;
      _urlController.text = normalizedHome;
      _tabs[0] = _tabs[0].copyWith(url: normalizedHome);
    });

    await _loadUrlIntoCurrent(Uri.parse(normalizedHome));

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
  }

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
      appBar: AppBar(titleSpacing: 12, title: const Text('Olewser')),
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

  Widget _buildBottomDock() {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Material(
        elevation: 12,
        color: colors.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
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
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _DockIconButton(
                    icon: Icons.arrow_upward,
                    tooltip: 'Go',
                    onPressed: _openTypedInput,
                  ),
                  _DockIconButton(
                    icon: Icons.refresh,
                    tooltip: 'Reload',
                    onPressed: () async {
                      await _webViewController.reload();
                      await _refreshNavigationControls();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  _DockIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onPressed: _canGoBack
                        ? () async {
                            await _webViewController.goBack();
                            await _refreshNavigationControls();
                          }
                        : null,
                  ),
                  _DockIconButton(
                    icon: Icons.arrow_forward_rounded,
                    tooltip: 'Forward',
                    onPressed: _canGoForward
                        ? () async {
                            await _webViewController.goForward();
                            await _refreshNavigationControls();
                          }
                        : null,
                  ),
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
                    icon: Icons.add_circle_outline,
                    tooltip: '+ Widgets',
                    onPressed: _openWidgetsSheet,
                  ),
                  const Spacer(),
                  _DockIconButton(
                    icon: Icons.settings_outlined,
                    tooltip: 'Settings',
                    onPressed: _openSettingsSheet,
                  ),
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _panelVisible = !_panelVisible;
                      });
                    },
                    icon: Icon(
                      _panelVisible
                          ? Icons.smart_toy
                          : Icons.smart_toy_outlined,
                    ),
                    label: const Text('OleksandrAi'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiPanel() {
    final Size size = MediaQuery.sizeOf(context);
    final double panelWidth = size.width < 460 ? size.width - 16 : 440;
    final double panelHeight = size.height < 760 ? 360 : 430;

    return Positioned(
      right: 8,
      left: size.width < 460 ? 8 : null,
      bottom: 112,
      width: size.width < 460 ? null : panelWidth,
      height: panelHeight,
      child: Card(
        elevation: 18,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12),
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
                    onPressed: _thinking ? null : _analyzeOpenPage,
                    icon: const Icon(Icons.public),
                    tooltip: 'Analyze open page',
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
                              child: Text(
                                '${model.label} - ${model.remoteModel}',
                                overflow: TextOverflow.ellipsis,
                              ),
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
                    child: const Text('New chat'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: _thinking ? null : _summarizeOpenPage,
                    icon: const Icon(Icons.summarize_outlined, size: 16),
                    label: const Text('Summarize'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _thinking ? null : _extractPageKeyPoints,
                    icon: const Icon(Icons.checklist_rounded, size: 16),
                    label: const Text('Key points'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _thinking ? null : _translateOpenPageToUkrainian,
                    icon: const Icon(Icons.translate_rounded, size: 16),
                    label: const Text('Translate UA'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(10),
                    itemCount: _chat.length + (_thinking ? 1 : 0),
                    separatorBuilder: (_, int index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (BuildContext context, int index) {
                      if (_thinking && index == _chat.length) {
                        return _ThinkingMessage(
                          modelLabel: _selectedModel.label,
                        );
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
                  IconButton.filledTonal(
                    onPressed: _speechReady ? _togglePromptVoiceInput : null,
                    icon: Icon(
                      _listening ? Icons.mic_off : Icons.mic_none_rounded,
                    ),
                    tooltip: _listening ? 'Stop voice input' : 'Voice input',
                  ),
                  const SizedBox(width: 4),
                  if (_thinking)
                    IconButton.filledTonal(
                      onPressed: _stopGeneration,
                      icon: const Icon(Icons.stop_rounded),
                      tooltip: 'Stop generation',
                    ),
                  if (_thinking) const SizedBox(width: 4),
                  IconButton.filled(
                    onPressed: _thinking ? null : _sendPrompt,
                    icon: const Icon(Icons.send),
                    tooltip: 'Send',
                  ),
                ],
              ),
            ],
          ),
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
    await _loadUrlIntoCurrent(Uri.parse(target));
  }

  Future<void> _switchTab(int index) async {
    if (index < 0 || index >= _tabs.length) {
      return;
    }
    setState(() {
      _activeTabIndex = index;
    });
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
                      trailing: _tabs.length > 1
                          ? IconButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _closeTab(index);
                              },
                              icon: const Icon(Icons.close),
                            )
                          : null,
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
                leading: const Icon(Icons.analytics_outlined),
                title: const Text('Analyze open page'),
                onTap: () {
                  Navigator.of(context).pop();
                  _analyzeOpenPage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.summarize_outlined),
                title: const Text('Summarize open page'),
                onTap: () {
                  Navigator.of(context).pop();
                  _summarizeOpenPage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.translate_rounded),
                title: const Text('Translate page to Ukrainian'),
                onTap: () {
                  Navigator.of(context).pop();
                  _translateOpenPageToUkrainian();
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
              ListTile(
                leading: Icon(
                  _panelVisible ? Icons.smart_toy : Icons.smart_toy_outlined,
                ),
                title: Text(
                  _panelVisible
                      ? 'Hide OleksandrAi panel'
                      : 'Show OleksandrAi panel',
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _panelVisible = !_panelVisible;
                  });
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
  }

  Future<void> _sendPrompt({
    String? promptOverride,
    String? userVisibleText,
    bool includePageContext = true,
  }) async {
    String prompt = (promptOverride ?? _promptController.text).trim();
    if (prompt.isEmpty || _thinking) {
      return;
    }

    if (includePageContext && _attachPageContext && promptOverride == null) {
      final String pageContext = await _collectPageContextSnippet();
      prompt = '$prompt\n\nCurrent page context:\n$pageContext';
    }

    _manualStopRequested = false;
    setState(() {
      _thinking = true;
      _chat.add(_ChatMessage.user(userVisibleText ?? prompt));
      if (promptOverride == null) {
        _promptController.clear();
      }
    });

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
      const AiChatMessage(
        role: 'system',
        content:
            'You are OleksandrAi inside Olewser browser. Reply clearly and concise.',
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
    } on AiRequestCanceledException {
      if (!mounted) {
        return;
      }
      if (!_manualStopRequested) {
        setState(() {
          _chat.add(_ChatMessage.assistant('Generation stopped.'));
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _chat.add(_ChatMessage.assistant('AI error: $error'));
      });
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
    setState(() {
      _chat
        ..clear()
        ..add(
          _ChatMessage.assistant(
            'New chat ready. Open page, choose model and send prompt.',
          ),
        );
    });
  }

  Future<void> _openSettingsSheet() async {
    final TextEditingController homeController = TextEditingController(
      text: _homePage,
    );
    ThemeMode draftTheme = widget.currentThemeMode;
    _SearchEngine draftEngine = _searchEngine;
    bool draftAggressive = _aggressiveAdBlock;
    bool draftPanelDefault = _panelVisibleDefault;
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
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: homeController,
                        decoration: const InputDecoration(
                          labelText: 'Home page',
                          hintText: 'https://example.com',
                          border: OutlineInputBorder(),
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
                        },
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Show OleksandrAi panel on start'),
                        value: draftPanelDefault,
                        onChanged: (bool value) {
                          setM(() {
                            draftPanelDefault = value;
                          });
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
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                final String nextHome = _normalizeToUrl(
                                  homeController.text,
                                );
                                setState(() {
                                  _homePage = nextHome;
                                  _searchEngine = draftEngine;
                                  _aggressiveAdBlock = draftAggressive;
                                  _panelVisibleDefault = draftPanelDefault;
                                  _attachPageContext = draftAttachContext;
                                });
                                widget.onThemeModeChanged(draftTheme);
                                widget.onAccentColorChanged(draftAccent);
                                await _savePreferences();
                                if (mounted) {
                                  Navigator.of(context).pop();
                                  _showSnack('Settings saved');
                                }
                              },
                              child: const Text('Save'),
                            ),
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

class _AccentChoice {
  const _AccentChoice(this.name, this.color);

  final String name;
  final Color color;
}

class _MobileTab {
  const _MobileTab({required this.title, required this.url});

  final String title;
  final String url;

  _MobileTab copyWith({String? title, String? url}) {
    return _MobileTab(title: title ?? this.title, url: url ?? this.url);
  }
}

class _HistoryEntry {
  const _HistoryEntry({required this.title, required this.url});

  final String title;
  final String url;
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

  factory _ChatMessage.user(String text) {
    return _ChatMessage(role: _ChatRole.user, text: text);
  }

  factory _ChatMessage.assistant(String text) {
    return _ChatMessage(role: _ChatRole.assistant, text: text);
  }

  final _ChatRole role;
  final String text;
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
  const _ThinkingMessage({required this.modelLabel});

  final String modelLabel;

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
              Text('Thinking (${widget.modelLabel})...'),
            ],
          ),
        ),
      ),
    );
  }
}
