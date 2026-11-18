// On-device expense parser.
//
// Works fully offline: no network, no API key needed. It extracts an amount
// (digits, including "Rs 200", "200 rupees", "₹200", decimals and commas,
// plus Indian number words like "two hundred" as a bonus) and a category
// from keyword matching. Anything it cannot recognise falls back honestly:
// no amount -> [ParsedExpense.amount] is null, unknown category -> other.
//
// The parser never invents data. Callers must ask the user to confirm or
// correct the parsed result before saving.

import '../models/expense.dart';

class ParsedExpense {
  final double? amount;
  final ExpenseCategory category;
  final String note;
  final bool amountFromWords;

  const ParsedExpense({
    required this.amount,
    required this.category,
    required this.note,
    this.amountFromWords = false,
  });
}

class ExpenseParser {
  static const _categoryKeywords = <ExpenseCategory, List<String>>{
    ExpenseCategory.food: [
      'lunch', 'dinner', 'breakfast', 'food', 'meal', 'restaurant', 'cafe',
      'coffee', 'tea', 'chai', 'snack', 'snacks', 'pizza', 'burger', 'grocery',
      'groceries', 'vegetable', 'vegetables', 'fruit', 'fruits', 'milk',
      'bread', 'breakfast', 'brunch', 'canteen', 'mess', 'tiffin', 'biryani',
      'sandwich', 'juice', 'samosa', 'dosa', 'thali', 'swiggy', 'zomato',
      'eating', 'ate', 'ordered food', 'takeaway',
    ],
    ExpenseCategory.travel: [
      'petrol', 'diesel', 'fuel', 'taxi', 'cab', 'uber', 'ola', 'auto',
      'rickshaw', 'bus', 'train', 'metro', 'flight', 'ticket', 'tickets',
      'travel', 'trip', 'toll', 'parking', 'fare', 'railway', 'airfare',
      'hotel', 'stay', 'petrol pump', 'fastag',
    ],
    ExpenseCategory.shopping: [
      'shopping', 'clothes', 'shirt', 'shoes', 'dress', 'jeans', 'amazon',
      'flipkart', 'bought', 'purchase', 'purchased', 'mobile', 'phone',
      'laptop', 'gadget', 'watch', 'bag', 'gift', 'gifts', 'stationery',
      'book', 'books', 'furniture', 'online shopping', 'mall',
    ],
    ExpenseCategory.bills: [
      'bill', 'bills', 'electricity', 'water', 'rent', 'recharge', 'mobile bill',
      'internet', 'wifi', 'broadband', 'gas', 'cylinder', 'emi', 'loan',
      'insurance', 'premium', 'subscription', 'netflix', 'spotify',
      'electricity bill', 'maintenance', 'society',
    ],
    ExpenseCategory.entertainment: [
      'movie', 'movies', 'cinema', 'entertainment', 'game', 'games', 'gaming',
      'concert', 'show', 'party', 'outing', 'bowling', 'arcade',
      'streaming', 'youtube premium', 'match', 'cricket',
    ],
    ExpenseCategory.health: [
      'doctor', 'hospital', 'medicine', 'medicines', 'pharmacy', 'clinic',
      'health', 'gym', 'fitness', 'treatment', 'dentist', 'checkup', 'test',
      'lab', 'prescription', 'vitamins', 'salon', 'haircut',
    ],
    ExpenseCategory.education: [
      'course', 'tuition', 'fees', 'fee', 'college', 'school', 'exam',
      'education', 'class', 'classes', 'coaching', 'udemy', 'coursera',
      'notes', 'admission', 'library', 'textbook',
    ],
  };

  static const _ones = <String, int>{
    'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
    'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
    'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14,
    'fifteen': 15, 'sixteen': 16, 'seventeen': 17, 'eighteen': 18,
    'nineteen': 19,
  };

  static const _tens = <String, int>{
    'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50,
    'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90,
  };

