import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/expense.dart';
import '../services/database_helper.dart';
import '../services/expense_parser.dart';
import '../services/export_service.dart';
import '../services/gemini_service.dart';
import '../services/settings_service.dart';
import 'add_edit_expense_screen.dart';
import 'settings_screen.dart';

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseHelper.instance;
  final _settings = SettingsService();
  final _speech = SpeechToText();

  var _month = DateTime(DateTime.now().year, DateTime.now().month);
  var _expenses = <Expense>[];
  var _loading = true;
  var _hasGeminiKey = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final expenses = await _db.getExpensesForMonth(_month.year, _month.month);
      final hasKey = await _settings.hasGeminiKey;
      if (!mounted) return;
      setState(() {
        _expenses = expenses;
        _hasGeminiKey = hasKey;
        _loading = false;
      });
    } catch (_) {
      // Storage unavailable (e.g. first launch edge case): show empty state.
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _loading = true;
    });
    _load();
  }

  void _goToCurrentMonth() {
    final now = DateTime.now();
    setState(() {
      _month = DateTime(now.year, now.month);
      _loading = true;
    });
    _load();
  }

  Future<void> _openAdd({Expense? existing, ParsedExpense? parsed, String? sourceText, String? parseSource}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddEditExpenseScreen(
          existing: existing,
          parsed: parsed,
          sourceText: sourceText,
          parseSource: parseSource,
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text('₹${expense.amount.toStringAsFixed(0)} — ${expense.note}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && expense.id != null) {
      await _db.deleteExpense(expense.id!);
      _load();
    }
  }

  Future<void> _startListening() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is needed to record expenses.'),
        ),
      );
      return;
    }
    final available = await _speech.initialize();
    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition is not available on this device.')),
      );
      return;
    }
    if (!mounted) return;
    final transcript = await showModalBottomSheet<String>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _ListeningSheet(speech: _speech),
    );
    if (transcript == null || transcript.trim().isEmpty) return;
    await _handleTranscript(transcript.trim());
  }

  Future<void> _handleTranscript(String text) async {
    // Show a brief "parsing" state, then confirm with the user.
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Understanding what you said…'),
          ],
        ),
      ),
    );

    ParsedExpense parsed;
    String parseSource;
    final apiKey = await _settings.getGeminiApiKey();
    if (apiKey != null) {
      final gemini = await GeminiService().parseWithGemini(text, apiKey);
      if (gemini != null) {
        parsed = gemini;
        parseSource = 'Parsed by Gemini (your API key)';
      } else {
        parsed = ExpenseParser.parse(text);
        parseSource =
            'Gemini could not parse this (check key / connection) — on-device parser used instead';
      }
    } else {
      parsed = ExpenseParser.parse(text);
      parseSource = 'Parsed on-device (no Gemini key set)';
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss parsing dialog
    await _openAdd(parsed: parsed, sourceText: text, parseSource: parseSource);
  }

  Future<void> _exportMonth() async {
    if (_expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to export this month yet.')),
      );
      return;
    }
    final name =
        'voiceledger-${_month.year}-${_month.month.toString().padLeft(2, '0')}.csv';
    await ExportService().shareExpensesCsv(_expenses, name);
  }

  String _formatAmount(double amount) => '₹${amount.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    final summary = MonthSummary.fromExpenses(_expenses);
    final now = DateTime.now();
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;

    return Scaffold(
      appBar: AppBar(
        title: const Text('VoiceLedger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export this month as CSV',
            onPressed: _exportMonth,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                children: [
                  _MonthNavigator(
                    month: _month,
                    isCurrentMonth: isCurrentMonth,
                    onShift: _shiftMonth,
                    onToday: _goToCurrentMonth,
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Spent in ${_monthNames[_month.month - 1]} ${_month.year}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatAmount(summary.total),
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${summary.count} expense${summary.count == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                _hasGeminiKey
                                    ? Icons.auto_awesome
                                    : Icons.mic_none,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _hasGeminiKey
                                      ? 'Smart parsing on (Gemini key set)'
                                      : 'On-device parsing — no key needed',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (summary.byCategory.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'By category',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 180,
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 36,
                                  sections: summary.byCategory.entries.map((e) {
                                    final pct =
                                        e.value / summary.total * 100;
                                    return PieChartSectionData(
                                      color: e.key.color,
                                      value: e.value,
                                      title: '${pct.toStringAsFixed(0)}%',
                                      radius: 56,
                                      titleStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...summary.byCategory.entries.map(
                              (e) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: e.key.color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(e.key.label)),
                                    Text(_formatAmount(e.value)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    'Expenses',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_expenses.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 48,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No expenses this month yet.',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tap the mic below and say "spent 200 on lunch", '
                              'or add one manually with the + button.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._expenses.map(
                      (e) => Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: e.category.color,
                            foregroundColor: Colors.white,
                            child: Text(e.category.glyph),
                          ),
                          title: Text(
                            e.note.isEmpty ? e.category.label : e.note,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${e.category.label} • ${e.date.day} '
                            '${_monthNames[e.date.month - 1]}',
                          ),
                          trailing: Text(
                            _formatAmount(e.amount),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onTap: () => _openAdd(existing: e),
                          onLongPress: () => _deleteExpense(e),
                        ),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        width: 72,
        height: 72,
        child: FloatingActionButton(
          onPressed: _startListening,
          tooltip: 'Speak an expense',
          child: const Icon(Icons.mic, size: 34),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            TextButton.icon(
              onPressed: () => _openAdd(),
              icon: const Icon(Icons.add),
              label: const Text('Add manually'),
            ),
            const SizedBox(width: 72),
            TextButton.icon(
              onPressed: _exportMonth,
              icon: const Icon(Icons.share_outlined),
              label: const Text('Export CSV'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthNavigator extends StatelessWidget {
  final DateTime month;
  final bool isCurrentMonth;
  final void Function(int delta) onShift;
  final VoidCallback onToday;

  const _MonthNavigator({
    required this.month,
    required this.isCurrentMonth,
    required this.onShift,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous month',
          onPressed: () => onShift(-1),
        ),
        Text(
          '${_monthNames[month.month - 1]} ${month.year}',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isCurrentMonth)
              TextButton(
                onPressed: onToday,
                child: const Text('Today'),
              ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next month',
              onPressed: isCurrentMonth ? null : () => onShift(1),
            ),
          ],
        ),
      ],
    );
  }
}

/// Bottom sheet shown while listening: live transcript + stop button.
/// Returns the final recognised text when the user taps Done.
class _ListeningSheet extends StatefulWidget {
  final SpeechToText speech;

  const _ListeningSheet({required this.speech});

  @override
  State<_ListeningSheet> createState() => _ListeningSheetState();
}

class _ListeningSheetState extends State<_ListeningSheet> {
  var _transcript = '';
  var _listening = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() => _listening = true);
    await widget.speech.listen(
      onResult: (result) {
        setState(() => _transcript = result.recognizedWords);
      },
      listenOptions: SpeechListenOptions(
        listenFor: Duration(seconds: 30),
        pauseFor: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _stop() async {
    await widget.speech.stop();
    if (!mounted) return;
    setState(() => _listening = false);
    Navigator.of(context).pop(_transcript);
  }

  @override
  void dispose() {
    widget.speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.mic,
            size: 56,
            color: _listening
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
          ),
          const SizedBox(height: 12),
          Text(
            _listening ? 'Listening… speak now' : 'Stopped',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Try: "spent 200 on lunch" or "paid 500 for petrol"',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _transcript.isEmpty ? 'Waiting for speech…' : _transcript,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _stop,
              child: const Text('Done — check what I said'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
