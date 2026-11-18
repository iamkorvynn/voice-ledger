// On-device settings: Gemini API key and first-run onboarding flag.
// The key is stored only in the app's private SharedPreferences on the
// device. It is never sent anywhere except to Google's Gemini API when the
// user asks for a smarter parse, and never written to the repo.

import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _geminiKeyKey = 'gemini_api_key';
  static const _onboardingDoneKey = 'onboarding_done';

  Future<String?> getGeminiApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_geminiKeyKey);
    if (key == null || key.trim().isEmpty) return null;
    return key.trim();
  }

  Future<void> setGeminiApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key.trim().isEmpty) {
      await prefs.remove(_geminiKeyKey);
    } else {
      await prefs.setString(_geminiKeyKey, key.trim());
    }
  }

  Future<bool> get hasGeminiKey async => await getGeminiApiKey() != null;

  Future<bool> get onboardingDone async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingDoneKey) ?? false;
  }

  Future<void> setOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingDoneKey, true);
  }
}
