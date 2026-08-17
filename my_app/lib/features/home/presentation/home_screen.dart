import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/network/auth_http_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/notifications/data/notifications_api_client.dart';
import '../../../features/notifications/presentation/notifications_screen.dart';
import '../../../features/notifications/state/notifications_controller.dart';
import '../../../shared/widgets/app_hero_header.dart';
import '../../../shared/widgets/app_screen_shell.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/primary_card_button.dart';
import '../../../shared/widgets/section_surface_card.dart';
import '../../../shared/widgets/social_links_card.dart';
import '../../estimation/presentation/estimation_menu_screen.dart';
import '../../fabrication/presentation/fabrication_menu_screen.dart';
import '../../flow_nav/models/flow_step.dart';
import '../../flow_nav/presentation/flow_progress_bar.dart';
import '../../flow_nav/state/flow_progress.dart';
import '../../settings/presentation/settings_home_screen.dart';
import '../../review_prompt/review_prompt_dialog.dart';
import '../../review_prompt/review_prompter.dart';
import '../../subscription/presentation/plan_status_strip.dart';
import '../../subscription/presentation/subscription_gate_screen.dart';
import '../../tutorial/tutorial_controller.dart';
import '../../tutorial/tutorial_overlay.dart';
import '../../tutorial/tutorial_step.dart';
import '../../tutorial/tutorial_target.dart';
import '../../tutorial/urdu_text.dart';

class HomeScreen extends StatefulWidget {
  final AuthHttpClient authClient;

