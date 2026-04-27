import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/gemini_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          child: Consumer<SettingsService>(
            builder: (context, settings, child) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Settings', style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 12),

                  // Model Selection
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI Model',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
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

                  // Theme Toggle
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Dark Mode', style: TextStyle(fontSize: 12)),
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

                  // Language Selection
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Language', style: TextStyle(fontSize: 12)),
                        DropdownButton<String>(
                          value: settings.language,
                          underline: const SizedBox(),
                          isDense: true,
                          style: const TextStyle(fontSize: 12),
                          items:
                              [
                                {'code': 'en', 'name': 'EN'},
                                {'code': 'uk', 'name': 'UA'},
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

                  // Back Button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Back', style: TextStyle(fontSize: 12)),
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
          border: isSelected
              ? Border.all(color: Colors.blue.shade400.withOpacity(0.5))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 16,
              color: isSelected ? Colors.blue : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
