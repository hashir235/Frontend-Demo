import 'package:flutter/material.dart';

import 'core/network/auth_http_client.dart';
import 'core/theme/app_theme.dart';
import 'features/app_update/app_update_service.dart';
import 'features/app_update/presentation/force_update_screen.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/auth/state/auth_controller.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/subscription/presentation/subscription_gate_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quick AL',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _UpdateGate(),
    );
  }
}

/// Runs the startup version check (direct build only) before the app is usable.
/// A forced update fully blocks the app; an optional update shows a one-time
/// dialog over the normal flow. On the Play build or any error this resolves to
/// [AppUpdateRequirement.none] immediately, so it never blocks by mistake.
class _UpdateGate extends StatefulWidget {
  const _UpdateGate();

  @override
  State<_UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<_UpdateGate> {
  final AppUpdateService _updateService = AppUpdateService();
  late final Future<AppUpdateStatus> _checkFuture;
  bool _optionalDialogShown = false;

  @override
  void initState() {
    super.initState();
    _checkFuture = _updateService.check();
  }

  void _maybeShowOptional(AppUpdateStatus status) {
    if (_optionalDialogShown ||
        status.requirement != AppUpdateRequirement.optional) {
      return;
    }
    _optionalDialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showOptionalUpdateDialog(
        context,
        status: status,
        service: _updateService,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUpdateStatus>(
      future: _checkFuture,
      builder: (BuildContext context, AsyncSnapshot<AppUpdateStatus> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _AuthBootstrapScreen();
        }
        final AppUpdateStatus status = snapshot.data ?? AppUpdateStatus.none;
        if (status.requirement == AppUpdateRequirement.forced) {
          return ForceUpdateScreen(status: status, service: _updateService);
        }
        _maybeShowOptional(status);
        return const _AuthGate();
      },
    );
  }
}

/// The normal auth-driven content: bootstrap → authenticated → guest.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final AuthController authController = AuthController.instance
      ..ensureInitialized();
    return AnimatedBuilder(
      animation: authController,
      builder: (BuildContext context, _) {
        return KeyedSubtree(
          key: ValueKey<String>(
            !authController.isInitialized
                ? 'launching'
                : authController.isAuthenticated
                ? 'authenticated'
                : 'guest',
          ),
          child: !authController.isInitialized
              ? const _AuthBootstrapScreen()
              : authController.isAuthenticated
              ? SubscriptionGateScreen(
                  child: HomeScreen(authClient: AuthHttpClient()),
                )
              : const AuthScreen(),
        );
      },
    );
  }
}

class _AuthBootstrapScreen extends StatelessWidget {
  const _AuthBootstrapScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFFF6FBFC), Color(0xFFE9F1F4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 120,
                height: 120,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset(
                    'assets/images/quick_al_icon.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Quick AL',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Restoring your workspace...',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
