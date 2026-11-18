import 'package:material_ui/material_ui.dart';

import '../models/expense.dart';
import '../services/database_helper.dart';
import '../services/expense_parser.dart';

/// Add / edit an expense manually, or confirm a voice-parsed one.
/// Nothing is saved until the user taps Save.
class AddEditExpenseScreen extends StatefulWidget {
  final Expense? existing;
  final ParsedExpense? parsed;
  final String? sourceText;
  final String? parseSource;

  const AddEditExpenseScreen({
    super.key,
    this.existing,
    this.parsed,
    this.sourceText,
    this.parseSource,
  });

  @override
  State<AddEditExpenseScreen> createState() => _AddEditExpenseScreenState();
}

class _AddEditExpenseScreenState extends State<AddEditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  late ExpenseCategory _category;
  late DateTime _date;
  var _saving = false;

  bool get _isEdit => widget.existing != null;
  bool get _isVoice => widget.parsed != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final parsed = widget.parsed;
    if (existing != null) {
      _amountController.text =
          existing.amount.toStringAsFixed(existing.amount % 1 == 0 ? 0 : 2);
      _noteController.text = existing.note;
      _category = existing.category;
      _date = existing.date;
    } else if (parsed != null) {
      _amountController.text =
          parsed.amount != null ? parsed.amount!.toStringAsFixed(0) : '';
      _noteController.text = parsed.note;
      _category = parsed.category;
      _date = DateTime.now();
    } else {
      _category = ExpenseCategory.other;
      _date = DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final amount = double.parse(_amountController.text.trim());
    final expense = Expense(
      id: widget.existing?.id,
      amount: amount,
      category: _category,
      note: _noteController.text.trim(),
      date: _date,
      sourceText: widget.sourceText ?? widget.existing?.sourceText,
    );
    if (_isEdit) {
      await DatabaseHelper.instance.updateExpense(expense);
    } else {
      await DatabaseHelper.instance.insertExpense(expense);
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete expense?'),
        content: const Text('This cannot be undone.'),
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
    if (confirmed == true && widget.existing?.id != null) {
      await DatabaseHelper.instance.deleteExpense(widget.existing!.id!);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit
              ? 'Edit expense'
              : _isVoice
                  ? 'Confirm expense'
                  : 'Add expense',
        ),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isVoice) ...[
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.hearing),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You said:',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '"${widget.sourceText}"',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.parseSource ?? '',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Check the amount and category below — fix anything '
                        'that is wrong before saving.',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final amount = double.tryParse((value ?? '').trim());
                if (amount == null || amount <= 0) {
                  return 'Enter an amount greater than 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Category',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ExpenseCategory.values.map((c) {
                final selected = c == _category;
                return ChoiceChip(
                  label: Text(c.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = c),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'e.g. Lunch with friends',
                border: OutlineInputBorder(),
              ),
              maxLength: 120,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date'),
              subtitle: Text(
                '${_date.day}/${_date.month}/${_date.year}',
              ),
              trailing: TextButton(
                onPressed: _pickDate,
                child: const Text('Change'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEdit ? 'Save changes' : 'Save expense'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
