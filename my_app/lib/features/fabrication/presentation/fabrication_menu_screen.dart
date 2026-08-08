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
import '../../flow_nav/models/flow_step.dart';
import '../../flow_nav/presentation/flow_progress_bar.dart';
import '../../tutorial/tutorial_controller.dart';
import '../../tutorial/tutorial_overlay.dart';
import '../../tutorial/tutorial_step.dart';
import '../../tutorial/tutorial_target.dart';
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

  /// Asks for the project details and creates it, returning what was made.
  ///
  /// Shared by both create buttons: the dialog, the backend session reset and
  /// the error handling are identical, and only where the user lands afterwards
  /// differs.
  Future<_NewProject?> _createProject(
    BuildContext context, {
    required EstimateFlow flow,
  }) async {
    final _ProjectDraft? draft = await _showProjectDialog(context);
    if (draft == null || !context.mounted) {
      return null;
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
      return null;
    }

    final ProjectRepository projectRepository = ProjectRepository();
    String? projectId;
    String? projectError;
    try {
      final project = await projectRepository.createProject(
        flow: flow,
        projectName: draft.projectName,
        projectLocation: draft.projectLocation,
      );
      projectId = project.id;
    } on Exception catch (error) {
      projectError = error.toString();
    }

    if (!context.mounted) {
      return null;
    }

    if (projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(projectError ?? 'Project create failed.')),
      );
      return null;
    }

    return _NewProject(id: projectId, draft: draft, resetWarning: resetWarning);
  }

  /// Aluminium: straight into the window catalogue, as before.
  Future<void> _handleCreateAluminiumProject(BuildContext context) async {
    final _NewProject? created = await _createProject(
      context,
      flow: EstimateFlow.fabrication,
    );
    if (created == null || !context.mounted) return;

    final EstimateSessionStore session = EstimateSessionStore(
      projectId: created.id,
      projectName: created.draft.projectName,
      projectLocation: created.draft.projectLocation,
      flow: EstimateFlow.fabrication,
      numberingMode: AppSettings.instance.numberingMode,
    );

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: FlowSteps.library.id),
        builder: (_) => WindowNavigationScreen.root(
          session: session,
          moduleTitle: 'Fabrication',
        ),
      ),
    );

    if (context.mounted) {
      _showResetWarning(context, created.resetWarning);
    }
  }

  /// Glass: straight to the row sheet.
  ///
  /// No window catalogue and no history in between -- a glass job is typed in
  /// as glass sizes from the start, so anything else on the way there is a
  /// detour.
  Future<void> _handleCreateGlassProject(BuildContext context) async {
    final _NewProject? created = await _createProject(
      context,
      flow: EstimateFlow.glass,
    );
    if (created == null || !context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: FlowSteps.glassSize.id),
        builder: (_) => GlassReportScreen(
          projectId: created.id,
          projectName: created.draft.projectName,
          projectLocation: created.draft.projectLocation,
        ),
      ),
    );

    if (context.mounted) {
      _showResetWarning(context, created.resetWarning);
    }
  }

  void _showResetWarning(BuildContext context, String? warning) {
    if (warning == null || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(warning)));
  }

  @override
  Widget build(BuildContext context) {
    return TutorialOverlay(
      screen: TutorialScreen.fabricationMenu,
      child: Scaffold(
        appBar: AppBar(title: const Text('Fabrication')),
        bottomNavigationBar: FlowProgressBar(stepId: FlowSteps.projects.id),
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
                    TutorialTarget(
                      id: 'fab.createProject',
                      child: PrimaryCardButton(
                        icon: Icons.add_box_outlined,
                        title: 'Create Aluminum Project  +',
                        subtitle:
                            'Windows and doors: pick from the catalogue, then cut, rate and report.',
                        accent: AppTheme.tealAccent,
                        onTap: () {
                          TutorialController.instance.advanceAfterTap();
                          _handleCreateAluminiumProject(context);
                        },
                      ),
                    ),
                    const SizedBox(height: AppTheme.space5),
                    PrimaryCardButton(
                      icon: Icons.grid_view_rounded,
                      title: 'Create Glass Project  +',
                      subtitle:
                          'Glass only: type the glass sizes and lay them out on sheets.',
                      accent: AppTheme.amberAccent,
                      onTap: () => _handleCreateGlassProject(context),
                    ),
                    const SizedBox(height: AppTheme.space5),
                    // One history for both kinds, each row saying which it is.
                    const RecentProjectsListSection(
                      flow: EstimateFlow.fabrication,
                      moduleTitle: 'Fabrication',
                      alsoInclude: <EstimateFlow>[EstimateFlow.glass],
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
      ),
    );
  }
}

/// A project that was just created, and anything worth telling the user about
/// how it went.
class _NewProject {
  final String id;
  final _ProjectDraft draft;

  /// Shown after the user has landed, not before -- a backend session reset
  /// that failed is worth knowing about but must not block the work.
  final String? resetWarning;

  const _NewProject({required this.id, required this.draft, this.resetWarning});
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
