import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'rate_review_screen.dart';

class MaterialSelectionScreen extends StatefulWidget {
  final String projectName;
  final String projectLocation;

  const MaterialSelectionScreen({
    super.key,
    required this.projectName,
    required this.projectLocation,
  });

  @override
  State<MaterialSelectionScreen> createState() => _MaterialSelectionScreenState();
}

class _MaterialSelectionScreenState extends State<MaterialSelectionScreen> {
  static const List<_MaterialChoice> _gageOptions = <_MaterialChoice>[
    _MaterialChoice(label: '1.2mm', value: '1.2mm'),
    _MaterialChoice(label: '1.6mm', value: '1.6mm'),
    _MaterialChoice(label: '2mm', value: '2mm'),
  ];

  static const List<_MaterialChoice> _colorOptions = <_MaterialChoice>[
    _MaterialChoice(
      label: 'H23/PC-RAL (champain)',
      value: 'H23/PC-RAL',
    ),
    _MaterialChoice(label: 'DULL', value: 'DULL'),
    _MaterialChoice(
      label: 'SAHARA/ BROW',
      value: 'SAHARA/ BROWN',
    ),
    _MaterialChoice(label: 'BLACK/ MULTI', value: 'BLACK/ MULTI'),
  ];

  _MaterialChoice _selectedGage = _gageOptions.first;
  _MaterialChoice _selectedColor = _colorOptions.first;

  void _handleNextPressed() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => RateReviewScreen(
          gaugeLabel: _selectedGage.label,
          gaugeValue: _selectedGage.value,
          colorLabel: _selectedColor.label,
          colorValue: _selectedColor.value,
          projectName: widget.projectName,
          projectLocation: widget.projectLocation,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Material Selection'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              AppTheme.ice,
              AppTheme.sky.withValues(alpha: 0.5),
              AppTheme.mist,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppTheme.sky.withValues(alpha: 0.8)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppTheme.deepTeal.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                children: <Widget>[
                  _SelectionCard(
                    title: 'Select Gage',
                    child: Column(
                      children: _gageOptions
                          .map(
                            (_MaterialChoice option) => _OptionTile(
                              label: option.label,
                              selected: _selectedGage == option,
                              onTap: () {
                                setState(() {
                                  _selectedGage = option;
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SelectionCard(
                    title: 'Select Color',
                    child: Column(
                      children: _colorOptions
                          .map(
                            (_MaterialChoice option) => _OptionTile(
                              label: option.label,
                              selected: _selectedColor == option,
                              onTap: () {
                                setState(() {
                                  _selectedColor = option;
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _handleNextPressed,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Next'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MaterialChoice {
  final String label;
  final String value;

  const _MaterialChoice({
    required this.label,
    required this.value,
  });
}

class _SelectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SelectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.mist.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.sky.withValues(alpha: 0.55)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.deepTeal,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected
            ? AppTheme.violet.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? AppTheme.violet.withValues(alpha: 0.7)
              : AppTheme.sky.withValues(alpha: 0.35),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            children: <Widget>[
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AppTheme.violet : AppTheme.deepTeal,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: AppTheme.deepTeal,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

