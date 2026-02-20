import 'package:flutter/material.dart';

import '../state/app_settings.dart';
import '../state/numbering_mode.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late NumberingMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = AppSettings.instance.numberingMode;
    AppSettings.instance.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    AppSettings.instance.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    setState(() {
      _mode = AppSettings.instance.numberingMode;
    });
  }

  void _updateMode(NumberingMode mode) {
    AppSettings.instance.setNumberingMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.ice, AppTheme.mist],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              Text(
                'Window Numbering',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.deepTeal,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how window numbers are assigned in Estimation.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.deepTeal.withValues(alpha: 0.7),
                    ),
              ),
              const SizedBox(height: 18),
              RadioListTile<NumberingMode>(
                value: NumberingMode.auto,
                groupValue: _mode,
                title: const Text('Auto (default)'),
                subtitle: const Text(
                  'Automatically increments window numbers for each new entry.',
                ),
                onChanged: (NumberingMode? value) {
                  if (value != null) {
                    _updateMode(value);
                  }
                },
              ),
              RadioListTile<NumberingMode>(
                value: NumberingMode.manual,
                groupValue: _mode,
                title: const Text('Manual'),
                subtitle: const Text(
                  'User must enter a window number before height/width.',
                ),
                onChanged: (NumberingMode? value) {
                  if (value != null) {
                    _updateMode(value);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
