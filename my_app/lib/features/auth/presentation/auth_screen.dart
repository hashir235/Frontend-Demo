import 'package:flutter/material.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/features/auth/data/auth_api_client.dart';
import 'package:my_app/features/auth/state/auth_controller.dart';
import 'package:my_app/shared/widgets/app_hero_header.dart';
import 'package:my_app/shared/widgets/app_screen_shell.dart';
import 'package:my_app/shared/widgets/section_surface_card.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthController _authController = AuthController.instance;
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _registerMode = false;
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    // If we arrived here because the session was invalidated remotely (account
    // opened on another device), surface that reason once.
    final String? pendingMessage = _authController.errorMessage;
    if (pendingMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showMessage(pendingMessage);
        _authController.clearError();
      });
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    _authController.clearError();

    final String fullName = _fullNameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    if (_registerMode && fullName.length < 2) {
      _showMessage('Full name must be at least 2 characters long.');
      return;
    }
    if (!email.contains('@')) {
      _showMessage('A valid email address is required.');
      return;
    }
    if (password.length < 8) {
      _showMessage('Password must be at least 8 characters long.');
      return;
    }

    final bool ok = _registerMode
        ? await _authController.register(
            fullName: fullName,
            email: email,
            password: password,
          )
        : await _authController.signIn(email: email, password: password);

    if (!ok && mounted && _authController.errorMessage != null) {
      _showMessage(_authController.errorMessage!);
    }
  }

  Future<void> _openForgotPasswordDialog() async {
    FocusScope.of(context).unfocus();
    final String? completedResetEmail = await Navigator.of(context)
        .push<String>(
          MaterialPageRoute<String>(
            builder: (BuildContext context) => _PasswordResetScreen(
              initialEmail: _emailController.text.trim(),
            ),
          ),
        );

    if (!mounted || completedResetEmail == null) {
      return;
    }

    setState(() {
      _registerMode = false;
      _emailController.text = completedResetEmail;
      _passwordController.clear();
      _passwordVisible = false;
    });
    _showMessage('Password updated. Sign in with your new password.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildHeroVisual() {
    return Container(
      width: 154,
      height: 210,
      padding: const EdgeInsets.all(AppTheme.space4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF123B63), Color(0xFF1F5D95)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 58,
            height: 58,
            padding: const EdgeInsets.all(AppTheme.space3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Image.asset(
              'assets/images/quick_al_icon.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          const Spacer(),
          _buildVisualChip(Icons.grid_view_rounded, 'Projects'),
          const SizedBox(height: AppTheme.space3),
          _buildVisualChip(Icons.picture_as_pdf_rounded, 'Reports'),
          const SizedBox(height: AppTheme.space3),
          _buildVisualChip(Icons.verified_user_rounded, 'Secure access'),
        ],
      ),
    );
  }

  Widget _buildVisualChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space3,
        vertical: AppTheme.space3,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: AppTheme.space3),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessPanel(BuildContext context) {
    return SectionSurfaceCard(
      accented: true,
      title: 'What your account unlocks',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Your Quick AL account keeps your projects, report flow, and fabrication context tied to one protected workspace.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppTheme.space5),
          Wrap(
            spacing: AppTheme.space3,
            runSpacing: AppTheme.space3,
            children: const <Widget>[
              _AccessPill(
                icon: Icons.folder_copy_rounded,
                label: 'Saved project history',
              ),
              _AccessPill(
                icon: Icons.precision_manufacturing_rounded,
                label: 'Fabrication continuity',
              ),
              _AccessPill(
                icon: Icons.request_quote_rounded,
                label: 'Billing workflow',
              ),
              _AccessPill(
                icon: Icons.lock_person_rounded,
                label: 'Protected access',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShowcaseRow() {
    return SizedBox(
      height: 236,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: const <Widget>[
          _StoryCard(
            icon: Icons.space_dashboard_rounded,
            title: 'Estimation Workspace',
            subtitle:
                'Move from window input to optimization with a cleaner, structured flow.',
            tone: Color(0xFFE7F0F8),
            accent: AppTheme.royalBlue,
            bulletA: 'Organized window entry',
            bulletB: 'Section-aware review',
            bulletC: 'Project continuity',
          ),
          SizedBox(width: AppTheme.space4),
          _StoryCard(
            icon: Icons.precision_manufacturing_rounded,
            title: 'Fabrication Flow',
            subtitle:
                'Keep production outputs readable and connected to the original project.',
            tone: Color(0xFFE3F3F2),
            accent: AppTheme.tealAccent,
            bulletA: 'Glass and cutting reports',
            bulletB: 'Workshop-ready detail',
            bulletC: 'Cleaner handoff',
          ),
          SizedBox(width: AppTheme.space4),
          _StoryCard(
            icon: Icons.receipt_long_rounded,
            title: 'Billing Confidence',
            subtitle:
                'Review material totals, rates, and bill outputs from one polished place.',
            tone: Color(0xFFFBF1E3),
            accent: AppTheme.amberAccent,
            bulletA: 'Material tables',
            bulletB: 'Invoice-ready totals',
            bulletC: 'PDF delivery flow',
          ),
        ],
      ),
    );
  }

  Widget _buildWhyUsePanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFFDFDFE), Color(0xFFF3F8FB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.line),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.royalBlue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppTheme.royalBlue,
                ),
              ),
              const SizedBox(width: AppTheme.space4),
              Expanded(
                child: Text(
                  'Why use Quick AL?',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space5),
          Text(
            'Quick AL keeps estimation, fabrication, and billing in one connected workspace so teams spend less time translating data and more time finishing projects accurately.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppTheme.space5),
          const Row(
            children: <Widget>[
              Expanded(
                child: _MiniStatCard(
                  icon: Icons.layers_rounded,
                  value: 'One flow',
                  label: 'Input to PDF without losing context',
                ),
              ),
              SizedBox(width: AppTheme.space4),
              Expanded(
                child: _MiniStatCard(
                  icon: Icons.bolt_rounded,
                  value: 'Less friction',
                  label: 'Fewer manual steps between decisions',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _authController,
      builder: (BuildContext context, _) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(title: const Text('Quick AL Access')),
          body: AppScreenShell(
            child: ListView(
              children: <Widget>[
                AppHeroHeader(
                  eyebrow: 'SECURE ACCESS',
                  title: 'Sign in to Quick AL',
                  subtitle:
                      'Access your estimation workspace, fabrication flow, saved projects, and PDF-ready reporting from one account.',
                  trailing: _buildHeroVisual(),
                ),
                const SizedBox(height: AppTheme.space6),
                SectionSurfaceCard(
                  title: _registerMode ? 'Create your account' : 'Welcome back',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _registerMode
                            ? 'Create a workspace account to start saving projects, generating reports, and moving from estimate to fabrication with continuity.'
                            : 'Sign in to continue with your saved projects, reports, and production workflow.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppTheme.space5),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Sign In'),
                              selected: !_registerMode,
                              onSelected: (_) {
                                setState(() {
                                  _registerMode = false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: AppTheme.space4),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Create Account'),
                              selected: _registerMode,
                              onSelected: (_) {
                                setState(() {
                                  _registerMode = true;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.space6),
                      if (_registerMode) ...<Widget>[
                        TextField(
                          controller: _fullNameController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                            hintText: 'Muhammad Ali',
                          ),
                        ),
                        const SizedBox(height: AppTheme.space5),
                      ],
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          hintText: 'you@example.com',
                        ),
                      ),
                      const SizedBox(height: AppTheme.space5),
                      TextField(
                        controller: _passwordController,
                        obscureText: !_passwordVisible,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'At least 8 characters',
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _passwordVisible = !_passwordVisible;
                              });
                            },
                            icon: Icon(
                              _passwordVisible
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                          ),
                        ),
                      ),
                      if (!_registerMode) ...<Widget>[
                        const SizedBox(height: AppTheme.space2),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _authController.isBusy
                                ? null
                                : _openForgotPasswordDialog,
                            child: const Text('Forgot Password?'),
                          ),
                        ),
                      ] else
                        const SizedBox(height: AppTheme.space6),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _authController.isBusy ? null : _submit,
                          icon: _authController.isBusy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                  ),
                                )
                              : Icon(
                                  _registerMode
                                      ? Icons.person_add_alt_1_rounded
                                      : Icons.login_rounded,
                                ),
                          label: Text(
                            _registerMode ? 'Create Account' : 'Sign In',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.space6),
                _buildAccessPanel(context),
                const SizedBox(height: AppTheme.space6),
                _buildShowcaseRow(),
                const SizedBox(height: AppTheme.space6),
                _buildWhyUsePanel(context),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PasswordResetScreen extends StatefulWidget {
  final String initialEmail;

  const _PasswordResetScreen({required this.initialEmail});

  @override
  State<_PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<_PasswordResetScreen> {
  final AuthController _authController = AuthController.instance;
  late final TextEditingController _emailController = TextEditingController(
    text: widget.initialEmail,
  );
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _codeSent = false;
  bool _resetVisible = false;
  bool _confirmVisible = false;
  bool _isSubmitting = false;
  String _sentMessage = '';
  String _maskedEmail = '';
  int _expiresInMinutes = 15;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _requestCode() async {
    final String email = _emailController.text.trim();
    if (!email.contains('@')) {
      _showMessage('A valid email address is required.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });
    _authController.clearError();
    final PasswordResetRequestResult? result = await _authController
        .requestPasswordReset(email: email);
    if (!mounted) {
      return;
    }

    if (result == null) {
      setState(() {
        _isSubmitting = false;
      });
      _showMessage(
        _authController.errorMessage ?? 'Password reset request failed.',
      );
      return;
    }

    setState(() {
      _codeSent = true;
      _isSubmitting = false;
      _sentMessage = result.message;
      _maskedEmail = result.maskedEmail;
      _expiresInMinutes = result.expiresInMinutes;
      _codeController.text = result.devResetCode ?? '';
    });
  }

  Future<void> _submitReset() async {
    final String email = _emailController.text.trim();
    final String code = _codeController.text.replaceAll(RegExp(r'\D'), '');
    final String password = _newPasswordController.text;
    final String confirm = _confirmPasswordController.text;

    if (!email.contains('@')) {
      _showMessage('A valid email address is required.');
      return;
    }
    if (code.length != 6) {
      _showMessage('Enter the 6 digit reset code.');
      return;
    }
    if (password.length < 8) {
      _showMessage('Your new password must be at least 8 characters long.');
      return;
    }
    if (password != confirm) {
      _showMessage('The passwords do not match.');
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isSubmitting = true;
    });
    _authController.clearError();
    final bool ok = await _authController.confirmPasswordReset(
      email: email,
      code: code,
      password: password,
    );
    if (!mounted) {
      return;
    }

    if (!ok) {
      setState(() {
        _isSubmitting = false;
      });
      _showMessage(_authController.errorMessage ?? 'Password reset failed.');
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(email);
  }

  void _changeEmail() {
    setState(() {
      _codeSent = false;
      _codeController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _sentMessage = '';
      _maskedEmail = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _authController,
      builder: (BuildContext context, _) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(title: const Text('Reset Password')),
          body: AppScreenShell(
            child: ListView(
              children: <Widget>[
                AppHeroHeader(
                  eyebrow: 'ACCOUNT RECOVERY',
                  title: _codeSent ? 'Enter reset code' : 'Reset password',
                  subtitle: '',
                  trailing: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: AppTheme.royalBlue.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      color: AppTheme.royalBlue,
                      size: 42,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.space6),
                SectionSurfaceCard(
                  title: _codeSent ? 'Verify your email' : 'Find your account',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _codeSent
                            ? (_maskedEmail.isEmpty
                                  ? _sentMessage
                                  : '$_sentMessage Check $_maskedEmail.')
                            : 'Enter the email on your Quick AL account. A one time reset code is required before the password can be changed.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (_codeSent) ...<Widget>[
                        const SizedBox(height: AppTheme.space3),
                        Text(
                          'Code expires in $_expiresInMinutes minutes and can be used only once.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                      const SizedBox(height: AppTheme.space5),
                      TextField(
                        controller: _emailController,
                        enabled: !_codeSent,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Registered email',
                          hintText: 'you@example.com',
                        ),
                      ),
                      if (_codeSent) ...<Widget>[
                        const SizedBox(height: AppTheme.space4),
                        TextField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          maxLength: 6,
                          decoration: const InputDecoration(
                            labelText: 'Reset code',
                            hintText: '6 digit code',
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: AppTheme.space4),
                        TextField(
                          controller: _newPasswordController,
                          obscureText: !_resetVisible,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'New password',
                            hintText: 'At least 8 characters',
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _resetVisible = !_resetVisible;
                                });
                              },
                              icon: Icon(
                                _resetVisible
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.space4),
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: !_confirmVisible,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submitReset(),
                          decoration: InputDecoration(
                            labelText: 'Confirm password',
                            hintText: 'Repeat your new password',
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _confirmVisible = !_confirmVisible;
                                });
                              },
                              icon: Icon(
                                _confirmVisible
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppTheme.space6),
                      if (_codeSent)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _isSubmitting ? null : _changeEmail,
                            child: const Text('Change email'),
                          ),
                        ),
                      if (_codeSent) const SizedBox(height: AppTheme.space3),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : _codeSent
                              ? _submitReset
                              : _requestCode,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                  ),
                                )
                              : Icon(
                                  _codeSent
                                      ? Icons.lock_open_rounded
                                      : Icons.mark_email_read_rounded,
                                ),
                          label: Text(
                            _codeSent ? 'Reset password' : 'Send code',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AccessPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _AccessPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space4,
        vertical: AppTheme.space3,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: AppTheme.royalBlue),
          const SizedBox(width: AppTheme.space3),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color tone;
  final Color accent;
  final String bulletA;
  final String bulletB;
  final String bulletC;

  const _StoryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tone,
    required this.accent,
    required this.bulletA,
    required this.bulletB,
    required this.bulletC,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 252,
      padding: const EdgeInsets.all(AppTheme.space5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.line),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: 92,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[tone, accent.withValues(alpha: 0.18)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              children: <Widget>[
                Positioned(
                  right: -10,
                  top: -8,
                  child: CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                Positioned(
                  left: 16,
                  top: 16,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: accent, size: 24),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Container(
                    width: 34,
                    height: 34,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset(
                      'assets/images/quick_al_icon.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space5),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppTheme.space3),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppTheme.space5),
          _StoryPoint(label: bulletA),
          const SizedBox(height: AppTheme.space3),
          _StoryPoint(label: bulletB),
          const SizedBox(height: AppTheme.space3),
          _StoryPoint(label: bulletC),
        ],
      ),
    );
  }
}

class _StoryPoint extends StatelessWidget {
  final String label;

  const _StoryPoint({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppTheme.royalBlue.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 14,
            color: AppTheme.royalBlue,
          ),
        ),
        const SizedBox(width: AppTheme.space3),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _MiniStatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.royalBlue.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.royalBlue),
          ),
          const SizedBox(height: AppTheme.space4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppTheme.space2),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
