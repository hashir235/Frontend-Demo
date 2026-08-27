import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_screen_shell.dart';
import '../../../shared/widgets/primary_card_button.dart';
import '../../../shared/widgets/section_surface_card.dart';
import '../../estimation/presentation/recent_projects_screen.dart';
import '../../estimation/state/estimate_session_store.dart';
import '../../fabrication/presentation/glass_report_screen.dart';
import '../../flow_nav/models/flow_step.dart';
import '../../flow_nav/state/flow_progress.dart';
import '../../help_videos/help_video_button.dart';
import '../../help_videos/tutorial_videos.dart';
import 'new_glass_project_dialog.dart';

/// Glass work on its own, alongside aluminium rather than inside it.
///
/// It used to be reachable only from the Aluminium Fabrication menu, which
/// said the wrong thing about it: a glass job is often a different day's work,
/// sometimes a different person's, and it gets reopened on its own. Its own
/// module means its own projects and its own history, without the aluminium
/// jobs mixed in.
///
/// Jobs that arrive from the aluminium side land here too, so both routes end
/// up in the same list.
class GlassFabricationMenuScreen extends StatelessWidget {
  const GlassFabricationMenuScreen({super.key});

  Future<void> _createProject(BuildContext context) async {
    final NewGlassProject? created = await showNewGlassProjectDialog(context);
    if (created == null || !context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: FlowSteps.glassSize.id),
        builder: (_) => GlassReportScreen(
          projectId: created.projectId,
          projectName: created.projectName,
          projectLocation: created.projectLocation,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Glass Fabrication')),
      body: AppScreenShell(
        child: ListView(
          children: <Widget>[
            SectionSurfaceCard(
              title: 'Glass Fabrication',
              subtitle:
                  'Type glass sizes, lay them out on sheets, and reopen past '
                  'glass jobs.',
              // The other two module menus carry their own video button; this
              // one was the only entry screen without one.
              trailing: const HelpVideoButton(
                videoKey: TutorialVideos.glassMenu,
              ),
              child: Column(
                children: <Widget>[
                  PrimaryCardButton(
                    icon: Icons.add_rounded,
                    title: 'Create Glass Project  +',
                    subtitle:
                        'Start a glass job on its own — sizes typed in from '
                        'the start.',
                    accent: AppTheme.tealAccent,
                    onTap: () {
                      FlowProgress.instance.enter(fabricationFlow);
                      _createProject(context);
                    },
                  ),
                  const SizedBox(height: AppTheme.space5),
                  // Glass only. Aluminium jobs have their own module now, and
                  // mixing them here would undo the point of the split.
                  const RecentProjectsListSection(
                    flow: EstimateFlow.glass,
                    moduleTitle: 'Glass Fabrication',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
