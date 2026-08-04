import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_screen_shell.dart';
import '../../../shared/widgets/state_message_card.dart';
import '../data/rate_list_api_client.dart';
import '../models/rate_list.dart';

/// Settings > Rates.
///
/// The owner uploads one list, but rates differ by city, so this screen shows
/// the list in force and lets the workshop price it their own way. Anything
/// edited here is what their bills are priced with; Reset goes back to the
/// owner's numbers.
class RatesScreen extends StatefulWidget {
  final RateListApiClient? client;

  const RatesScreen({super.key, this.client});

  @override
  State<RatesScreen> createState() => _RatesScreenState();
}

class _RatesScreenState extends State<RatesScreen> {
  late final RateListApiClient _api = widget.client ?? RateListApiClient();

  RateList _list = RateList.empty;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final RateList list = await _api.fetch();
      if (!mounted) return;
      setState(() {
        _list = list;
        _loading = false;
        _dirty = false;
      });
    } on RateListApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final RateList saved = await _api.save(_list.rows);
      if (!mounted) return;
      setState(() {
        _list = saved;
        _saving = false;
        _dirty = false;
      });
      _toast('Rates saved. Your bills will use these.');
    } on RateListApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.message);
    }
  }

  Future<void> _reset() async {
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Back to the standard rates?'),
        content: const Text(
          'Your own rates will be removed and the rates sent by Quick AL will '
          'be used instead. Sections you added yourself will go too.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep mine'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (sure != true) return;

    setState(() => _saving = true);
    try {
      final RateList fresh = await _api.resetToMaster();
      if (!mounted) return;
      setState(() {
        _list = fresh;
        _saving = false;
        _dirty = false;
      });
      _toast('Standard rates restored.');
    } on RateListApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.message);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _setRate(int rowIndex, String colour, String value) {
    final RateRow row = _list.rows[rowIndex];
    final Map<String, String> next = Map<String, String>.from(row.byColour)
      ..[colour] = value.trim();
    final List<RateRow> rows = List<RateRow>.from(_list.rows)
      ..[rowIndex] = row.copyWith(byColour: next);
    setState(() {
      _list = RateList(rows: rows, master: _list.master, customised: true);
      _dirty = true;
    });
  }

  Future<void> _addSection() async {
    final _NewSection? added = await showDialog<_NewSection>(
      context: context,
      builder: (BuildContext ctx) => _AddSectionDialog(
        colours: _list.colours,
        isTaken: (String name) => _list.hasSection(name),
      ),
    );
    if (added == null) return;

    setState(() {
      _list = RateList(
        rows: <RateRow>[
          ..._list.rows,
          RateRow(section: added.section, byColour: added.rates),
        ],
        master: _list.master,
        customised: true,
      );
      _dirty = true;
    });
  }

  void _removeSection(int index) {
    final RateRow row = _list.rows[index];
    setState(() {
      _list = RateList(
        rows: List<RateRow>.from(_list.rows)..removeAt(index),
        master: _list.master,
        customised: true,
      );
      _dirty = true;
    });
    _toast('Removed ${row.section}.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rates'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Back to standard rates',
            onPressed: _saving ? null : _reset,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton.extended(
              onPressed: _saving ? null : _addSection,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add section'),
            ),
      bottomNavigationBar: _dirty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(_saving ? 'Saving...' : 'Save rates'),
                ),
              ),
            )
          : null,
      body: AppScreenShell(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: StateMessageCard(
          icon: Icons.price_change_outlined,
          title: 'Rates could not load',
          message: _error!,
        ),
      );
    }
    if (_list.rows.isEmpty) {
      return const Center(
        child: StateMessageCard(
          icon: Icons.price_change_outlined,
          title: 'No rates yet',
          message: 'No rate list has been published yet.',
        ),
      );
    }

    final List<String> colours = _list.colours;

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: <Widget>[
        _buildBanner(context),
        const SizedBox(height: AppTheme.space5),
        for (int i = 0; i < _list.rows.length; i++)
          _buildSectionCard(context, i, colours),
      ],
    );
  }

  Widget _buildBanner(BuildContext context) {
    final bool custom = _list.customised;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: custom
            ? AppTheme.tealAccent.withValues(alpha: 0.12)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            custom ? Icons.edit_note_rounded : Icons.cloud_done_rounded,
            color: custom ? AppTheme.tealAccent : AppTheme.slate,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              custom
                  ? 'You are using your own rates. Bills are priced with these.'
                  : 'These are the standard rates sent by Quick AL. Change any '
                        'of them to use your own.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context,
    int index,
    List<String> colours,
  ) {
    final RateRow row = _list.rows[index];
    final bool isOwn =
        _list.masterValue(row.section, colours.isEmpty ? '' : colours.first) ==
        null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    row.section,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.deepTeal,
                    ),
                  ),
                ),
                if (isOwn)
                  IconButton(
                    tooltip: 'Remove this section',
                    onPressed: () => _removeSection(index),
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (final String colour in colours)
              _buildRateField(row, index, colour),
          ],
        ),
      ),
    );
  }

  Widget _buildRateField(RateRow row, int index, String colour) {
    final String current = row.byColour[colour] ?? '';
    final String? standard = _list.masterValue(row.section, colour);
    final bool changed =
        standard != null && standard.isNotEmpty && standard != current;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: Text(
              colour,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.slate,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: TextFormField(
              key: ValueKey<String>('${row.section}|$colour|$current'),
              initialValue: current,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                LengthLimitingTextInputFormatter(8),
              ],
              textAlign: TextAlign.end,
              decoration: InputDecoration(
                isDense: true,
                helperText: changed ? 'was $standard' : null,
                helperStyle: const TextStyle(fontSize: 11),
              ),
              onChanged: (String v) => _setRate(index, colour, v),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewSection {
  final String section;
  final Map<String, String> rates;

  const _NewSection(this.section, this.rates);
}

/// Adds a section of the workshop's own. The name has to be one the list does
/// not already carry -- two rows for the same section would make the price
/// depend on which one the engine happened to read first.
class _AddSectionDialog extends StatefulWidget {
  final List<String> colours;
  final bool Function(String name) isTaken;

  const _AddSectionDialog({required this.colours, required this.isTaken});

  @override
  State<_AddSectionDialog> createState() => _AddSectionDialogState();
}

class _AddSectionDialogState extends State<_AddSectionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _section = TextEditingController();
  late final Map<String, TextEditingController> _rates =
      <String, TextEditingController>{
        for (final String c in widget.colours) c: TextEditingController(),
      };

  @override
  void dispose() {
    _section.dispose();
    for (final TextEditingController c in _rates.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a section'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _section,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Section',
                  hintText: 'D33 (1.2mm)',
                ),
                validator: (String? v) {
                  final String name = (v ?? '').trim();
                  if (name.isEmpty) return 'Enter a section name';
                  if (widget.isTaken(name)) {
                    return 'This section is already in the list';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              for (final String colour in widget.colours)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextFormField(
                    controller: _rates[colour],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      LengthLimitingTextInputFormatter(8),
                    ],
                    decoration: InputDecoration(labelText: colour),
                    validator: (String? v) {
                      if ((v ?? '').trim().isEmpty) return 'Enter a rate';
                      return null;
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            Navigator.of(context).pop(
              _NewSection(_section.text.trim(), <String, String>{
                for (final MapEntry<String, TextEditingController> e
                    in _rates.entries)
                  e.key: e.value.text.trim(),
              }),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
