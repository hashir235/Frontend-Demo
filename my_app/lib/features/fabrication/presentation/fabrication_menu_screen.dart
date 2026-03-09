import 'dart:convert';

import 'package:my_app/core/config/api_config.dart';
import 'package:my_app/core/network/auth_http_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_hero_header.dart';
import '../../../shared/widgets/app_screen_shell.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/primary_card_button.dart';
import '../../../shared/widgets/section_surface_card.dart';
import '../../estimation/data/project_repository.dart';
import '../../estimation/presentation/recent_projects_screen.dart';
import '../../estimation/presentation/window_navigation_screen.dart';
import '../../estimation/state/estimate_session_store.dart';
import '../../settings/state/app_settings.dart';
import 'glass_report_screen.dart';

class FabricationMenuScreen extends StatelessWidget {
  const FabricationMenuScreen({super.key});


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
      final http.Response response = await AuthHttpClient()
          .post(
            ApiConfig.buildUri('/api/estimation/reset-session'),
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

    final ProjectRepository projectRepository = ProjectRepository();
    String? projectId;
    String? projectError;
    try {
      final project = await projectRepository.createProject(
        flow: EstimateFlow.fabrication,
        projectName: draft.projectName,
        projectLocation: draft.projectLocation,
      );
      projectId = project.id;
    } on Exception catch (error) {
      projectError = error.toString();
    }

    if (!context.mounted) {
      return;
    }

    if (projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(projectError ?? 'Project create failed.')),
      );
      return;
    }

    final EstimateSessionStore session = EstimateSessionStore(
      projectId: projectId,
      projectName: draft.projectName,
      projectLocation: draft.projectLocation,
      flow: EstimateFlow.fabrication,
      numberingMode: AppSettings.instance.numberingMode,
    );

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
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
      appBar: AppBar(title: const Text('Fabrication')),
      body: AppScreenShell(
        child: ListView(
          children: <Widget>[
            AppHeroHeader(
              eyebrow: 'FABRICATION',
              title: 'Production-ready fabrication workflow',
              subtitle:
                  'Start fabrication projects, run cutting and glass output flows, and reopen recent work from the same polished surface.',
              trailing: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[AppTheme.tealAccent, AppTheme.royalBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: const Icon(
                  Icons.precision_manufacturing_rounded,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.space6),
            SectionSurfaceCard(
              title: 'Start Work',
              subtitle:
                  'Create a new fabrication project, view the latest glass report, or reopen recent work.',
              child: Column(
                children: <Widget>[
                  PrimaryCardButton(
                    icon: Icons.add_box_outlined,
                    title: 'Create Project',
                    subtitle:
                        'Set project details and open the fabrication window catalogue.',
                    accent: AppTheme.tealAccent,
                    onTap: () => _handleCreateProject(context),
                  ),
                  const SizedBox(height: AppTheme.space5),
                  PrimaryCardButton(
                    icon: Icons.table_view_rounded,
                    title: 'Glass Report',
                    subtitle:
                        'Open the latest fabrication glass table and PDF tools.',
                    accent: AppTheme.amberAccent,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const GlassReportScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppTheme.space5),
                  const RecentProjectsListSection(
                    flow: EstimateFlow.fabrication,
                    moduleTitle: 'Fabrication',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.space6),
            const Row(
              children: <Widget>[
                Expanded(
                  child: MetricCard(
                    label: 'Glass + cutting flow',
                    value: 'Integrated',
                    icon: Icons.fact_check_outlined,
                    accent: AppTheme.tealAccent,
                  ),
                ),
              ],
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
                decoration: const InputDecoration(labelText: 'Project Name *'),
                validator: _requiredValidator,
              ),
              const SizedBox(height: AppTheme.space4),
              TextFormField(
                controller: _locationController,
                inputFormatters: <TextInputFormatter>[
                  LengthLimitingTextInputFormatter(100),
                ],
                decoration: const InputDecoration(labelText: 'Location *'),
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
