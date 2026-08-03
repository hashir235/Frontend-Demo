import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/api_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/state/auth_controller.dart';
import '../../subscription/data/subscription_api_client.dart';
import '../../subscription/models/subscription_models.dart';
import '../../subscription/presentation/subscription_gate_screen.dart';
import '../data/billing_settings_repository.dart';
import '../data/estimation_settings_repository.dart';
import '../data/fabrication_settings_repository.dart';
import '../data/payment_preferences_api_client.dart';
import '../models/billing_settings.dart';
import '../models/estimation_settings.dart';
import '../models/fabrication_settings.dart';
import '../../../shared/widgets/social_links_card.dart';
import '../../estimation/presentation/section_recalculation_screen.dart'
    show kMinStockLengthFt, kMaxStockLengthFt;
import '../../tutorial/tutorial_controller.dart';
import '../../tutorial/urdu_text.dart';
import '../state/app_settings.dart';
import '../state/numbering_mode.dart';
import '../state/size_input_mode.dart';
import 'legal_document_screen.dart';
import 'rates_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GlobalKey<FormState> _billingFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _estimationFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _fabricationFormKey = GlobalKey<FormState>();

  final TextEditingController _contractorController = TextEditingController();
  final TextEditingController _workshopController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  final TextEditingController _maxExtraPiecesController =
      TextEditingController();
  final TextEditingController _redZone1Controller = TextEditingController();
  final TextEditingController _redZone2Controller = TextEditingController();
  final Map<String, TextEditingController> _sectionLengthControllers =
      <String, TextEditingController>{};
  final Map<String, TextEditingController> _cuttingMarginControllers =
      <String, TextEditingController>{};
  final TextEditingController _fabricationCuttingMarginController =
      TextEditingController();

  late NumberingMode _mode;
  late SizeInputMode _sizeInputMode;

  /// null = categories ka menu khula ha; warna wo section jo khula ha.
  String? _openSectionId;
  late final BillingSettingsRepository _billingSettingsRepository;
  late final EstimationSettingsRepository _estimationSettingsRepository;
  late final FabricationSettingsRepository _fabricationSettingsRepository;
  late final PaymentPreferencesApiClient _paymentPreferencesApiClient;

  RenewalMode _renewalMode = RenewalMode.manual;
  bool _isLoadingPaymentPreferences = true;
  bool _isSavingPaymentPreferences = false;
  String? _paymentPreferencesError;

  final SubscriptionApiClient _subscriptionApiClient = SubscriptionApiClient();
  SubscriptionStatus? _subscriptionStatus;
  bool _isLoadingSubscriptionStatus = true;
  String? _subscriptionStatusError;

  bool _isLoadingBillingSettings = true;
  bool _isSavingBillingSettings = false;
  String? _billingSettingsError;

  bool _isLoadingEstimationSettings = true;
  bool _isSavingEstimationSettings = false;
  String? _estimationSettingsError;
  bool _enforceMaxExtraPieces = false;

  bool _isLoadingFabricationSettings = true;
  bool _isSavingFabricationSettings = false;
  String? _fabricationSettingsError;

  @override
  void initState() {
    super.initState();
    _mode = AppSettings.instance.numberingMode;
    _sizeInputMode = AppSettings.instance.sizeInputMode;
    _billingSettingsRepository = BillingSettingsRepository();
    _estimationSettingsRepository = EstimationSettingsRepository();
    _fabricationSettingsRepository = FabricationSettingsRepository();
    _paymentPreferencesApiClient = PaymentPreferencesApiClient();
    AppSettings.instance.addListener(_onSettingsChanged);
    _loadBillingSettings();
    _loadEstimationSettings();
    _loadFabricationSettings();
    _loadPaymentPreferences();
    _loadSubscriptionStatus();
  }

  Future<void> _loadSubscriptionStatus() async {
    setState(() {
      _isLoadingSubscriptionStatus = true;
      _subscriptionStatusError = null;
    });
    try {
      final SubscriptionStatus status = await _subscriptionApiClient
          .fetchStatus();
      if (!mounted) return;
      setState(() {
        _subscriptionStatus = status;
        _isLoadingSubscriptionStatus = false;
      });
    } on SubscriptionApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingSubscriptionStatus = false;
        _subscriptionStatusError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingSubscriptionStatus = false;
        _subscriptionStatusError = 'Subscription status failed to load.';
      });
    }
  }

  Future<void> _openBillingAndPlans() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const SubscriptionGateScreen.manage(),
      ),
    );
    if (mounted) {
      _loadSubscriptionStatus();
    }
  }

  String _subscriptionSummaryLine() {
    if (_isLoadingSubscriptionStatus) {
      return 'Checking your plan...';
    }
    if (_subscriptionStatusError != null) {
      return 'Plan status is unavailable right now.';
    }
    final SubscriptionStatus? status = _subscriptionStatus;
    if (status == null) {
      return 'Plan status is unavailable right now.';
    }
    if (status.entitlement == 'subscription' && status.subscription != null) {
      final String planName = status.plan != null
          ? '${status.plan!.title} (${status.plan!.durationLabel})'
          : 'Paid plan';
      final String expires = formatQuickAlDate(status.subscription!.expiresAt);
      return status.subscription!.autoRenewing
          ? '$planName — renews on $expires.'
          : '$planName — active until $expires.';
    }
    if (status.trialActive) {
      final int days = status.trial?.daysRemaining ?? 0;
      final String ends = formatQuickAlDate(status.trial?.expiresAt);
      return days > 0
          ? 'Free Trial — $days ${days == 1 ? 'day' : 'days'} left (ends $ends).'
          : 'Free Trial — ends today ($ends).';
    }
    return 'No active plan. Buy a plan to keep full access.';
  }

  @override
  void dispose() {
    AppSettings.instance.removeListener(_onSettingsChanged);
    _contractorController.dispose();
    _workshopController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _maxExtraPiecesController.dispose();
    _redZone1Controller.dispose();
    _redZone2Controller.dispose();
    _fabricationCuttingMarginController.dispose();
    for (final TextEditingController controller
        in _sectionLengthControllers.values) {
      controller.dispose();
    }
    for (final TextEditingController controller
        in _cuttingMarginControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onSettingsChanged() {
    setState(() {
      _mode = AppSettings.instance.numberingMode;
      _sizeInputMode = AppSettings.instance.sizeInputMode;
    });
  }

  void _updateMode(NumberingMode mode) {
    AppSettings.instance.setNumberingMode(mode);
  }

  void _updateSizeInputMode(SizeInputMode mode) {
    AppSettings.instance.setSizeInputMode(mode);
  }

  Future<void> _loadBillingSettings() async {
    setState(() {
      _isLoadingBillingSettings = true;
      _billingSettingsError = null;
    });

    try {
      final BillingSettingsModel settings = await _billingSettingsRepository
          .fetchBillingSettings();
      if (!mounted) {
        return;
      }
      _contractorController.text = settings.contractorName;
      _workshopController.text = settings.workshopName;
      _addressController.text = settings.workshopAddress;
      _phoneController.text = settings.workshopPhone;
      setState(() {
        _isLoadingBillingSettings = false;
      });
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _billingSettingsError = error.toString();
        _isLoadingBillingSettings = false;
      });
    }
  }

  Future<void> _loadFabricationSettings() async {
    setState(() {
      _isLoadingFabricationSettings = true;
      _fabricationSettingsError = null;
    });

    try {
      final FabricationSettingsModel settings =
          await _fabricationSettingsRepository.fetchFabricationSettings();
      if (!mounted) {
        return;
      }
      _fabricationCuttingMarginController.text = _formatNumber(
        settings.cuttingMarginCm,
      );
      setState(() {
        _isLoadingFabricationSettings = false;
      });
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _fabricationSettingsError = error.toString();
        _isLoadingFabricationSettings = false;
      });
    }
  }

  Future<void> _loadEstimationSettings() async {
    setState(() {
      _isLoadingEstimationSettings = true;
      _estimationSettingsError = null;
    });

    try {
      final EstimationSettingsModel settings =
          await _estimationSettingsRepository.fetchEstimationSettings();
      if (!mounted) {
        return;
      }

      _maxExtraPiecesController.text = settings.maxExtraPieces.toString();
      _redZone1Controller.text = _formatNumber(settings.redZoneEven);
      _redZone2Controller.text = _formatNumber(settings.redZoneOdd);
      _enforceMaxExtraPieces = settings.enforceMaxExtraPieces;

      final Set<String> activeKeys = settings.sectionLengths.keys.toSet();
      final List<String> staleKeys = _sectionLengthControllers.keys
          .where((String key) => !activeKeys.contains(key))
          .toList(growable: false);
      for (final String key in staleKeys) {
        _sectionLengthControllers.remove(key)?.dispose();
      }
      final Set<String> activeMarginKeys = settings.cuttingMargins.keys.toSet();
      final List<String> staleMarginKeys = _cuttingMarginControllers.keys
          .where((String key) => !activeMarginKeys.contains(key))
          .toList(growable: false);
      for (final String key in staleMarginKeys) {
        _cuttingMarginControllers.remove(key)?.dispose();
      }

      for (final MapEntry<String, List<int>> entry
          in settings.sectionLengths.entries) {
        final TextEditingController controller = _sectionLengthControllers
            .putIfAbsent(entry.key, TextEditingController.new);
        controller.text = _joinLengths(entry.value);
      }
      for (final MapEntry<String, double> entry
          in settings.cuttingMargins.entries) {
        final TextEditingController controller = _cuttingMarginControllers
            .putIfAbsent(entry.key, TextEditingController.new);
        controller.text = _formatNumber(entry.value);
      }

      setState(() {
        _isLoadingEstimationSettings = false;
      });
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _estimationSettingsError = error.toString();
        _isLoadingEstimationSettings = false;
      });
    }
  }

  Future<void> _loadPaymentPreferences() async {
    setState(() {
      _isLoadingPaymentPreferences = true;
      _paymentPreferencesError = null;
    });

    try {
      final RenewalMode mode =
          await _paymentPreferencesApiClient.fetchRenewalMode();
      if (!mounted) {
        return;
      }
      setState(() {
        _renewalMode = mode;
        _isLoadingPaymentPreferences = false;
      });
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _paymentPreferencesError = error.toString();
        _isLoadingPaymentPreferences = false;
      });
    }
  }

  Future<void> _updateRenewalMode(RenewalMode mode) async {
    final RenewalMode previous = _renewalMode;
    setState(() {
      _renewalMode = mode;
      _isSavingPaymentPreferences = true;
    });

    try {
      final RenewalMode saved =
          await _paymentPreferencesApiClient.saveRenewalMode(mode);
      if (!mounted) {
        return;
      }
      setState(() {
        _renewalMode = saved;
        _isSavingPaymentPreferences = false;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved == RenewalMode.auto
                ? 'Auto renewal selected.'
                : 'Manual renewal selected.',
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _renewalMode = previous;
        _isSavingPaymentPreferences = false;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  String? _phoneValidator(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return null;
    }
    if (text.length < 7) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  String? _requiredDecimalValidator(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Required';
    }
    final double? number = double.tryParse(text);
    if (number == null || number < 0) {
      return 'Enter a valid number';
    }
    return null;
  }

  String? _requiredDecimalWithZeroValidator(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Required';
    }
    final double? number = double.tryParse(text);
    if (number == null || number < 0) {
      return 'Enter a valid number';
    }
    return null;
  }

  String? _requiredIntValidator(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Required';
    }
    final int? number = int.tryParse(text);
    if (number == null || number < 0) {
      return 'Enter a valid whole number';
    }
    return null;
  }

  /// Starting the tour pops the user back to Home, because that is where it
  /// begins and where its first step points.
  Widget _buildTutorialCard(BuildContext context) {
    return _buildSettingsCard(
      context,
      icon: Icons.play_circle_outline_rounded,
      title: 'App kaise istemal karein',
      subtitle:
          'Poora Estimation ka safar — window ke naap se le kar tayyar bill '
          'tak — asli screens par, Urdu mein.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FilledButton.icon(
            onPressed: () {
              TutorialController.instance.start();
              Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              'رہنمائی شروع کریں',
              style: UrduText.body(color: Colors.white, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  /// Rates get their own full screen -- the table is far too wide to sit
  /// inside a settings card -- so this card is the door to it.
  Widget _buildRatesCard(BuildContext context) {
    return _buildSettingsCard(
      context,
      icon: Icons.price_change_rounded,
      title: 'Rates',
      subtitle:
          'The rate for every section, by gauge and colour. Change any of '
          'them to price with your own.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext _) => const RatesScreen(),
                ),
              );
            },
            icon: const Icon(Icons.table_chart_rounded),
            label: const Text('Open rate list'),
          ),
        ],
      ),
    );
  }

  /// Puts every section back to the mill's standard bars.
  ///
  /// Sections whose name ends in F come in 15/17/19 ft; everything else comes
  /// in 14/16/18. Without this, a user who mistyped a length had no way back
  /// except remembering what had been there before.
  void _restoreStandardSectionLengths() {
    setState(() {
      for (final String key in _sectionLengthControllers.keys) {
        final bool isF = key.toUpperCase().endsWith('F');
        _sectionLengthControllers[key]!.text = isF
            ? '15, 17, 19'
            : '14, 16, 18';
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Standard lengths filled in. Save to apply them.'),
      ),
    );
  }

  String? _sectionLengthsValidator(String? value) {
    final List<int>? lengths = _parseLengthList(value);
    if (lengths == null) {
      return 'Use comma-separated whole numbers';
    }
    if (lengths.isEmpty) {
      return 'Enter at least one length';
    }
    // These are the bars the dealer stocks, in feet. A user once saved 238
    // here -- reading the field as inches -- and every section then failed to
    // optimize, with an error that pointed nowhere near this screen.
    final Iterable<int> outOfRange = lengths.where(
      (int ft) => ft < kMinStockLengthFt || ft > kMaxStockLengthFt,
    );
    if (outOfRange.isNotEmpty) {
      return 'Lengths are in feet ($kMinStockLengthFt-$kMaxStockLengthFt). '
          'Check ${outOfRange.first} — did you mean inches?';
    }
    return null;
  }

  List<int>? _parseLengthList(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return null;
    }

    final List<int> lengths = <int>[];
    final List<String> parts = text.split(',');
    for (final String rawPart in parts) {
      final String part = rawPart.trim();
      if (part.isEmpty) {
        return null;
      }
      final int? parsed = int.tryParse(part);
      if (parsed == null || parsed <= 0) {
        return null;
      }
      lengths.add(parsed);
    }
    return lengths;
  }

  Future<void> _saveBillingSettings() async {
    final FormState? form = _billingFormKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isSavingBillingSettings = true;
      _billingSettingsError = null;
    });

    try {
      final BillingSettingsModel saved = await _billingSettingsRepository
          .saveBillingSettings(
            BillingSettingsModel(
              contractorName: _contractorController.text.trim(),
              workshopName: _workshopController.text.trim(),
              workshopPhone: _phoneController.text.trim(),
              workshopAddress: _addressController.text.trim(),
            ),
          );

      if (!mounted) {
        return;
      }

      _contractorController.text = saved.contractorName;
      _workshopController.text = saved.workshopName;
      _addressController.text = saved.workshopAddress;
      _phoneController.text = saved.workshopPhone;

      setState(() {
        _isSavingBillingSettings = false;
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('General settings saved.')));
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _billingSettingsError = error.toString();
        _isSavingBillingSettings = false;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _saveEstimationSettings() async {
    final FormState? form = _estimationFormKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final Map<String, List<int>> sectionLengths = <String, List<int>>{};
    final Map<String, double> cuttingMargins = <String, double>{};
    for (final String key in _sortedSectionKeys()) {
      final List<int>? parsed = _parseLengthList(
        _sectionLengthControllers[key]?.text,
      );
      if (parsed == null) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Invalid lengths for $key.')));
        return;
      }
      sectionLengths[key] = parsed;
    }
    for (final String key in _sortedCuttingMarginKeys()) {
      final String text = (_cuttingMarginControllers[key]?.text ?? '').trim();
      final double? parsed = double.tryParse(text);
      if (parsed == null || parsed < 0) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid cutting margin for $key.')),
        );
        return;
      }
      cuttingMargins[key] = parsed;
    }

    setState(() {
      _isSavingEstimationSettings = true;
      _estimationSettingsError = null;
    });

    try {
      final EstimationSettingsModel saved = await _estimationSettingsRepository
          .saveEstimationSettings(
            EstimationSettingsModel(
              sectionLengths: sectionLengths,
              cuttingMargins: cuttingMargins,
              maxExtraPieces: int.parse(_maxExtraPiecesController.text.trim()),
              enforceMaxExtraPieces: _enforceMaxExtraPieces,
              redZoneEven: double.parse(_redZone1Controller.text.trim()),
              redZoneOdd: double.parse(_redZone2Controller.text.trim()),
            ),
          );

      if (!mounted) {
        return;
      }

      _maxExtraPiecesController.text = saved.maxExtraPieces.toString();
      _redZone1Controller.text = _formatNumber(saved.redZoneEven);
      _redZone2Controller.text = _formatNumber(saved.redZoneOdd);
      _enforceMaxExtraPieces = saved.enforceMaxExtraPieces;

      for (final MapEntry<String, List<int>> entry
          in saved.sectionLengths.entries) {
        final TextEditingController controller = _sectionLengthControllers
            .putIfAbsent(entry.key, TextEditingController.new);
        controller.text = _joinLengths(entry.value);
      }
      for (final MapEntry<String, double> entry
          in saved.cuttingMargins.entries) {
        final TextEditingController controller = _cuttingMarginControllers
            .putIfAbsent(entry.key, TextEditingController.new);
        controller.text = _formatNumber(entry.value);
      }

      setState(() {
        _isSavingEstimationSettings = false;
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estimation settings saved.')),
      );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _estimationSettingsError = error.toString();
        _isSavingEstimationSettings = false;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _saveFabricationSettings() async {
    final FormState? form = _fabricationFormKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isSavingFabricationSettings = true;
      _fabricationSettingsError = null;
    });

    try {
      final FabricationSettingsModel saved =
          await _fabricationSettingsRepository.saveFabricationSettings(
            FabricationSettingsModel(
              cuttingMarginCm: double.parse(
                _fabricationCuttingMarginController.text.trim(),
              ),
            ),
          );

      if (!mounted) {
        return;
      }

      _fabricationCuttingMarginController.text = _formatNumber(
        saved.cuttingMarginCm,
      );

      setState(() {
        _isSavingFabricationSettings = false;
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fabrication settings saved.')),
      );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _fabricationSettingsError = error.toString();
        _isSavingFabricationSettings = false;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  List<String> _sortedSectionKeys() {
    final List<String> keys = _sectionLengthControllers.keys.toList();
    keys.sort();
    return keys;
  }

  List<String> _sortedCuttingMarginKeys() {
    final List<String> keys = _cuttingMarginControllers.keys.toList();
    keys.sort();
    return keys;
  }

  String _joinLengths(List<int> lengths) => lengths.join(', ');

  String _formatNumber(double value) {
    String text = value.toStringAsFixed(2);
    text = text.replaceFirst(RegExp(r'\.00$'), '');
    text = text.replaceFirst(RegExp(r'(\.\d)0$'), r'$1');
    return text;
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
      isDense: true,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.9),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: AppTheme.deepTeal,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildSectionSubtitle(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: AppTheme.deepTeal.withValues(alpha: 0.7),
        height: 1.35,
      ),
    );
  }

  Widget _buildEstimationSubheading(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppTheme.deepTeal,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildPageHero(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: 0.96),
            AppTheme.ice.withValues(alpha: 0.92),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppTheme.violet.withValues(alpha: 0.12),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
        border: Border.all(color: AppTheme.violet.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.violet.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'System Controls',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppTheme.violet,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.deepTeal,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          _buildSectionSubtitle(
            context,
            'Manage numbering, company information, estimation rules, and fabrication margins from one place.',
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.violet.withValues(alpha: 0.10)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppTheme.violet.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.violet.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppTheme.violet),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _buildSectionTitle(context, title),
                    const SizedBox(height: 6),
                    _buildSectionSubtitle(context, subtitle),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildSettingsCluster(
    BuildContext context, {
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.ice.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.violet.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildEstimationSubheading(context, title),
          if (subtitle != null) ...<Widget>[
            _buildSectionSubtitle(context, subtitle),
            const SizedBox(height: 12),
          ],
          ...children,
        ],
      ),
    );
  }

  Widget _buildErrorBanner(
    BuildContext context,
    String message,
    VoidCallback onRetry,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.red.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry Load'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  /// Numbering and size entry both decide how the window input page behaves,
  /// so they live together on one page instead of two near-identical ones.
  Widget _buildWindowInputCard(BuildContext context) {
    return _buildSettingsCard(
      context,
      icon: Icons.tune_rounded,
      title: 'Window Input',
      subtitle: 'How window numbers and sizes are entered.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildSubSectionLabel(context, 'Window Numbering'),
          const SizedBox(height: 8),
          _buildNumberingOptions(context),
          const SizedBox(height: 20),
          _buildSubSectionLabel(context, 'Size Input Method'),
          const SizedBox(height: 8),
          _buildSizeInputOptions(context),
        ],
      ),
    );
  }

  Widget _buildSubSectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: AppTheme.deepTeal,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildNumberingOptions(BuildContext context) {
    return Container(
        decoration: BoxDecoration(
          color: AppTheme.ice.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.violet.withValues(alpha: 0.10)),
        ),
        child: RadioGroup<NumberingMode>(
          groupValue: _mode,
          onChanged: (NumberingMode? value) {
            if (value != null) {
              _updateMode(value);
            }
          },
          child: Column(
            children: const <Widget>[
              RadioListTile<NumberingMode>(
                value: NumberingMode.auto,
                title: Text('Auto (default)'),
                subtitle: Text(
                  'Automatically increments window numbers for each new entry.',
                ),
              ),
              Divider(height: 1),
              RadioListTile<NumberingMode>(
                value: NumberingMode.manual,
                title: Text('Manual'),
                subtitle: Text(
                  'User must enter a window number before height/width.',
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildSizeInputOptions(BuildContext context) {
    return Container(
        decoration: BoxDecoration(
          color: AppTheme.ice.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.violet.withValues(alpha: 0.10)),
        ),
        child: RadioGroup<SizeInputMode>(
          groupValue: _sizeInputMode,
          onChanged: (SizeInputMode? value) {
            if (value != null) {
              _updateSizeInputMode(value);
            }
          },
          child: Column(
            children: const <Widget>[
              RadioListTile<SizeInputMode>(
                value: SizeInputMode.wheel,
                title: Text('Wheel (default)'),
                subtitle: Text(
                  'Inch and suter are picked on a tape-style wheel.',
                ),
              ),
              Divider(height: 1),
              RadioListTile<SizeInputMode>(
                value: SizeInputMode.keypad,
                title: Text('Typing box'),
                subtitle: Text(
                  'Every part of the size is typed into an input box.',
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildCompanyInformationCard(BuildContext context) {
    return _buildSettingsCard(
      context,
      icon: Icons.apartment_rounded,
      title: 'Company Information',
      subtitle: 'These values are loaded automatically into the billing flow.',
      child: _isLoadingBillingSettings
          ? _buildLoadingCard()
          : Form(
              key: _billingFormKey,
              child: Column(
                children: <Widget>[
                  if (_billingSettingsError != null)
                    _buildErrorBanner(
                      context,
                      _billingSettingsError!,
                      _loadBillingSettings,
                    ),
                  TextFormField(
                    controller: _contractorController,
                    inputFormatters: <TextInputFormatter>[
                      LengthLimitingTextInputFormatter(80),
                    ],
                    decoration: _inputDecoration('Contractor Name'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _workshopController,
                    inputFormatters: <TextInputFormatter>[
                      LengthLimitingTextInputFormatter(80),
                    ],
                    decoration: _inputDecoration('Workshop / Company Name'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    maxLines: 2,
                    inputFormatters: <TextInputFormatter>[
                      LengthLimitingTextInputFormatter(200),
                    ],
                    decoration: _inputDecoration('Address'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(15),
                    ],
                    validator: _phoneValidator,
                    decoration: _inputDecoration('Workshop / Company Phone'),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSavingBillingSettings
                          ? null
                          : _saveBillingSettings,
                      child: Text(
                        _isSavingBillingSettings
                            ? 'Saving...'
                            : 'Save Settings',
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEstimationSettingsCard(BuildContext context) {
    return _buildSettingsCard(
      context,
      icon: Icons.tune_rounded,
      title: 'Estimation Settings',
      subtitle:
          'Manage allowed lengths, cutting margins, and optimization thresholds.',
      child: _isLoadingEstimationSettings
          ? _buildLoadingCard()
          : Form(
              key: _estimationFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (_estimationSettingsError != null)
                    _buildErrorBanner(
                      context,
                      _estimationSettingsError!,
                      _loadEstimationSettings,
                    ),
                  _buildSettingsCluster(
                    context,
                    title: 'Assigned Lengths for Section',
                    subtitle:
                        'Lengths of the bars your dealer stocks, in feet. '
                        'Use commas, for example 14, 16, 18.',
                    children: <Widget>[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _restoreStandardSectionLengths,
                          icon: const Icon(Icons.restart_alt_rounded, size: 18),
                          label: const Text('Restore standard lengths'),
                        ),
                      ),
                      const SizedBox(height: 4),
                      ..._sortedSectionKeys().map((String key) {
                        final TextEditingController controller =
                            _sectionLengthControllers[key]!;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextFormField(
                            controller: controller,
                            validator: _sectionLengthsValidator,
                            decoration: _inputDecoration(key),
                          ),
                        );
                      }),
                    ],
                  ),
                  _buildSettingsCluster(
                    context,
                    title: 'Cutting Margin of Each Section',
                    subtitle:
                        'These margins are applied per section during estimation calculations.',
                    children: _sortedCuttingMarginKeys()
                        .map((String key) {
                          final TextEditingController controller =
                              _cuttingMarginControllers[key]!;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextFormField(
                              controller: controller,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: _requiredDecimalWithZeroValidator,
                              decoration: _inputDecoration(key),
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
                  _buildSettingsCluster(
                    context,
                    title: 'Red Zone Thresholds',
                    subtitle:
                        'These thresholds control when the optimizer may keep a custom extra piece before rounding up to the smallest stock length.',
                    children: <Widget>[
                      TextFormField(
                        controller: _redZone1Controller,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: _requiredDecimalValidator,
                        decoration: _inputDecoration(
                          'RedZoneEven',
                          hint: 'Even groups: 14, 16, 18',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _redZone2Controller,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: _requiredDecimalValidator,
                        decoration: _inputDecoration(
                          'RedZoneOdd',
                          hint: 'Odd groups: 15, 17, 19',
                        ),
                      ),
                    ],
                  ),
                  _buildSettingsCluster(
                    context,
                    title: 'Extra Pieces Allowance',
                    subtitle:
                        'Control how many extra leftover pieces may remain when strict enforcement is enabled.',
                    children: <Widget>[
                      TextFormField(
                        controller: _maxExtraPiecesController,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: _requiredIntValidator,
                        decoration: _inputDecoration('Max Extra Pieces'),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enforce Extra Pieces Limit'),
                        subtitle: const Text(
                          'Turn on to strictly block extra leftover pieces beyond the limit.',
                        ),
                        value: _enforceMaxExtraPieces,
                        onChanged: (bool value) {
                          setState(() {
                            _enforceMaxExtraPieces = value;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSavingEstimationSettings
                          ? null
                          : _saveEstimationSettings,
                      child: Text(
                        _isSavingEstimationSettings
                            ? 'Saving...'
                            : 'Save Estimation Settings',
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFabricationSettingsCard(BuildContext context) {
    return _buildSettingsCard(
      context,
      icon: Icons.construction_rounded,
      title: 'Fabrication Settings',
      subtitle:
          'Manage the fabrication cutting margin used in fabrication optimization and reports.',
      child: _isLoadingFabricationSettings
          ? _buildLoadingCard()
          : Form(
              key: _fabricationFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (_fabricationSettingsError != null)
                    _buildErrorBanner(
                      context,
                      _fabricationSettingsError!,
                      _loadFabricationSettings,
                    ),
                  _buildSettingsCluster(
                    context,
                    title: 'Fabrication Cutting Margin',
                    subtitle: 'This value is in cm. Current default is 1.2.',
                    children: <Widget>[
                      TextFormField(
                        controller: _fabricationCuttingMarginController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: <TextInputFormatter>[
                          LengthLimitingTextInputFormatter(8),
                        ],
                        validator: _requiredDecimalWithZeroValidator,
                        decoration: _inputDecoration(
                          'Fabrication Cutting Margin',
                          hint: '1.2',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSavingFabricationSettings
                          ? null
                          : _saveFabricationSettings,
                      child: Text(
                        _isSavingFabricationSettings
                            ? 'Saving...'
                            : 'Save Fabrication Settings',
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPaymentRenewalCard(BuildContext context) {
    return _buildSettingsCard(
      context,
      icon: Icons.payments_rounded,
      title: 'Payment & Renewal',
      subtitle:
          'See your current plan, buy or change plans, and choose how your '
          'subscription renews.',
      child: _isLoadingPaymentPreferences
          ? _buildLoadingCard()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (_paymentPreferencesError != null)
                  _buildErrorBanner(
                    context,
                    _paymentPreferencesError!,
                    _loadPaymentPreferences,
                  ),
                _buildSettingsCluster(
                  context,
                  title: 'Your Plan',
                  subtitle: _subscriptionSummaryLine(),
                  children: <Widget>[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _openBillingAndPlans,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.royalBlue,
                        ),
                        icon: const Icon(Icons.workspace_premium_rounded),
                        label: Text(
                          _subscriptionStatus?.entitlement == 'subscription'
                              ? 'View / Change Plan'
                              : 'View & Buy Plans',
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.ice.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: AppTheme.violet.withValues(alpha: 0.10),
                    ),
                  ),
                  child: RadioGroup<RenewalMode>(
                    groupValue: _renewalMode,
                    onChanged: (RenewalMode? value) {
                      if (value != null && !_isSavingPaymentPreferences) {
                        _updateRenewalMode(value);
                      }
                    },
                    child: Column(
                      children: const <Widget>[
                        RadioListTile<RenewalMode>(
                          value: RenewalMode.manual,
                          title: Text('Manual renewal (default)'),
                          subtitle: Text(
                            'You renew yourself. The app reminds you before your subscription expires. No automatic charges.',
                          ),
                        ),
                        Divider(height: 1),
                        RadioListTile<RenewalMode>(
                          value: RenewalMode.auto,
                          title: Text('Auto renewal'),
                          subtitle: Text(
                            'Your subscription renews automatically when online payments are available. You will be notified before each renewal.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildSettingsCluster(
                  context,
                  title: 'Refund Policy',
                  children: <Widget>[
                    const Text(
                      'All subscription payments are final and non-refundable. '
                      'If the app does not work after your payment because of '
                      'a technical problem on our side, you can request a '
                      'refund review by emailing quickal.dev@gmail.com from '
                      'your registered email within 7 days of payment. '
                      'Include your payment reference.',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Google Play purchases follow Google Play\'s own refund process.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.deepTeal.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildLegalLink(
                      context,
                      icon: Icons.receipt_long_rounded,
                      label: 'Read the full Refund Policy',
                      path: '/refund-policy',
                      title: 'Refund Policy',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const PaymentHelpCard(),
              ],
            ),
    );
  }

  Widget _buildLegalSupportCard(BuildContext context) {
    return _buildSettingsCard(
      context,
      icon: Icons.gavel_rounded,
      title: 'Legal & Support',
      subtitle:
          'Our policies and how to reach us. Everything opens inside the app.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildSettingsCluster(
            context,
            title: 'Policies',
            subtitle: 'The terms that apply to your subscription and your data.',
            children: <Widget>[
              _buildLegalLink(
                context,
                icon: Icons.description_rounded,
                label: 'Terms and Conditions',
                path: '/terms',
                title: 'Terms and Conditions',
              ),
              _buildLegalLink(
                context,
                icon: Icons.privacy_tip_rounded,
                label: 'Privacy Policy',
                path: '/privacy-policy',
                title: 'Privacy Policy',
              ),
              _buildLegalLink(
                context,
                icon: Icons.receipt_long_rounded,
                label: 'Refund & Cancellation Policy',
                path: '/refund-policy',
                title: 'Refund Policy',
              ),
              _buildLegalLink(
                context,
                icon: Icons.person_remove_rounded,
                label: 'Delete Account & Data',
                path: '/delete-account',
                title: 'Delete Account',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSettingsCluster(
            context,
            title: 'Customer support',
            subtitle: 'Quick AL by MMH Tech — we reply within 24 hours.',
            children: <Widget>[
              const _SupportRow(
                icon: Icons.chat_rounded,
                label: 'WhatsApp',
                value: '0329 7590468',
              ),
              const SizedBox(height: 10),
              const _SupportRow(
                icon: Icons.mail_rounded,
                label: 'Email',
                value: 'quickal.dev@gmail.com',
              ),
              const SizedBox(height: 10),
              const _SupportRow(
                icon: Icons.language_rounded,
                label: 'Website',
                value: 'quickalapp.com',
              ),
              const SizedBox(height: 10),
              const _SupportRow(
                icon: Icons.storefront_rounded,
                label: 'Merchant',
                value: 'MMH Tech (Sole Proprietor), Pakistan',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Policies live on quickalapp.com so wording can be fixed without an app
  // release; they open in-app so the user never loses their place.
  Widget _buildLegalLink(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String path,
    required String title,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => LegalDocumentScreen(
                title: title,
                url: ApiConfig.resolveUrl(path),
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 20, color: AppTheme.violet),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: AppTheme.slate,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context) {
    return AnimatedBuilder(
      animation: AuthController.instance,
      builder: (BuildContext context, _) {
        final AuthController authController = AuthController.instance;
        final String displayName =
            authController.currentUser?.fullName.trim().isNotEmpty == true
            ? authController.currentUser!.fullName
            : 'Signed-in user';
        final String email = authController.currentUser?.email ?? '';

        return _buildSettingsCard(
          context,
          icon: Icons.manage_accounts_rounded,
          title: 'Account',
          subtitle:
              'You stay signed in on this device until you choose to sign out.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildSettingsCluster(
                context,
                title: displayName,
                subtitle: email.isEmpty ? 'Current session is active.' : email,
                children: const <Widget>[
                  Text(
                    'Use sign out only when you want to remove this account from the device.',
                  ),
                ],
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: authController.isBusy
                      ? null
                      : () async {
                          await authController.signOut();
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.deepTeal,
                  ),
                  icon: authController.isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.logout_rounded),
                  label: Text(
                    authController.isBusy ? 'Signing Out...' : 'Sign Out',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Settings ab ek lambi list nahi. Pehle categories ka menu khulta ha, aur
  /// kisi category par tap karne se sirf usi se related settings dikhti hain.
  ///
  /// Yahan Navigator use nahi kiya kyunke saare controllers aur loaders isi
  /// State mein hain — section badalna sirf ek setState ha, is liye koi bhi
  /// adhoora load ya likha hua text zaya nahi hota.
  List<_SettingsSection> get _sections => <_SettingsSection>[
    _SettingsSection(
      id: 'window_input',
      icon: Icons.tune_rounded,
      title: 'Window Input',
      subtitle: 'Numbering aur size entry ka tareeqa.',
      builder: _buildWindowInputCard,
    ),
    _SettingsSection(
      id: 'tutorial',
      icon: Icons.play_circle_outline_rounded,
      title: 'App kaise istemal karein',
      subtitle: 'Qadam ba qadam rehnumai — Urdu mein.',
      builder: _buildTutorialCard,
    ),
    _SettingsSection(
      id: 'rates',
      icon: Icons.price_change_rounded,
      title: 'Rates',
      subtitle: 'Section ke rates dekhein aur apne mutabiq badlein.',
      builder: _buildRatesCard,
    ),
    _SettingsSection(
      id: 'company',
      icon: Icons.apartment_rounded,
      title: 'Company Information',
      subtitle: 'Workshop ka naam, phone aur address.',
      builder: _buildCompanyInformationCard,
    ),
    _SettingsSection(
      id: 'estimation',
      icon: Icons.straighten_outlined,
      title: 'Estimation Settings',
      subtitle: 'Lengths, cutting margins, red zone, extra pieces.',
      builder: _buildEstimationSettingsCard,
    ),
    _SettingsSection(
      id: 'fabrication',
      icon: Icons.handyman_outlined,
      title: 'Fabrication Settings',
      subtitle: 'Fabrication cutting margin.',
      builder: _buildFabricationSettingsCard,
    ),
    _SettingsSection(
      id: 'payment',
      icon: Icons.credit_card_rounded,
      title: 'Payment & Renewal',
      subtitle: 'Aap ka plan aur renewal.',
      builder: _buildPaymentRenewalCard,
    ),
    _SettingsSection(
      id: 'legal',
      icon: Icons.gavel_rounded,
      title: 'Legal & Support',
      subtitle: 'Policies aur customer support.',
      builder: _buildLegalSupportCard,
    ),
    _SettingsSection(
      id: 'account',
      icon: Icons.person_outline_rounded,
      title: 'Account',
      subtitle: 'Sign out.',
      builder: _buildAccountCard,
    ),
  ];

  Widget _buildSectionTile(BuildContext context, _SettingsSection section) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _openSectionId = section.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.ice.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(section.icon, color: AppTheme.violet, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      section.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.deepTeal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      section.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.slate,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.slate),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final _SettingsSection? openSection = _openSectionId == null
        ? null
        : _sections.where((s) => s.id == _openSectionId).firstOrNull;

    return PopScope(
      // Section khula ho to back button pehle menu par wapas laye, seedha
      // settings se bahar na nikale.
      canPop: openSection == null,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          setState(() => _openSectionId = null);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(openSection?.title ?? 'General Settings'),
          centerTitle: true,
          leading: openSection == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => setState(() => _openSectionId = null),
                ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[AppTheme.ice, AppTheme.mist],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: openSection == null
                ? ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                    itemCount: _sections.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (BuildContext context, int index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildPageHero(context),
                        );
                      }
                      return _buildSectionTile(context, _sections[index - 1]);
                    },
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                    children: <Widget>[openSection.builder(context)],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Settings menu ka ek option aur us se juri settings ka builder.
class _SettingsSection {
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget Function(BuildContext) builder;

  const _SettingsSection({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.builder,
  });
}

/// One contact line in the Legal & Support card. Selectable so a user (or a
/// reviewer) can copy the number or address straight out of the app.
class _SupportRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SupportRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 20, color: AppTheme.tealAccent),
        const SizedBox(width: 12),
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
