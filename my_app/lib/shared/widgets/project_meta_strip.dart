import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class ProjectMetaStrip extends StatelessWidget {
  final String projectName;
  final String projectLocation;
  final List<Widget> extras;

  const ProjectMetaStrip({
    super.key,
    required this.projectName,
    required this.projectLocation,
    this.extras = const <Widget>[],
  });

  String _value(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? '--' : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTheme.space3,
      runSpacing: AppTheme.space3,
      children: <Widget>[
        _MetaChip(label: 'Project', value: _value(projectName)),
        _MetaChip(label: 'Location', value: _value(projectLocation)),
        ...extras,
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetaChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space4,
        vertical: AppTheme.space3,
      ),
      decoration: AppTheme.infoChipDecoration(),
      child: RichText(
        text: TextSpan(
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textPrimary),
          children: <InlineSpan>[
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
