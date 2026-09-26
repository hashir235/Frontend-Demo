import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_hero_header.dart';
import '../../../shared/widgets/app_screen_shell.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/primary_card_button.dart';
import '../../../shared/widgets/section_surface_card.dart';
import '../../estimation/data/new_project_session.dart';
import '../../estimation/data/project_repository.dart';
import '../../estimation/presentation/recent_projects_screen.dart';
import '../../estimation/presentation/window_navigation_screen.dart';
import '../../estimation/state/estimate_session_store.dart';
import '../../flow_nav/models/flow_step.dart';
import '../../flow_nav/presentation/flow_progress_bar.dart';
import '../../tutorial/tutorial_controller.dart';
import '../../tutorial/tutorial_overlay.dart';
import '../../tutorial/tutorial_step.dart';
import '../../tutorial/tutorial_target.dart';
import '../../help_videos/tutorial_videos.dart';

class FabricationMenuScreen extends StatelessWidget {
  const FabricationMenuScreen({super.key, this.projectRepository});

  /// Where new projects are written. Left out, the real server.
  final ProjectRepository? projectRepository;

  Future<_ProjectDraft?> _showProjectDialog(BuildContext context) async {
    return showDialog<_ProjectDraft>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _CreateProjectDialog(),
    );
  }

  /// Aluminium: straight into the window catalogue. The library opens the
  /// moment Create is pressed; the project is written to the server behind it.
  Future<void> _handleCreateAluminiumProject(BuildContext context) async {
    final _ProjectDraft? draft = await _showProjectDialog(context);
    if (draft == null || !context.mounted) return;

    final EstimateSessionStore session = startNewProjectSession(
      flow: EstimateFlow.fabrication,
      projectName: draft.projectName,
      projectLocation: draft.projectLocation,
      messenger: ScaffoldMessenger.of(context),
      repository: projectRepository,
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
                title: 'Fabrication Workflow',
                videoKey: TutorialVideos.fabricationMenu,
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
                    // Aluminium jobs only. Glass has its own module on Home
                    // with its own history, and listing glass jobs here as
                    // well would undo the point of separating them.
                    const RecentProjectsListSection(
                      flow: EstimateFlow.fabrication,
                      moduleTitle: 'Aluminium Fabrication',
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
