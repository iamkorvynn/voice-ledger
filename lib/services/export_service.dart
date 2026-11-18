// CSV export of expenses, shared via share_plus.

import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/expense.dart';

class ExportService {
  static String expensesToCsv(List<Expense> expenses) {
    final rows = <List<dynamic>>[
      ['Date', 'Amount (₹)', 'Category', 'Note'],
    ];
    for (final e in expenses) {
      rows.add([
        '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-'
            '${e.date.day.toString().padLeft(2, '0')}',
        e.amount.toStringAsFixed(2),
        e.category.label,
        e.note,
      ]);
    }
    return Csv().encode(rows);
  }

  Future<void> shareExpensesCsv(
    List<Expense> expenses,
    String fileName,
  ) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(expensesToCsv(expenses));
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: 'VoiceLedger expenses'),
    );
  }
}
