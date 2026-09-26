import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../flow_nav/models/flow_step.dart';
import '../../flow_nav/presentation/flow_progress_bar.dart';
import '../../tutorial/tutorial_controller.dart';
import '../../tutorial/tutorial_overlay.dart';
import '../../tutorial/tutorial_step.dart';
import '../../tutorial/tutorial_target.dart';
import '../../../shared/widgets/app_hero_header.dart';
import '../../../shared/widgets/app_screen_shell.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/primary_card_button.dart';
import '../../../shared/widgets/section_surface_card.dart';
import '../data/new_project_session.dart';
import '../data/project_repository.dart';
import '../state/estimate_session_store.dart';
import 'recent_projects_screen.dart';
import 'window_navigation_screen.dart';
import '../../help_videos/tutorial_videos.dart';

class EstimationMenuScreen extends StatelessWidget {
  const EstimationMenuScreen({super.key, this.projectRepository});

  /// Where new projects are written. Left out, the real server.
  final ProjectRepository? projectRepository;

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

    // The library opens now; the project is written to the server behind it.
    final EstimateSessionStore session = startNewProjectSession(
      flow: EstimateFlow.estimation,
      projectName: draft.projectName,
      projectLocation: draft.projectLocation,
      messenger: ScaffoldMessenger.of(context),
      repository: projectRepository,
    );

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: FlowSteps.library.id),
        builder: (_) => WindowNavigationScreen.root(session: session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Estimation')),
      bottomNavigationBar: FlowProgressBar(stepId: FlowSteps.projects.id),
      body: TutorialOverlay(
        screen: TutorialScreen.projectMenu,
        child: AppScreenShell(
          child: ListView(
            children: <Widget>[
              AppHeroHeader(
                eyebrow: 'ESTIMATION',
                title: 'Estimation process for quotation',
                videoKey: TutorialVideos.estimationMenu,
                subtitle:
                    'Create projects, pick windows visually, and move through review, optimization, rates, and billing with a consistent premium workflow.',
                trailing: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: AppTheme.brandGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                  child: const Icon(
                    Icons.calculate_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.space6),
              SectionSurfaceCard(
                title: 'Start Work',
                subtitle:
                    'Create a new estimation project or continue from a saved one.',
                child: Column(
                  children: <Widget>[
                    TutorialTarget(
                      id: 'menu.createProject',
                      child: PrimaryCardButton(
                        icon: Icons.add_box_outlined,
                        title: 'Create Project',
                        subtitle:
                            'Capture project details and open the full window catalogue.',
                        onTap: () {
                          TutorialController.instance.advanceAfterTap();
                          _handleCreateProject(context);
                        },
                      ),
                    ),
                    const SizedBox(height: AppTheme.space5),
                    const RecentProjectsListSection(
                      flow: EstimateFlow.estimation,
                      moduleTitle: 'Estimation',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.space6),
              const Row(
                children: <Widget>[
                  Expanded(
                    child: MetricCard(
                      label: 'Workflow',
                      value: 'Create -> Review -> Optimize',
                      icon: Icons.timeline_rounded,
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
