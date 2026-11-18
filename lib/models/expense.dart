// Expense model and categories for VoiceLedger.

import 'package:material_ui/material_ui.dart';

enum ExpenseCategory {
  food,
  travel,
  shopping,
  bills,
  entertainment,
  health,
  education,
  other,
}

extension ExpenseCategoryX on ExpenseCategory {
  String get label {
    switch (this) {
      case ExpenseCategory.food:
        return 'Food';
      case ExpenseCategory.travel:
        return 'Travel';
      case ExpenseCategory.shopping:
        return 'Shopping';
      case ExpenseCategory.bills:
        return 'Bills';
      case ExpenseCategory.entertainment:
        return 'Entertainment';
      case ExpenseCategory.health:
        return 'Health';
      case ExpenseCategory.education:
        return 'Education';
      case ExpenseCategory.other:
        return 'Other';
    }
  }

  /// Emoji-free short icon label used in lists (plain text glyph).
  String get glyph {
    switch (this) {
      case ExpenseCategory.food:
        return 'F';
      case ExpenseCategory.travel:
        return 'T';
      case ExpenseCategory.shopping:
        return 'S';
      case ExpenseCategory.bills:
        return 'B';
      case ExpenseCategory.entertainment:
        return 'E';
      case ExpenseCategory.health:
        return 'H';
      case ExpenseCategory.education:
        return 'Ed';
      case ExpenseCategory.other:
        return 'O';
    }
  }

  static ExpenseCategory fromName(String name) {
    return ExpenseCategory.values.firstWhere(
      (c) => c.name == name,
      orElse: () => ExpenseCategory.other,
    );
  }

  Color get color {
    switch (this) {
      case ExpenseCategory.food:
        return const Color(0xFFE67E22);
      case ExpenseCategory.travel:
        return const Color(0xFF2980B9);
      case ExpenseCategory.shopping:
        return const Color(0xFF8E44AD);
      case ExpenseCategory.bills:
        return const Color(0xFFC0392B);
      case ExpenseCategory.entertainment:
        return const Color(0xFF16A085);
      case ExpenseCategory.health:
        return const Color(0xFF27AE60);
      case ExpenseCategory.education:
        return const Color(0xFF2C3E50);
      case ExpenseCategory.other:
        return const Color(0xFF7F8C8D);
    }
  }
}

class Expense {
  final int? id;
  final double amount;
  final ExpenseCategory category;
  final String note;
  final DateTime date;
  final String? sourceText;

  const Expense({
    this.id,
    required this.amount,
    required this.category,
    required this.note,
    required this.date,
    this.sourceText,
  });

  Expense copyWith({
    int? id,
    double? amount,
    ExpenseCategory? category,
    String? note,
    DateTime? date,
    String? sourceText,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      note: note ?? this.note,
      date: date ?? this.date,
      sourceText: sourceText ?? this.sourceText,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'category': category.name,
      'note': note,
      'date': date.millisecondsSinceEpoch,
      'source_text': sourceText,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      category: ExpenseCategoryX.fromName(map['category'] as String),
      note: map['note'] as String? ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      sourceText: map['source_text'] as String?,
    );
  }
}

// Totals for a month, computed from a list of expenses.
class MonthSummary {
  final double total;
  final Map<ExpenseCategory, double> byCategory;
  final int count;

  const MonthSummary({
    required this.total,
    required this.byCategory,
    required this.count,
  });

  factory MonthSummary.fromExpenses(List<Expense> expenses) {
    var total = 0.0;
    final byCategory = <ExpenseCategory, double>{};
    for (final e in expenses) {
      total += e.amount;
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }
    return MonthSummary(total: total, byCategory: byCategory, count: expenses.length);
  }
}
