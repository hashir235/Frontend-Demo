import 'package:flutter/material.dart';
import 'package:my_app/core/config/api_config.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/features/auth/state/auth_controller.dart';
import 'package:my_app/shared/widgets/app_hero_header.dart';
import 'package:my_app/shared/widgets/app_screen_shell.dart';
import 'package:my_app/shared/widgets/section_surface_card.dart';
import 'package:my_app/features/tutorial/urdu_text.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthController _authController = AuthController.instance;

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

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signInWithGoogle() async {
    FocusScope.of(context).unfocus();
    _authController.clearError();
    final bool ok = await _authController.signInWithGoogle();
    // On success the auth gate rebuilds and routes to workshop onboarding (new
    // account) or Home. A silent cancel leaves errorMessage null.
    if (!ok && mounted && _authController.errorMessage != null) {
      _showMessage(_authController.errorMessage!);
    }
  }

  Widget _buildHeroVisual() {
    return Container(
      width: 154,
      // Deliberately no fixed height. It used to be 210, which fitted until the
      // labels became Urdu -- Nastaliq sits taller than Latin at the same font
      // size, and the last chip was being clipped. Sizing to the content also
      // means a phone set to larger text does not bring the clipping back.
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
        mainAxisSize: MainAxisSize.min,
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
          // A Spacer needs a bounded height, which the card no longer has.
          const SizedBox(height: AppTheme.space5),
          _buildVisualChip(Icons.grid_view_rounded, 'پروجیکٹ'),
          const SizedBox(height: AppTheme.space3),
          _buildVisualChip(Icons.picture_as_pdf_rounded, 'رپورٹیں'),
          const SizedBox(height: AppTheme.space3),
          _buildVisualChip(Icons.verified_user_rounded, 'محفوظ رسائی'),
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
      title: 'آپ کے اکاؤنٹ میں کیا محفوظ رہتا ہے',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'آپ کے سارے پروجیکٹ، رپورٹیں اور فیبریکیشن کا کام ایک ہی محفوظ جگہ پر رہتا ہے — کچھ گم نہیں ہوتا۔',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppTheme.space5),
          Wrap(
            spacing: AppTheme.space3,
            runSpacing: AppTheme.space3,
            children: const <Widget>[
              _AccessPill(
                icon: Icons.folder_copy_rounded,
                label: 'پرانے پروجیکٹ محفوظ',
              ),
              _AccessPill(
                icon: Icons.precision_manufacturing_rounded,
                label: 'فیبریکیشن کا تسلسل',
              ),
              _AccessPill(
                icon: Icons.request_quote_rounded,
                label: 'بل بنانے کا نظام',
              ),
              _AccessPill(
                icon: Icons.lock_person_rounded,
                label: 'محفوظ رسائی',
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
            title: 'ایسٹیمیشن',
            subtitle:
                'ونڈو کا ناپ ڈالیں اور سیدھا لینتھ آپٹیمائزیشن تک پہنچیں۔',
            tone: Color(0xFFE7F0F8),
            accent: AppTheme.royalBlue,
            bulletA: 'ونڈو کی ترتیب سے انٹری',
            bulletB: 'سیکشن کے مطابق جائزہ',
            bulletC: 'پروجیکٹ محفوظ رہتا ہے',
          ),
          SizedBox(width: AppTheme.space4),
          _StoryCard(
            icon: Icons.precision_manufacturing_rounded,
            title: 'فیبریکیشن',
            subtitle: 'کٹنگ اور شیشے کی رپورٹ، کاریگر کے پڑھنے کے قابل۔',
            tone: Color(0xFFE3F3F2),
            accent: AppTheme.tealAccent,
            bulletA: 'شیشہ اور کٹنگ رپورٹ',
            bulletB: 'ورکشاپ کے قابلِ استعمال',
            bulletC: 'کاریگر کو صاف ہدایت',
          ),
          SizedBox(width: AppTheme.space4),
          _StoryCard(
            icon: Icons.receipt_long_rounded,
            title: 'بل اور حساب',
            subtitle: 'مال کا میزان، ریٹ اور تیار بل — سب ایک جگہ۔',
            tone: Color(0xFFFBF1E3),
            accent: AppTheme.amberAccent,
            bulletA: 'مال کی سمری',
            bulletB: 'بل کے لیے تیار میزان',
            bulletC: 'PDF بنا کر بھیجیں',
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
                  'کوئیک اے ایل کیوں؟',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space5),
          Text(
            'اندازہ، فیبریکیشن اور بل — تینوں ایک ہی جگہ جڑے ہوئے۔ حساب دوبارہ لکھنے میں وقت ضائع نہیں ہوتا، کام جلدی اور درست ہوتا ہے۔',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppTheme.space5),
          const Row(
            children: <Widget>[
              Expanded(
                child: _MiniStatCard(
                  icon: Icons.layers_rounded,
                  value: 'ایک ہی نظام',
                  label: 'ناپ سے PDF تک، بغیر کچھ دوبارہ لکھے',
                ),
              ),
              SizedBox(width: AppTheme.space4),
              Expanded(
                child: _MiniStatCard(
                  icon: Icons.bolt_rounded,
                  value: 'کم محنت',
                  label: 'ہاتھ سے کم کام، غلطی کم',
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
        // The first screen a new user ever sees, and most of them are
        // Pakistani workshop owners -- so it speaks Urdu, right to left, in
        // Nastaliq for the headings.
        return UrduDirection(
          child: Theme(
            data: UrduText.theme(context),
            child: Scaffold(
              extendBodyBehindAppBar: true,
              appBar: AppBar(title: const Text('کوئیک اے ایل')),
              body: AppScreenShell(
                child: ListView(
                  children: <Widget>[
                    AppHeroHeader(
                      eyebrow: 'محفوظ رسائی',
                      title: 'کوئیک اے ایل میں داخل ہوں',
                      subtitle:
                          'ایلومینیم ونڈوز کا اندازہ، کٹنگ رپورٹ، شیشے کا حساب اور بل — سب ایک ہی اکاؤنٹ میں محفوظ رہتا ہے۔',
                      trailing: _buildHeroVisual(),
                    ),
                    const SizedBox(height: AppTheme.space6),
                    SectionSurfaceCard(
                      title: 'اپنے اکاؤنٹ میں داخل ہوں',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'اپنے گوگل اکاؤنٹ سے داخل ہوں۔ اس کے بعد آپ کے سارے '
                            'پروجیکٹ، رپورٹیں اور بل محفوظ رہیں گے — فون بدلنے پر '
                            'بھی۔',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: AppTheme.space6),
                          if (ApiConfig.isGoogleSignInEnabled)
                            _GoogleSignInButton(
                              busy: _authController.isBusy,
                              onPressed: _authController.isBusy
                                  ? null
                                  : _signInWithGoogle,
                            )
                          else
                            Text(
                              'اس وقت سائن اِن دستیاب نہیں۔ براہِ کرم ویب سائٹ سے '
                              'ایپ اپ ڈیٹ کر کے دوبارہ کوشش کریں۔',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppTheme.danger),
                            ),
                          const SizedBox(height: AppTheme.space3),
                          Text(
                            'پہلی بار آ رہے ہیں؟ گوگل سے داخل ہوتے ہی آپ کا اکاؤنٹ '
                            'خود بن جائے گا — پھر آپ اپنی ورکشاپ کی تفصیل درج '
                            'کریں گے۔',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.textSecondary),
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
            ),
          ),
        );
      },
    );
  }
}

/// Signing in is the only thing to do on this screen, so the button carries a
/// blue neon glow to pull the eye straight to it. The face of the button stays
/// white with Google's own mark -- their branding rules require that -- so the
/// glow sits outside it.
class _GoogleSignInButton extends StatefulWidget {
  final bool busy;
  final VoidCallback? onPressed;

  const _GoogleSignInButton({required this.busy, required this.onPressed});

  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Someone who has asked the system to cut animations gets a steady glow
    // instead of a pulsing one.
    final bool animate = !MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _glow,
      builder: (BuildContext context, Widget? child) {
        final double t = animate ? _glow.value : 0.5;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(
                  0xFF4DA3FF,
                ).withValues(alpha: 0.45 + 0.30 * t),
                blurRadius: 14 + 12 * t,
                spreadRadius: 0.5 + 1.5 * t,
              ),
              BoxShadow(
                color: const Color(
                  0xFF2E8BFF,
                ).withValues(alpha: 0.28 + 0.22 * t),
                blurRadius: 34 + 22 * t,
                spreadRadius: 1 + 3 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: _buildButton(context),
    );
  }

  Widget _buildButton(BuildContext context) {
    final bool busy = widget.busy;
    final VoidCallback? onPressed = widget.onPressed;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF3C4043),
          side: const BorderSide(color: Color(0xFF9CC9FF), width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (busy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            else
              const _GoogleGlyph(),
            const SizedBox(width: 12),
            const Text(
              'گوگل کے ساتھ جاری رکھیں',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

/// A lightweight stand-in for the official multi-colour Google "G". Drop the
/// official logo asset in here later to fully match Google's branding.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 18,
          height: 1.0,
          color: Color(0xFF4285F4),
        ),
      ),
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