  /// Parse spoken (or typed) text into an amount, category and note.
  static ParsedExpense parse(String rawText) {
    final text = rawText.trim();
    final lower = text.toLowerCase();

    final digitAmount = _extractDigitAmount(lower);
    double? amount = digitAmount;
    var fromWords = false;
    if (amount == null) {
      amount = _extractWordAmount(lower);
      fromWords = amount != null;
    }

    final category = _detectCategory(lower);
    final note = _buildNote(text, amount);

    return ParsedExpense(
      amount: amount,
      category: category,
      note: note,
      amountFromWords: fromWords,
    );
  }

  /// Digits: "200", "1,500", "250.50", "Rs 200", "₹200", "200 rupees".
  static double? _extractDigitAmount(String lower) {
    // Strip commas inside numbers first so "1,500" parses as 1500.
    final normalised = lower.replaceAllMapped(
      RegExp(r'(\d),(\d)'),
      (m) => '${m[1]}${m[2]}',
    );
    final matches = RegExp(r'(\d+(?:\.\d+)?)').allMatches(normalised).toList();
    if (matches.isEmpty) return null;
    // Prefer a number that sits next to a currency marker; otherwise the
    // largest number (e.g. "spent 200 on lunch for 2 people" -> 200).
    double? best;
    for (final m in matches) {
      final value = double.tryParse(m.group(1)!);
      if (value == null) continue;
      final before = normalised.substring(0, m.start);
      final after = normalised.substring(m.end);
      final nearCurrency = before.trimRight().endsWith('rs') ||
          before.trimRight().endsWith('₹') ||
          before.trimRight().endsWith('inr') ||
          after.trimLeft().startsWith('rupees') ||
          after.trimLeft().startsWith('rs') ||
          after.trimLeft().startsWith('₹');
      if (nearCurrency) return value;
      if (best == null || value > best) best = value;
    }
    return best;
  }

  /// Number words: "two hundred", "one thousand five hundred", "fifty".
  static double? _extractWordAmount(String lower) {
    final words = lower
        .replaceAll('-', ' ')
        .split(RegExp(r'[^a-z]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    var current = 0;
    var total = 0;
    var found = false;
    var i = 0;
    while (i < words.length) {
      final w = words[i];
      if (_ones.containsKey(w)) {
        current += _ones[w]!;
        found = true;
      } else if (_tens.containsKey(w)) {
        current += _tens[w]!;
        found = true;
      } else if (w == 'hundred') {
        current = (current == 0 ? 1 : current) * 100;
        found = true;
      } else if (w == 'thousand') {
        total += (current == 0 ? 1 : current) * 1000;
        current = 0;
        found = true;
      } else if (w == 'lakh' || w == 'lac') {
        total += (current == 0 ? 1 : current) * 100000;
        current = 0;
        found = true;
      } else if (found) {
        // A number-word run ended; stop so "two hundred on lunch" doesn't
        // swallow unrelated words.
        break;
      }
      i++;
    }
    if (!found) return null;
    return (total + current).toDouble();
  }

  static ExpenseCategory _detectCategory(String lower) {
    // Longest keyword first, so "textbook" beats "book" and
    // "electricity bill" beats "bill".
    final all = <({ExpenseCategory category, String keyword})>[];
    for (final entry in _categoryKeywords.entries) {
      for (final keyword in entry.value) {
        all.add((category: entry.key, keyword: keyword));
      }
    }
    all.sort((a, b) => b.keyword.length.compareTo(a.keyword.length));
    for (final item in all) {
      if (lower.contains(item.keyword)) return item.category;
    }
    return ExpenseCategory.other;
  }

  /// Note = the original text with the amount phrase tidied up, so the user
  /// still sees what they said. Capitalised first letter.
  static String _buildNote(String text, double? amount) {
    var note = text.trim();
    if (note.isEmpty) return '';
    note = note[0].toUpperCase() + note.substring(1);
    return note;
  }
}
