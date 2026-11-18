// Local SQLite storage for expenses (sqflite). All data stays on device.

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/expense.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = join(dir, 'voice_ledger.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE expenses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            category TEXT NOT NULL,
            note TEXT NOT NULL,
            date INTEGER NOT NULL,
            source_text TEXT
          )
        ''');
      },
    );
  }

  Future<int> insertExpense(Expense expense) async {
    final db = await database;
    return db.insert('expenses', expense.toMap());
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await database;
    return db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    return db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Expense>> getExpensesForMonth(int year, int month) async {
    final db = await database;
    final start = DateTime(year, month, 1).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1, 1).millisecondsSinceEpoch;
    final rows = await db.query(
      'expenses',
      where: 'date >= ? AND date < ?',
      whereArgs: [start, end],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(Expense.fromMap).toList();
  }

  Future<List<Expense>> getAllExpenses() async {
    final db = await database;
    final rows = await db.query('expenses', orderBy: 'date DESC, id DESC');
    return rows.map(Expense.fromMap).toList();
  }

  /// Distinct (year, month) pairs that have at least one expense,
  /// newest first.
  Future<List<DateTime>> getAvailableMonths() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT strftime("%Y", date / 1000, "unixepoch") AS y, '
      'strftime("%m", date / 1000, "unixepoch") AS m '
      'FROM expenses ORDER BY y DESC, m DESC',
    );
    return rows
        .map((r) => DateTime(int.parse(r['y'] as String), int.parse(r['m'] as String)))
        .toList();
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
