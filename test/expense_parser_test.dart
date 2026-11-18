import 'package:flutter_test/flutter_test.dart';
import 'package:voiceledger/models/expense.dart';
import 'package:voiceledger/services/expense_parser.dart';

void main() {
  group('amount extraction', () {
    test('plain digits', () {
      expect(ExpenseParser.parse('spent 200 on lunch').amount, 200);
    });

    test('Rs prefix', () {
      expect(ExpenseParser.parse('spent Rs 200 on lunch').amount, 200);
    });

    test('rupees suffix', () {
      expect(ExpenseParser.parse('paid 500 rupees for petrol').amount, 500);
    });

    test('rupee symbol', () {
      expect(ExpenseParser.parse('₹750 for groceries').amount, 750);
    });

    test('decimals', () {
      expect(ExpenseParser.parse('spent 250.50 on coffee').amount, 250.5);
    });

    test('comma thousands', () {
      expect(ExpenseParser.parse('paid 1,500 for rent').amount, 1500);
    });

    test('no amount gives null, never a fake number', () {
      final parsed = ExpenseParser.parse('went out for lunch');
      expect(parsed.amount, isNull);
    });

    test('largest number wins when several are present', () {
      expect(
        ExpenseParser.parse('spent 200 on lunch for 2 people').amount,
        200,
      );
    });
  });

  group('number words (bonus)', () {
    test('two hundred', () {
      expect(ExpenseParser.parse('spent two hundred on lunch').amount, 200);
    });

    test('one thousand five hundred', () {
      expect(
        ExpenseParser.parse('paid one thousand five hundred for fees').amount,
        1500,
      );
    });

    test('fifty', () {
      expect(ExpenseParser.parse('fifty rupees for chai').amount, 50);
    });
  });

  group('category mapping', () {
    test('food keywords', () {
      expect(
        ExpenseParser.parse('spent 200 on lunch').category,
        ExpenseCategory.food,
      );
      expect(
        ExpenseParser.parse('300 for pizza').category,
        ExpenseCategory.food,
      );
    });

    test('travel keywords', () {
      expect(
        ExpenseParser.parse('paid 500 for petrol').category,
        ExpenseCategory.travel,
      );
      expect(
        ExpenseParser.parse('200 for metro ticket').category,
        ExpenseCategory.travel,
      );
    });

    test('shopping keywords', () {
      expect(
        ExpenseParser.parse('bought shoes for 1200').category,
        ExpenseCategory.shopping,
      );
    });

    test('bills keywords', () {
      expect(
        ExpenseParser.parse('paid electricity bill 900').category,
        ExpenseCategory.bills,
      );
      expect(
        ExpenseParser.parse('rent 8000').category,
        ExpenseCategory.bills,
      );
    });

    test('entertainment keywords', () {
      expect(
        ExpenseParser.parse('spent 600 on a movie').category,
        ExpenseCategory.entertainment,
      );
    });

    test('health keywords', () {
      expect(
        ExpenseParser.parse('bought medicine for 350').category,
        ExpenseCategory.health,
      );
    });

    test('education keywords', () {
      expect(
        ExpenseParser.parse('paid tuition fees 2000').category,
        ExpenseCategory.education,
      );
    });

    test('unknown maps to other', () {
      expect(
        ExpenseParser.parse('spent 100 on something random').category,
        ExpenseCategory.other,
      );
    });

    test('longest keyword wins (textbook is education, not shopping book)', () {
      expect(
        ExpenseParser.parse('bought a textbook for 450').category,
        ExpenseCategory.education,
      );
    });
  });

  group('month totals', () {
    test('MonthSummary sums totals and groups by category', () {
      final summary = MonthSummary.fromExpenses([
        Expense(
          amount: 200,
          category: ExpenseCategory.food,
          note: 'lunch',
          date: DateTime(2026, 11, 5),
        ),
        Expense(
          amount: 500,
          category: ExpenseCategory.travel,
          note: 'petrol',
          date: DateTime(2026, 11, 6),
        ),
        Expense(
          amount: 100,
          category: ExpenseCategory.food,
          note: 'chai',
          date: DateTime(2026, 11, 7),
        ),
      ]);
      expect(summary.total, 800);
      expect(summary.count, 3);
      expect(summary.byCategory[ExpenseCategory.food], 300);
      expect(summary.byCategory[ExpenseCategory.travel], 500);
    });

    test('empty list gives zero totals', () {
      final summary = MonthSummary.fromExpenses([]);
      expect(summary.total, 0);
      expect(summary.count, 0);
      expect(summary.byCategory, isEmpty);
    });
  });

  group('expense model round-trip', () {
    test('toMap/fromMap preserves fields', () {
      final expense = Expense(
        id: 1,
        amount: 250.5,
        category: ExpenseCategory.bills,
        note: 'Electricity',
        date: DateTime(2026, 11, 10, 12),
        sourceText: 'paid 250 for electricity',
      );
      final restored = Expense.fromMap(expense.toMap());
      expect(restored.id, 1);
      expect(restored.amount, 250.5);
      expect(restored.category, ExpenseCategory.bills);
      expect(restored.note, 'Electricity');
      expect(restored.sourceText, 'paid 250 for electricity');
    });
  });
}
