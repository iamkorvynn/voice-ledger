// Optional Gemini-powered parsing.
//
// Only used when the user has entered their own Gemini API key in Settings.
// Without a key this service is never called and the on-device parser is
// used instead. A Gemini result is still shown for confirmation before
// saving — it is never trusted blindly, and a failure always falls back to
// the on-device parser with an honest message.

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/expense.dart';
import 'expense_parser.dart';

class GeminiService {
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-2.0-flash:generateContent';

  /// Ask Gemini to parse spoken expense text. Returns null on any failure
  /// (no network, bad key, bad response) so the caller can fall back.
  Future<ParsedExpense?> parseWithGemini(String text, String apiKey) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_endpoint?key=$apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {
                      'text':
                          'Parse this spoken expense into JSON with keys '
                          '"amount" (number or null), "category" (one of: '
                          'food, travel, shopping, bills, entertainment, '
                          'health, education, other), "note" (short note). '
                          'Reply with JSON only, no markdown. Text: "$text"',
                    },
                  ],
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) return null;
      final parts =
          candidates[0]['content']['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) return null;
      var raw = (parts[0]['text'] as String).trim();
      // Strip markdown code fences if the model added them.
      raw = raw.replaceAll('```json', '').replaceAll('```', '').trim();
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      final amountRaw = parsed['amount'];
      final amount = amountRaw is num ? amountRaw.toDouble() : null;
      final category = ExpenseCategoryX.fromName(
        (parsed['category'] as String? ?? 'other').toLowerCase(),
      );
      return ParsedExpense(
        amount: amount,
        category: category,
        note: (parsed['note'] as String? ?? text).trim(),
      );
    } catch (_) {
      return null;
    }
  }
}
