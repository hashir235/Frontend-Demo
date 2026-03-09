import 'package:flutter/material.dart';
import 'package:my_app/core/theme/app_theme.dart';
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
      _showMessage('Full name kam az kam 2 characters ka hona chahiye.');
      return;
    }
    if (!email.contains('@')) {
      _showMessage('Valid email address zaroori hai.');
      return;
    }
    if (password.length < 8) {
      _showMessage('Password kam az kam 8 characters ka hona chahiye.');
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
                      'Login ke baghair app home workflow open nahi karegi. Apna account use karo ya naya account banao.',
                  trailing: Container(
                    width: 140,
                    height: 140,
                    padding: const EdgeInsets.all(AppTheme.space3),
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
                  title: _registerMode ? 'Create Account' : 'Sign In',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
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
                            labelText: 'Full Name',
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
                          labelText: 'Email',
                          hintText: 'you@example.com',
                        ),
                      ),
                      const SizedBox(height: AppTheme.space5),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        onSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          hintText: 'At least 8 characters',
                        ),
                      ),
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
                SectionSurfaceCard(
                  accented: true,
                  title: 'Current Access Model',
                  child: Text(
                    'Ab app ko use karne ke liye pehle login zaroori hoga. Is se home screen direct open nahi hogi aur saved projects user account ke sath map kiye jayenge.',
                    style: Theme.of(context).textTheme.bodyLarge,
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
