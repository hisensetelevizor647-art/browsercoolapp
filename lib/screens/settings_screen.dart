import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_localizer.dart';
import '../services/gemini_service.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
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
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.aiModel,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
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

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.25),
                      ),
                    ),
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

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.25),
                      ),
                    ),
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
    );
  }

  Widget _buildModelOption(
    BuildContext context,
    SettingsService settings,
    String value,
    String label,
  ) {
    final theme = Theme.of(context);
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
          color: isSelected
              ? Colors.blue.shade400.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Colors.blue.shade400.withOpacity(0.5)
                : theme.colorScheme.outline.withOpacity(0.15),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 16,
              color: isSelected
                  ? Colors.blue
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