  const HomeScreen({super.key, required this.authClient});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final NotificationsController _notificationsController;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _notificationsController = NotificationsController(
      NotificationsApiClient(widget.authClient),
    );
    _notificationsController.load();
    _loadVersion();
    _offerTutorialOnFirstRun();
    _maybeAskForRating();
    // Nothing started yet: show the lone Home bubble. A journey already in
    // progress is left alone -- Home stays mounted underneath it.
    if (FlowProgress.instance.flow == null) {
      FlowProgress.instance.enter(homeFlow);
    }
  }

  /// A first-time user lands here straight after workshop setup, so the tour
  /// starts itself -- once, ever. After this it only runs when someone asks
  /// for it from Home or Settings.
  Future<void> _offerTutorialOnFirstRun() async {
    if (await TutorialController.instance.hasSeen()) return;
    if (!mounted) return;
    // Written before the tour opens, not when it closes. Someone who kills
    // the app halfway through has still had their one automatic showing --
    // otherwise it would greet them again on every launch.
    await TutorialController.instance.markSeen();
    if (!mounted) return;
    // Let Home finish laying out, otherwise the first step has nothing to
    // point at yet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) TutorialController.instance.start();
    });
  }

  /// Asks for a rating once the user has had the app a week.
  ///
  /// Never on the same launch as the tour: a first-time user meeting a rating
  /// dialog before they have used anything would rightly ignore it, and we
  /// would have spent our one polite ask on nothing.
  Future<void> _maybeAskForRating() async {
    final ReviewPrompter prompter = ReviewPrompter();
    await prompter.noteAppOpened();
    if (!await TutorialController.instance.hasSeen()) return;
    if (!mounted) return;
    // After the first frame, so the dialog does not fight the screen coming up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeAskForReview(context, prompter: prompter);
    });
  }

  Future<void> _loadVersion() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _appVersion = 'v${info.version}');
      }
    } catch (_) {
      if (mounted) setState(() => _appVersion = 'v1.0.1');
    }
  }

  @override
  void dispose() {
    _notificationsController.dispose();
    super.dispose();
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            NotificationsScreen(controller: _notificationsController),
      ),
    );
  }

  /// Anyone who gets lost can replay a walkthrough from here, and these are the
  /// first things on Home so they are easy to find when you need them.
  ///
  /// Two separate tours: quoting a customer and cutting the job are different
  /// work, and plenty of people only ever do one of them.
  Widget _buildTutorialButtons(BuildContext context) {
    return Column(
      children: <Widget>[
        _buildTutorialButton(
          context,
          title: 'ایسٹیمیشن کیسے کریں',
          subtitle: 'ناپ سے گاہک کے بل تک — اردو میں',
          accent: AppTheme.tealAccent,
          onTap: () =>
              TutorialController.instance.start(tour: TutorialTour.estimation),
        ),
        const SizedBox(height: AppTheme.space4),
        _buildTutorialButton(
          context,
          title: 'فیبریکیشن کیسے کریں',
          subtitle: 'کٹنگ لسٹ اور شیشے کی رپورٹ — اردو میں',
          accent: AppTheme.amberAccent,
          onTap: () =>
              TutorialController.instance.start(tour: TutorialTour.fabrication),
        ),
      ],
    );
  }

  Widget _buildTutorialButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Material(
      color: accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space4),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppTheme.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: UrduText.heading(fontSize: 18)),
                    Text(subtitle, style: UrduText.caption()),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppTheme.slate),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      // A single bubble here, which grows into the chain once a job starts.
      bottomNavigationBar: FlowProgressBar(stepId: FlowSteps.home.id),
      appBar: AppBar(
        title: const Text('Quick AL'),
        actions: <Widget>[
          ListenableBuilder(
            listenable: _notificationsController,
            builder: (BuildContext context, _) {
              final int unread = _notificationsController.unreadCount;
              return Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: _openNotifications,
                    tooltip: 'Notifications',
                  ),
                  if (unread > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: AppTheme.danger,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: TutorialOverlay(
        screen: TutorialScreen.home,
        child: AppScreenShell(
          child: ListView(
            children: <Widget>[
              // First thing on the screen: what you are on and how long is
              // left. People were opening Settings to find this out, and in
              // the last few days it is the thing that changes what they do
              // next.
              const PlanStatusStrip(),
              AppHeroHeader(
                eyebrow: 'QUICK AL',
                title: 'Aluminium Window & Glass Workspace',
                subtitle:
                    'A refined business tool for aluminium windows, glass work, fabrication operations, and project settings.',
                trailing: Container(
                  width: 132,
                  height: 132,
                  padding: const EdgeInsets.all(AppTheme.space2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(color: AppTheme.line),
                    boxShadow: AppTheme.softShadow(),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    child: Image.asset(
                      'assets/images/quick_al_icon.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.space6),
              SectionSurfaceCard(
                title: 'Workspace',
                subtitle:
                    'Choose the module that matches the current project phase.',
                child: Column(
                  children: <Widget>[
                    TutorialTarget(
                      id: 'home.estimation',
                      child: PrimaryCardButton(
                        // A window with its panes: this module is where a
                        // window gets measured and priced.
                        icon: Icons.window_rounded,
                        title: 'Aluminium Estimation',
                        subtitle:
                            'Window selection, review flow, optimization, rates, material table, and billing.',
                        onTap: () {
                          // While the tour is on this step, tapping is the step.
                          TutorialController.instance.advanceAfterTap();
                          FlowProgress.instance.enter(estimationFlow);
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              settings: RouteSettings(
                                name: FlowSteps.projects.id,
                              ),
                              builder: (_) => const SubscriptionGateScreen(
                                child: EstimationMenuScreen(),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppTheme.space5),
                    TutorialTarget(
                      id: 'home.fabrication',
                      child: PrimaryCardButton(
                        // A saw blade: this module is where bars get cut.
                        icon: Icons.carpenter_rounded,
                        title: 'Aluminium Fabrication',
                        subtitle:
                            'Production-ready windows, cutting workflow, glass reporting, and fabrication outputs.',
                        accent: AppTheme.tealAccent,
                        onTap: () {
                          TutorialController.instance.advanceAfterTap();
                          FlowProgress.instance.enter(fabricationFlow);
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              settings: RouteSettings(
                                name: FlowSteps.projects.id,
                              ),
                              builder: (_) => const SubscriptionGateScreen(
                                child: FabricationMenuScreen(),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppTheme.space5),
                    PrimaryCardButton(
                      icon: Icons.settings_suggest_rounded,
                      title: 'Settings',
                      subtitle:
                          'General, estimation, and fabrication configuration with structured controls.',
                      accent: AppTheme.amberAccent,
                      onTap: () {
                        FlowProgress.instance.enter(settingsRootFlow);
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            settings: RouteSettings(
                              name: FlowSteps.settings.id,
                            ),
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.space6),
              const SocialLinksCard(),
              const SizedBox(height: AppTheme.space6),
              // The tours sit down here rather than above the modules: someone
              // opening the app to do a job wants the job, not the lesson.
              _buildTutorialButtons(context),
              const SizedBox(height: AppTheme.space6),
              Row(
                children: <Widget>[
                  Expanded(
                    child: MetricCard(
                      label: 'App version',
                      value: _appVersion.isEmpty ? 'v1.0.1' : _appVersion,
                      icon: Icons.verified_rounded,
                    ),
                  ),
                  const SizedBox(width: AppTheme.space4),
                  Expanded(
                    child: MetricCard(
                      label: 'Modules',
                      value: '3',
                      icon: Icons.dashboard_customize_rounded,
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
