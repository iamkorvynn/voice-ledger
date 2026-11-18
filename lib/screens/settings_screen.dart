import 'package:material_ui/material_ui.dart';

import '../services/database_helper.dart';
import '../services/export_service.dart';
import '../services/settings_service.dart';

/// Settings: optional Gemini key, export all data, about.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService();
  final _keyController = TextEditingController();
  var _loading = true;
  var _saved = false;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final key = await _settings.getGeminiApiKey();
    if (!mounted) return;
    setState(() {
      _keyController.text = key ?? '';
      _loading = false;
    });
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _saveKey() async {
    await _settings.setGeminiApiKey(_keyController.text);
    setState(() => _saved = true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _keyController.text.trim().isEmpty
              ? 'Gemini key removed — on-device parsing will be used.'
              : 'Gemini key saved on this device only.',
        ),
      ),
    );
  }

  Future<void> _exportAll() async {
    final all = await DatabaseHelper.instance.getAllExpenses();
    if (all.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No expenses to export yet.')),
      );
      return;
    }
    await ExportService().shareExpensesCsv(all, 'voiceledger-all.csv');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Smarter parsing (optional)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'By default VoiceLedger parses what you say entirely '
                  'on-device — no network, no account, nothing leaves your '
                  'phone. If you want smarter parsing, paste your own Gemini '
                  'API key below. It is stored only on this device and is '
                  'used only to parse your spoken expense text. Without a '
                  'key, the on-device parser is used and the app says so '
                  'honestly.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _keyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Gemini API key',
                    hintText: 'Paste your key here (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saveKey,
                  child: const Text('Save key'),
                ),
                if (_saved) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Saved. Leave the field empty and save again to remove it.',
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Your data',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Every expense is stored in a local SQLite database on '
                  'this phone. There is no account and no sync.',
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _exportAll,
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Export all expenses as CSV'),
                ),
                const SizedBox(height: 24),
                Text(
                  'About',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text('VoiceLedger 1.0.0 — speak it, confirm it, track it.'),
                const Text('Made by Numaan Bin Husain.'),
              ],
            ),
    );
  }
}
