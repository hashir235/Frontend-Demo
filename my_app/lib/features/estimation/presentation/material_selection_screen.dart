import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_hero_header.dart';
import '../../../shared/widgets/app_screen_shell.dart';
import '../../../shared/widgets/project_meta_strip.dart';
import '../../../shared/widgets/section_surface_card.dart';
import '../data/cost_table_api_client.dart';
import '../data/rate_review_api_client.dart';
import 'rate_review_screen.dart';

class MaterialSelectionScreen extends StatefulWidget {
  final String? projectId;
  final String projectName;
  final String projectLocation;
  final String requestContext;
  final RateReviewApiClient? rateReviewApiClient;
  final CostTableApiClient? costTableApiClient;
  final String materialTableTitle;
  final bool materialTableShowNextToBill;
  final bool materialTableShowPdfActions;

  const MaterialSelectionScreen({
    super.key,
    this.projectId,
    required this.projectName,
    required this.projectLocation,
    this.requestContext = 'estimation',
    this.rateReviewApiClient,
    this.costTableApiClient,
    this.materialTableTitle = 'Estimation Material Table',
    this.materialTableShowNextToBill = true,
    this.materialTableShowPdfActions = true,
  });

  @override
  State<MaterialSelectionScreen> createState() =>
      _MaterialSelectionScreenState();
}

class _MaterialSelectionScreenState extends State<MaterialSelectionScreen> {
  static const List<_MaterialChoice> _gageOptions = <_MaterialChoice>[
    _MaterialChoice(label: '1.2mm', value: '1.2mm'),
    _MaterialChoice(label: '1.6mm', value: '1.6mm'),
    _MaterialChoice(label: '2mm', value: '2mm'),
  ];

  static const List<_MaterialChoice> _colorOptions = <_MaterialChoice>[
    _MaterialChoice(label: 'H23/PC-RAL (champain)', value: 'H23/PC-RAL'),
    _MaterialChoice(label: 'DULL', value: 'DULL'),
    _MaterialChoice(label: 'SAHARA/ BROW', value: 'SAHARA/ BROWN'),
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
          projectId: widget.projectId,
          requestContext: widget.requestContext,
          projectName: widget.projectName,
          projectLocation: widget.projectLocation,
          apiClient: widget.rateReviewApiClient,
          costTableApiClient: widget.costTableApiClient,
          materialTableTitle: widget.materialTableTitle,
          materialTableShowNextToBill: widget.materialTableShowNextToBill,
          materialTableShowPdfActions: widget.materialTableShowPdfActions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Material Selection')),
      body: AppScreenShell(
        child: ListView(
          children: <Widget>[
            const AppHeroHeader(
              eyebrow: 'MATERIAL',
              title: 'Choose gauge and finish',
              subtitle:
                  'Set the base material properties before rates and cost calculations are reviewed.',
            ),
            const SizedBox(height: AppTheme.space5),
            ProjectMetaStrip(
              projectName: widget.projectName,
              projectLocation: widget.projectLocation,
            ),
            const SizedBox(height: AppTheme.space6),
            SectionSurfaceCard(
              title: 'Gauge',
              subtitle:
                  'Select the aluminium gauge that will drive rate review.',
              child: Column(
                children: _gageOptions
                    .map(
                      (_MaterialChoice option) => Padding(
                        padding: const EdgeInsets.only(bottom: AppTheme.space3),
                        child: _OptionTile(
                          label: option.label,
                          selected: _selectedGage == option,
                          onTap: () {
                            setState(() {
                              _selectedGage = option;
                            });
                          },
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: AppTheme.space5),
            SectionSurfaceCard(
              title: 'Colour',
              subtitle:
                  'Choose the finish that will be used across the rate pipeline.',
              child: Column(
                children: _colorOptions
                    .map(
                      (_MaterialChoice option) => Padding(
                        padding: const EdgeInsets.only(bottom: AppTheme.space3),
                        child: _OptionTile(
                          label: option.label,
                          selected: _selectedColor == option,
                          onTap: () {
                            setState(() {
                              _selectedColor = option;
                            });
                          },
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: AppTheme.space6),
            FilledButton(
              onPressed: _handleNextPressed,
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialChoice {
  final String label;
  final String value;

  const _MaterialChoice({required this.label, required this.value});
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space5,
            vertical: AppTheme.space5,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.royalBlue.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: selected ? AppTheme.royalBlue : AppTheme.line,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AppTheme.royalBlue : AppTheme.textSecondary,
              ),
              const SizedBox(width: AppTheme.space4),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: AppTheme.textPrimary,
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
