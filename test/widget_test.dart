import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voiceledger/main.dart';
import 'package:voiceledger/screens/add_edit_expense_screen.dart';
import 'package:voiceledger/services/expense_parser.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('onboarding shows speak-confirm-track and finishes',
      (tester) async {
    await tester.pumpWidget(const VoiceLedgerApp());
    await tester.pumpAndSettle();

    // First onboarding page.
    expect(find.text('Speak your expense'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm before saving'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Track every month'), findsOneWidget);
    await tester.tap(find.text('Start tracking'));
    await tester.pumpAndSettle();

    // Home screen: empty month state, mic button present.
    expect(find.text('VoiceLedger'), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsOneWidget);
    expect(find.text('No expenses this month yet.'), findsOneWidget);
  });

  testWidgets('confirm screen shows parsed voice result for review',
      (tester) async {
    final parsed = ExpenseParser.parse('spent 200 on lunch');
    await tester.pumpWidget(
      MaterialApp(
        home: AddEditExpenseScreen(
          parsed: parsed,
          sourceText: 'spent 200 on lunch',
          parseSource: 'Parsed on-device (no Gemini key set)',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Confirm expense'), findsOneWidget);
    expect(find.textContaining('spent 200 on lunch'), findsWidgets);
    expect(find.textContaining('Parsed on-device'), findsOneWidget);
    // Parsed amount prefilled in the amount field, category pre-selected.
    final amountField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(amountField.controller?.text, '200');
    expect(find.text('Food'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Save expense'), findsOneWidget);
  });

  testWidgets('add screen validates amount before saving', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AddEditExpenseScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount greater than 0'), findsOneWidget);
  });
}
