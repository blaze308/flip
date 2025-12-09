import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_providers.dart';
import '../widgets/custom_toaster.dart';

/// Language Settings Screen
/// Select preferred language
class LanguageSettingsScreen extends ConsumerStatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  ConsumerState<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends ConsumerState<LanguageSettingsScreen> {
  final List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English', 'nativeName': 'English'},
    {'code': 'es', 'name': 'Spanish', 'nativeName': 'Español'},
    {'code': 'fr', 'name': 'French', 'nativeName': 'Français'},
    {'code': 'de', 'name': 'German', 'nativeName': 'Deutsch'},
    {'code': 'it', 'name': 'Italian', 'nativeName': 'Italiano'},
    {'code': 'pt', 'name': 'Portuguese', 'nativeName': 'Português'},
    {'code': 'ru', 'name': 'Russian', 'nativeName': 'Русский'},
    {'code': 'zh', 'name': 'Chinese', 'nativeName': '中文'},
    {'code': 'ja', 'name': 'Japanese', 'nativeName': '日本語'},
    {'code': 'ko', 'name': 'Korean', 'nativeName': '한국어'},
    {'code': 'ar', 'name': 'Arabic', 'nativeName': 'العربية'},
    {'code': 'hi', 'name': 'Hindi', 'nativeName': 'हिन्दी'},
  ];

  @override
  Widget build(BuildContext context) {
    final languageAsync = ref.watch(languageSettingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          'Language',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1D1E33),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: languageAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error: $error',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        data: (selectedLanguage) {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _languages.length,
            itemBuilder: (context, index) {
              final language = _languages[index];
              final isSelected = language['code'] == selectedLanguage;

              return Card(
                color: const Color(0xFF1D1E33),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    Icons.language,
                    color: isSelected ? const Color(0xFF4ECDC4) : Colors.white70,
                  ),
                  title: Text(
                    language['name']!,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF4ECDC4) : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    language['nativeName']!,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Color(0xFF4ECDC4))
                      : null,
                  onTap: () async {
                    final result = await ref.read(languageSettingsProvider.notifier).updateLanguage(
                          language['code']!,
                        );

                    if (mounted) {
                      if (result['success'] == true) {
                        ToasterService.showSuccess(context, 'Language updated to ${language['name']}');
                      } else {
                        ToasterService.showError(context, result['message'] ?? 'Failed to update language');
                      }
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

