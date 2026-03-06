import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/primary_card_button.dart';
import '../../estimation/presentation/window_navigation_screen.dart';
import '../../estimation/state/estimate_session_store.dart';
import '../../settings/state/app_settings.dart';
import 'glass_report_screen.dart';

class FabricationMenuScreen extends StatelessWidget {
  const FabricationMenuScreen({super.key});

  String _apiBaseUrl() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://127.0.0.1:8080';
  }

  Future<_ProjectDraft?> _showProjectDialog(BuildContext context) async {
    return showDialog<_ProjectDraft>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _CreateProjectDialog(),
    );
  }

  Future<void> _handleCreateProject(BuildContext context) async {
    final _ProjectDraft? draft = await _showProjectDialog(context);
    if (draft == null || !context.mounted) {
      return;
    }

    String? resetWarning;
    try {
      final http.Response response = await http
          .post(
            Uri.parse('${_apiBaseUrl()}/api/estimation/reset-session'),
            headers: const <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(const <String, Object?>{}),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        resetWarning = 'Backend reset failed. Continuing with new project.';
      }
    } on Exception {
      resetWarning = 'Reset service unreachable. Continuing with new project.';
    }

    if (!context.mounted) {
      return;
    }

    final EstimateSessionStore session = EstimateSessionStore(
      projectName: draft.projectName,
      projectLocation: draft.projectLocation,
      flow: EstimateFlow.fabrication,
      numberingMode: AppSettings.instance.numberingMode,
    );

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WindowNavigationScreen.root(
          session: session,
          moduleTitle: 'Fabrication',
        ),
      ),
    );

    if (resetWarning != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(resetWarning)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Fabrication'), centerTitle: true),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.ice, AppTheme.mist],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            const _GlowCircle(
              alignment: Alignment(-1.2, -1.0),
              size: 200,
              color: AppTheme.violet,
            ),
            const _GlowCircle(
              alignment: Alignment(1.1, 0.8),
              size: 240,
              color: AppTheme.sky,
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fabrication tools',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Create project and continue fabrication flow',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: ListView(
                        children: [
                          PrimaryCardButton(
                            icon: Icons.add_box_outlined,
                            title: 'Create Project',
                            subtitle: 'Set project details and browse windows',
                            onTap: () => _handleCreateProject(context),
                          ),
                          const SizedBox(height: 12),
                          PrimaryCardButton(
                            icon: Icons.table_view_rounded,
                            title: 'Glass Report',
                            subtitle: 'View latest fabrication glass table',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const GlassReportScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectDraft {
  final String projectName;
  final String projectLocation;

  const _ProjectDraft({
    required this.projectName,
    required this.projectLocation,
  });
}

class _CreateProjectDialog extends StatefulWidget {
  const _CreateProjectDialog();

  @override
  State<_CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<_CreateProjectDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  @override
  void dispose() {
    _projectNameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Project'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _projectNameController,
                autofocus: true,
                inputFormatters: <TextInputFormatter>[
                  LengthLimitingTextInputFormatter(100),
                ],
                decoration: _decoration('Project Name *'),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                inputFormatters: <TextInputFormatter>[
                  LengthLimitingTextInputFormatter(100),
                ],
                decoration: _decoration('Location *'),
                validator: _requiredValidator,
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
            final FormState? form = _formKey.currentState;
            if (form == null || !form.validate()) {
              return;
            }
            Navigator.of(context).pop(
              _ProjectDraft(
                projectName: _projectNameController.text.trim(),
                projectLocation: _locationController.text.trim(),
              ),
            );
          },
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final Alignment alignment;
  final double size;
  final Color color;

  const _GlowCircle({
    required this.alignment,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}
