import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_localizer.dart';
import '../services/gemini_service.dart';
import '../services/settings_service.dart';
import '../services/watch_assistant_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  dynamic _accentColor(ThemeData theme) => theme.colorScheme.primary;

  dynamic _accentAltColor(ThemeData theme) => theme.colorScheme.secondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assistantBridge = WatchAssistantService();
    final accent = _accentColor(theme);
    final accentAlt = _accentAltColor(theme);
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
                    Colors.yellow.shade600.withOpacity(isDark ? 0.24 : 0.16),
                    Colors.green.shade500.withOpacity(isDark ? 0.3 : 0.2),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -88,
                    right: -44,
                    child: _buildGlow(
                      accent.withOpacity(isDark ? 0.28 : 0.2),
                      210,
                    ),
                  ),
                  Positioned(
                    bottom: -92,
                    left: -48,
                    child: _buildGlow(
                      accentAlt.withOpacity(isDark ? 0.24 : 0.16),
                      220,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
              child: Consumer<SettingsService>(
                builder: (context, settings, child) {
                  final l10n = AppLocalizer.fromCode(settings.language);
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.settings,
                        style: TextStyle(
                          fontSize: 14,
                          color: accent.withOpacity(0.9),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSectionCard(
                        theme,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.aiModel,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.72,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...SettingsService.availableModels.map((model) {
                              return _buildModelOption(
                                context,
                                settings,
                                model['id']!,
                                model['name']!,
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSectionCard(
                        theme,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.darkMode,
                              style: const TextStyle(fontSize: 12),
                            ),
                            Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                value: settings.themeMode == ThemeMode.dark,
                                onChanged: (val) {
                                  settings.setThemeMode(
                                    val ? ThemeMode.dark : ThemeMode.light,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSectionCard(
                        theme,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.language,
                              style: const TextStyle(fontSize: 12),
                            ),
                            DropdownButton<String>(
                              value: settings.language,
                              underline: const SizedBox(),
                              isDense: true,
                              style: const TextStyle(fontSize: 12),
                              items:
                                  [
                                    {'code': 'en', 'name': 'EN'},
                                    {'code': 'uk', 'name': 'UK'},
                                    {'code': 'sk', 'name': 'SK'},
                                  ].map((lang) {
                                    return DropdownMenuItem<String>(
                                      value: lang['code'],
                                      child: Text(lang['name']!),
                                    );
                                  }).toList(),
                              onChanged: (newValue) {
                                if (newValue != null) {
                                  settings.setLanguage(newValue);
                                  Provider.of<GeminiService>(
                                    context,
                                    listen: false,
                                  ).updateLanguage(newValue);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSectionCard(
                        theme,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.setDefaultAssistant,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.72,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () async {
                                  final opened = await assistantBridge
                                      .openAssistantSettings();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        opened
                                            ? l10n.assistantSettingsOpened
                                            : l10n.assistantSettingsUnavailable,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.assistant_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  l10n.open,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: Text(
                            l10n.back,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(ThemeData theme, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface.withOpacity(0.96),
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.36),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.24)),
        boxShadow: [
          BoxShadow(color: theme.shadowColor.withOpacity(0.14), blurRadius: 10),
        ],
      ),
      child: child,
    );
  }

  Widget _buildGlow(dynamic color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color, blurRadius: size * 0.35, spreadRadius: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildModelOption(
    BuildContext context,
    SettingsService settings,
    String value,
    String label,
  ) {
    final theme = Theme.of(context);
    final accent = _accentColor(theme);
    final isSelected = settings.model == value;

    return GestureDetector(
      onTap: () {
        settings.setModel(value);
        Provider.of<GeminiService>(context, listen: false).updateModel(value);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    accent.withOpacity(0.26),
                    _accentAltColor(theme).withOpacity(0.18),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? accent.withOpacity(0.58)
                : theme.colorScheme.outline.withOpacity(0.15),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 16,
              color: isSelected
                  ? accent
                  : theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
