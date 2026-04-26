import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'src/ai/ai_service.dart';
import 'src/ai/model_catalog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OlewserApp());
}

class OlewserApp extends StatelessWidget {
  const OlewserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Olewser Android',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3366FF)),
        useMaterial3: true,
      ),
      home: const BrowserHomePage(),
    );
  }
}

class BrowserHomePage extends StatefulWidget {
  const BrowserHomePage({super.key});

  @override
  State<BrowserHomePage> createState() => _BrowserHomePageState();
}

class _BrowserHomePageState extends State<BrowserHomePage> {
  static const String _initialUrl = 'https://www.google.com';
  static const List<String> _blockedHostParts = <String>[
    'doubleclick.net',
    'googlesyndication.com',
    'googleadservices.com',
    'adservice.google.',
    'adnxs.com',
    'taboola.com',
    'outbrain.com',
    'mgid.com',
    'popads.',
    'propellerads.',
    'adsterra.',
    'trafficjunky.',
    'adskeeper.',
    'banner.',
    'ads.',
  ];

  late final WebViewController _webViewController;
  final AiService _aiService = AiService();
  final TextEditingController _urlController = TextEditingController(
    text: _initialUrl,
  );
  final TextEditingController _promptController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  final FocusNode _promptFocusNode = FocusNode();
  final List<_ChatMessage> _chat = <_ChatMessage>[
    _ChatMessage.assistant(
      'Привіт! Я OleksandrAI в Olewser Android. Відкрий сторінку і пиши, що зробити.',
    ),
  ];

