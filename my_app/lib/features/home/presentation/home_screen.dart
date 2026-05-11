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
import '../../settings/presentation/settings_home_screen.dart';

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
        builder: (_) => NotificationsScreen(
          controller: _notificationsController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
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
            AppHeroHeader(
              eyebrow: 'QUICK AL',
              title: 'Estimation & Fabrication Workspace',
              subtitle:
                  'A refined business tool for aluminium windows, fabrication operations, and project settings.',
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
                    icon: Icons.calculate_rounded,
                    title: 'Estimation',
                    subtitle:
                        'Window selection, review flow, optimization, rates, material table, and billing.',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const EstimationMenuScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppTheme.space5),
                  PrimaryCardButton(
                    icon: Icons.construction_rounded,
                    title: 'Fabrication',
                    subtitle:
                        'Production-ready windows, cutting workflow, glass reporting, and fabrication outputs.',
                    accent: AppTheme.tealAccent,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const FabricationMenuScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppTheme.space5),
                  PrimaryCardButton(
                    icon: Icons.settings_suggest_rounded,
                    title: 'Settings',
                    subtitle:
                        'General, estimation, and fabrication configuration with structured controls.',
                    accent: AppTheme.amberAccent,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
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
          ],
        ),
      ),
    );
  }
}
