import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:my_app/core/config/api_config.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/features/auth/state/auth_controller.dart';
import 'package:my_app/features/settings/data/billing_settings_api_client.dart';
import 'package:my_app/features/settings/models/billing_settings.dart';
import 'package:my_app/features/settings/presentation/legal_document_screen.dart';
import 'package:my_app/shared/widgets/app_hero_header.dart';
import 'package:my_app/shared/widgets/app_screen_shell.dart';
import 'package:my_app/shared/widgets/section_surface_card.dart';

/// Shown right after a first-time sign-in (typically "Continue with Google")
/// when the account has no workshop details yet. Collects the workshop identity
/// that brands invoices and reports, then hands control back to the auth gate,
/// which routes on to Home. Everything here stays editable later in Settings.
///
/// There is no way past this screen without filling it in and accepting the
/// terms -- the workshop name brands every invoice, and the acceptance is the
/// record that the user agreed before using the app.
class WorkshopOnboardingScreen extends StatefulWidget {
  const WorkshopOnboardingScreen({super.key});

  @override
  State<WorkshopOnboardingScreen> createState() =>
      _WorkshopOnboardingScreenState();
}

class _WorkshopOnboardingScreenState extends State<WorkshopOnboardingScreen> {
  final AuthController _authController = AuthController.instance;
  final BillingSettingsApiClient _apiClient = BillingSettingsApiClient();

  late final TextEditingController _contractorNameController =
      TextEditingController(text: _authController.currentUser?.fullName ?? '');
  final TextEditingController _workshopNameController = TextEditingController();
  final TextEditingController _workshopPhoneController =
      TextEditingController();
  final TextEditingController _workshopAddressController =
      TextEditingController();

  bool _saving = false;
  bool _acceptedTerms = false;

  late final TapGestureRecognizer _termsRecognizer = TapGestureRecognizer()
    ..onTap = () => _openLegalDocument('Terms and Conditions', '/terms');
  late final TapGestureRecognizer _privacyRecognizer = TapGestureRecognizer()
    ..onTap = () => _openLegalDocument('Privacy Policy', '/privacy-policy');

  @override
  void dispose() {
    _contractorNameController.dispose();
    _workshopNameController.dispose();
    _workshopPhoneController.dispose();
    _workshopAddressController.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  void _openLegalDocument(String title, String path) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            LegalDocumentScreen(title: title, url: ApiConfig.resolveUrl(path)),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final String workshopName = _workshopNameController.text.trim();
    if (workshopName.length < 2) {
      _showMessage(
        'Workshop / company name must be at least 2 characters long.',
      );
      return;
    }
    if (!_acceptedTerms) {
      _showMessage(
        'Please accept the Terms & Conditions and Privacy Policy to continue.',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _apiClient.saveBillingSettings(
        BillingSettingsModel(
          contractorName: _contractorNameController.text.trim(),
          workshopName: workshopName,
          workshopPhone: _workshopPhoneController.text.trim(),
          workshopAddress: _workshopAddressController.text.trim(),
        ),
      );
      // Flag cleared -> the auth gate rebuilds and shows Home. This widget is
      // then disposed, so no further setState is needed on the success path.
      await _authController.markWorkshopSetupComplete();
    } on BillingSettingsApiException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Could not save your workshop details. Please try again.');
    }
  }

  /// The tick plus the sentence, where "Terms & Conditions" and "Privacy
  /// Policy" open the real documents. Tapping anywhere else on the sentence
  /// toggles the tick, so the whole row is a comfortable target.
  Widget _buildTermsCheckbox(BuildContext context) {
    final TextStyle? bodyStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: AppTheme.slate, height: 1.4);
    final TextStyle? linkStyle = bodyStyle?.copyWith(
      color: AppTheme.tealAccent,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: AppTheme.tealAccent,
    );

    void toggle() {
      if (_saving) return;
      setState(() => _acceptedTerms = !_acceptedTerms);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 28,
          height: 28,
          child: Checkbox(
            key: const Key('accept_terms_checkbox'),
            value: _acceptedTerms,
            onChanged: _saving ? null : (bool? value) => toggle(),
          ),
        ),
        const SizedBox(width: AppTheme.space3),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: GestureDetector(
              onTap: toggle,
              behavior: HitTestBehavior.opaque,
              child: Text.rich(
                TextSpan(
                  style: bodyStyle,
                  children: <InlineSpan>[
                    const TextSpan(text: 'I agree to the '),
                    TextSpan(
                      text: 'Terms & Conditions',
                      style: linkStyle,
                      recognizer: _termsRecognizer,
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: linkStyle,
                      recognizer: _privacyRecognizer,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Set up your workshop'),
      ),
      body: AppScreenShell(
        child: ListView(
          children: <Widget>[
            AppHeroHeader(
              eyebrow: 'ALMOST THERE',
              title: 'Add your workshop details',
              subtitle:
                  'These print on your invoices and reports. You can change '
                  'them any time in Settings.',
              trailing: Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: AppTheme.tealAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AppTheme.tealAccent,
                  size: 42,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.space6),
            SectionSurfaceCard(
              title: 'Your workshop',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextField(
                    controller: _workshopNameController,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Workshop / Company name',
                      hintText: 'Hashir Aluminium & Glass Store',
                    ),
                  ),
                  const SizedBox(height: AppTheme.space5),
                  TextField(
                    controller: _contractorNameController,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Contractor / Owner name (optional)',
                      hintText: 'Muhammad Hashir',
                    ),
                  ),
                  const SizedBox(height: AppTheme.space5),
                  TextField(
                    controller: _workshopPhoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Workshop phone (optional)',
                      hintText: '0300 1234567',
                    ),
                  ),
                  const SizedBox(height: AppTheme.space5),
                  TextField(
                    controller: _workshopAddressController,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.words,
                    maxLines: 2,
                    minLines: 1,
                    onSubmitted: (_) => _save(),
                    decoration: const InputDecoration(
                      labelText: 'Workshop address (optional)',
                      hintText: 'Jalalpur Jattan Road, Gujrat',
                    ),
                  ),
                  const SizedBox(height: AppTheme.space5),
                  _buildTermsCheckbox(context),
                  const SizedBox(height: AppTheme.space6),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (_saving || !_acceptedTerms) ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            )
                          : const Icon(Icons.check_circle_rounded),
                      label: const Text('Save & continue'),
                    ),
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