  bool _pageLoading = true;
  bool _thinking = false;
  bool _panelVisible = true;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String _currentUrl = _initialUrl;
  AiModel _selectedModel = AiModel.pro;
  Offset _panelOffset = const Offset(12, 110);

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            if (_isBlockedRequest(request.url)) {
              _showSnack('Blocked ad/tracker request');
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (String url) {
            setState(() {
              _pageLoading = true;
              _currentUrl = url;
              _urlController.text = url;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _pageLoading = false;
              _currentUrl = url;
              _urlController.text = url;
            });
            _refreshNavigationControls();
          },
        ),
      )
      ..loadRequest(Uri.parse(_initialUrl));
  }

  @override
  void dispose() {
    _urlController.dispose();
    _promptController.dispose();
    _urlFocusNode.dispose();
    _promptFocusNode.dispose();
    _aiService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Olewser Android'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Analyze open page',
            onPressed: _thinking ? null : _analyzeOpenPage,
            icon: const Icon(Icons.analytics_outlined),
          ),
          IconButton(
            tooltip: _panelVisible ? 'Hide AI panel' : 'Show AI panel',
            onPressed: () {
              setState(() {
                _panelVisible = !_panelVisible;
              });
            },
            icon: Icon(
              _panelVisible ? Icons.smart_toy : Icons.smart_toy_outlined,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _buildAddressBar(),
            Expanded(
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
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            _panelVisible = !_panelVisible;
          });
        },
        icon: Icon(_panelVisible ? Icons.close : Icons.chat_bubble_outline),
        label: Text(_panelVisible ? 'Hide AI' : 'Show AI'),
      ),
    );
  }

  Widget _buildAddressBar() {
    return Material(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        child: Row(
          children: <Widget>[
            IconButton(
              onPressed: _canGoBack
                  ? () async {
                      await _webViewController.goBack();
                      await _refreshNavigationControls();
                    }
                  : null,
              icon: const Icon(Icons.arrow_back),
            ),
            IconButton(
              onPressed: _canGoForward
                  ? () async {
                      await _webViewController.goForward();
                      await _refreshNavigationControls();
                    }
                  : null,
              icon: const Icon(Icons.arrow_forward),
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
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
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
            IconButton(
              onPressed: _openTypedInput,
              icon: const Icon(Icons.arrow_upward),
              tooltip: 'Go',
            ),
            IconButton(
              onPressed: () async {
                await _webViewController.reload();
                await _refreshNavigationControls();
              },
              icon: const Icon(Icons.refresh),
              tooltip: 'Reload',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiPanel() {
    final Size size = MediaQuery.sizeOf(context);
    final double panelWidth = size.width < 420 ? size.width - 24 : 380;
    final double panelHeight = size.height < 760 ? 360 : 420;
    final double maxLeft = (size.width - panelWidth - 12)
        .clamp(12, double.infinity)
        .toDouble();
    final double maxTop = (size.height - panelHeight - 24)
        .clamp(90, double.infinity)
        .toDouble();
    final double left = _panelOffset.dx.clamp(12, maxLeft).toDouble();
    final double top = _panelOffset.dy.clamp(90, maxTop).toDouble();

    if (left != _panelOffset.dx || top != _panelOffset.dy) {
      _panelOffset = Offset(left, top);
    }

    return Positioned(
      left: left,
      top: top,
      width: panelWidth,
      height: panelHeight,
      child: GestureDetector(
        onPanUpdate: (DragUpdateDetails details) {
          setState(() {
            _panelOffset = Offset(
              (_panelOffset.dx + details.delta.dx)
                  .clamp(12, maxLeft)
                  .toDouble(),
              (_panelOffset.dy + details.delta.dy).clamp(90, maxTop).toDouble(),
            );
          });
        },
        child: Card(
          elevation: 12,
          color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.open_with),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'OleksandrAI',
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
                      onPressed: _newChat,
                      child: const Text('New'),
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
                      separatorBuilder: (_, _unused) =>
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
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _promptController,
                        focusNode: _promptFocusNode,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendPrompt(),
                        decoration: const InputDecoration(
                          hintText: 'Type a prompt...',
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
                      onPressed: _thinking ? null : _sendPrompt,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ],
            ),
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

  bool _isBlockedRequest(String rawUrl) {
    final Uri? uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return false;
    }

    final String host = uri.host.toLowerCase();
    if (host.isEmpty) {
      return false;
    }

    return _blockedHostParts.any(host.contains);
  }

  Future<void> _openTypedInput() async {
    final String rawInput = _urlController.text.trim();
    if (rawInput.isEmpty) {
      return;
    }

    _urlFocusNode.unfocus();
    final Uri uri = _normalizeToUri(rawInput);
    await _webViewController.loadRequest(uri);
    await _refreshNavigationControls();
  }

  Uri _normalizeToUri(String input) {
    final bool hasScheme =
        input.startsWith('http://') || input.startsWith('https://');
    if (hasScheme) {
      return Uri.parse(input);
    }

    if (input.contains(' ') || !input.contains('.')) {
      return Uri.https('www.google.com', '/search', <String, String>{
        'q': input,
      });
    }

    return Uri.parse('https://$input');
  }

  Future<void> _analyzeOpenPage() async {
    _promptFocusNode.unfocus();

    final String title = (await _webViewController.getTitle())?.trim() ?? '';
    final dynamic rawBody = await _webViewController
        .runJavaScriptReturningResult('''
      (() => {
        const text = document.body?.innerText ?? '';
        return JSON.stringify(text.slice(0, 3000));
      })();
      ''');

    final String bodyText = _decodeJsString(rawBody);
    final String prompt =
        '''
Analyze the currently open browser page.
URL: $_currentUrl
Title: ${title.isEmpty ? 'Unknown title' : title}
Visible content excerpt:
$bodyText

Give a short summary and then key actions I can do next.
''';

    await _sendPrompt(
      promptOverride: prompt,
      userVisibleText: 'Analyze open page',
    );
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

  Future<void> _sendPrompt({
    String? promptOverride,
    String? userVisibleText,
  }) async {
    final String prompt = (promptOverride ?? _promptController.text).trim();
    if (prompt.isEmpty || _thinking) {
      return;
    }

    setState(() {
      _thinking = true;
      _chat.add(_ChatMessage.user(userVisibleText ?? prompt));
      if (promptOverride == null) {
        _promptController.clear();
      }
    });

    final List<AiChatMessage> messages = <AiChatMessage>[
      const AiChatMessage(
        role: 'system',
        content:
            'You are OleksandrAI inside Olewser Android browser. Reply clearly and concisely. '
            'If user asks about an open page, use supplied page context.',
      ),
      ..._chat.map(
        (_ChatMessage message) => AiChatMessage(
          role: message.role == _ChatRole.user ? 'user' : 'assistant',
          content: message.text,
        ),
      ),
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
            'New chat ready. Open a page or type your prompt.',
          ),
        );
    });
  }

  void _showSnack(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
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
        constraints: const BoxConstraints(maxWidth: 280),
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
              Text('Thinking with ${widget.modelLabel}...'),
            ],
          ),
        ),
      ),
    );
  }
}
