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
import '../../estimation/presentation/estimation_menu_screen.dart';
import '../../fabrication/presentation/fabrication_menu_screen.dart';
import '../../flow_nav/models/flow_step.dart';
import '../../flow_nav/presentation/flow_progress_bar.dart';
import '../../flow_nav/state/flow_progress.dart';
import '../../settings/presentation/settings_home_screen.dart';
import '../../review_prompt/review_prompt_dialog.dart';
import '../../review_prompt/review_prompter.dart';
import '../../subscription/data/subscription_api_client.dart';
import '../../subscription/models/home_plan_look.dart';
import '../../subscription/models/subscription_models.dart';
import '../../subscription/presentation/plan_status_strip.dart';
import '../../subscription/presentation/plan_validity_card.dart';
import '../../subscription/state/plan_shade.dart';
import '../../glass_fabrication/presentation/glass_fabrication_menu_screen.dart';
import '../../subscription/presentation/subscription_gate_screen.dart';
import '../../help_videos/tutorial_videos.dart';

class HomeScreen extends StatefulWidget {
  final AuthHttpClient authClient;

  /// Injected in tests; the real screen builds one on [authClient].
  final SubscriptionApiClient? subscriptionClient;

  const HomeScreen({
    super.key,
    required this.authClient,
    this.subscriptionClient,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final NotificationsController _notificationsController;
  late final SubscriptionApiClient _subscriptionClient =
      widget.subscriptionClient ??
      SubscriptionApiClient(httpClient: widget.authClient);
  String _appVersion = '';

  /// The shop's plan, once it has been read. Null for anyone who has never
  /// had one -- they keep the usual Home.
  HomePlanLook? _plan;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationsController = NotificationsController(
      NotificationsApiClient(widget.authClient),
    );
    _notificationsController.load();
    _loadPlan();
    _loadVersion();
    _maybeAskForRating();
    // Nothing started yet: show the lone Home bubble. A journey already in
    // progress is left alone -- Home stays mounted underneath it.
    if (FlowProgress.instance.flow == null) {
      FlowProgress.instance.enter(homeFlow);
    }
  }

  /// Asks for a rating once the user has had the app a week -- never on a
  /// first launch, which [ReviewPrompter] sees to: a first-time user meeting
  /// a rating dialog before they have used anything would rightly ignore it.
  Future<void> _maybeAskForRating() async {
    final ReviewPrompter prompter = ReviewPrompter();
    await prompter.noteAppOpened();
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

  /// Reads the plan again whenever the app comes back to the front: a plan
  /// renewed from the panel, or one that ran out while the phone was in a
  /// pocket, shows on Home without restarting the app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadPlan();
  }

  Future<void> _loadPlan() async {
    try {
      final SubscriptionStatus status = await _subscriptionClient.fetchStatus();
      if (!mounted) return;
      final HomePlanLook? plan = HomePlanLook.from(status);
      setState(() => _plan = plan);
      // Every screen's background, not only this one's. Home stays mounted
      // under every journey, so this read keeps the whole app current.
      PlanShade.instance.value = plan?.tone;
    } catch (_) {
      // Offline, or the server is having a moment: Home keeps whatever it
      // last showed rather than guessing.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      body: AppScreenShell(
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
              videoKey: TutorialVideos.home,
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
                  PrimaryCardButton(
                    // An invoice: what this module is for is arriving at a
                    // priced bill the customer is handed.
                    icon: Icons.receipt_long_rounded,
                    title: 'Aluminium Estimation',
                    videoKey: TutorialVideos.homeEstimation,
                    subtitle:
                        'Window selection, review flow, optimization, rates, material table, and billing.',
                    onTap: () {
                      FlowProgress.instance.enter(estimationFlow);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          settings: RouteSettings(name: FlowSteps.projects.id),
                          builder: (_) => const SubscriptionGateScreen(
                            child: EstimationMenuScreen(),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppTheme.space5),
                  PrimaryCardButton(
                    // A cutter: this module is where the bars actually get cut
                    // to length on the table saw.
                    icon: Icons.content_cut_rounded,
                    title: 'Aluminium Fabrication',
                    videoKey: TutorialVideos.homeFabrication,
                    subtitle:
                        'Production-ready windows, cutting workflow, glass reporting, and fabrication outputs.',
                    accent: AppTheme.tealAccent,
                    onTap: () {
                      FlowProgress.instance.enter(fabricationFlow);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          settings: RouteSettings(name: FlowSteps.projects.id),
                          builder: (_) => const SubscriptionGateScreen(
                            child: FabricationMenuScreen(),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppTheme.space5),
                  // Glass stands beside aluminium rather than inside it: it
                  // is often a different day's work, and it gets reopened on
                  // its own.
                  PrimaryCardButton(
                    icon: Icons.window_rounded,
                    title: 'Glass Fabrication',
                    videoKey: TutorialVideos.homeGlass,
                    subtitle:
                        'Glass sizes, sheet optimization, and glass jobs '
                        'with their own history.',
                    accent: AppTheme.sky,
                    onTap: () {
                      FlowProgress.instance.enter(fabricationFlow);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          settings: RouteSettings(name: FlowSteps.projects.id),
                          builder: (_) => const SubscriptionGateScreen(
                            child: GlassFabricationMenuScreen(),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppTheme.space5),
                  PrimaryCardButton(
                    icon: Icons.settings_suggest_rounded,
                    title: 'Settings',
                    videoKey: TutorialVideos.homeSettings,
                    subtitle:
                        'General, estimation, and fabrication configuration with structured controls.',
                    accent: AppTheme.amberAccent,
                    onTap: () {
                      FlowProgress.instance.enter(settingsRootFlow);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          settings: RouteSettings(name: FlowSteps.settings.id),
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
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
            // Which plan, and the date it runs to.
            if (_plan != null) ...<Widget>[
              const SizedBox(height: AppTheme.space6),
              PlanValidityCard(look: _plan!),
            ],
          ],
        ),
      ),
    );
  }
}
