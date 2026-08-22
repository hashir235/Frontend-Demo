import '../../help_videos/help_video_button.dart';
import '../../help_videos/tutorial_videos.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/api_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../auth/data/auth_api_client.dart';
import '../../auth/state/auth_controller.dart';
import '../../subscription/data/subscription_api_client.dart';
import '../../subscription/models/subscription_models.dart';
import '../../subscription/presentation/subscription_gate_screen.dart';
import '../data/billing_settings_repository.dart';
import '../data/estimation_settings_repository.dart';
import '../data/fabrication_settings_repository.dart';
import '../data/payment_preferences_api_client.dart';
import '../data/settings_defaults_api_client.dart';
import '../data/bill_defaults_api_client.dart';
import '../data/rate_cities_api_client.dart';
import 'city_picker_field.dart';
import '../models/bill_defaults.dart';
import '../models/billing_settings.dart';
import '../models/estimation_settings.dart';
import '../models/extra_pieces_allowance.dart';
import '../models/fabrication_settings.dart';
import '../../../shared/widgets/social_links_card.dart';
import '../../estimation/presentation/section_recalculation_screen.dart'
    show kMinStockLengthFt, kMaxStockLengthFt;
import '../../app_update/app_update_service.dart';
import '../../app_update/presentation/force_update_screen.dart';
import '../../flow_nav/models/flow_step.dart';
import '../../flow_nav/presentation/flow_progress_bar.dart';
import '../../tutorial/tutorial_controller.dart';
import '../../tutorial/tutorial_step.dart';
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

  // Fabrication keeps its own copy of everything the optimizer reads. The two
  // modules cut different stock, so one shared set of lengths and rules was
  // never right for both.
  final TextEditingController _fabricationMaxExtraPiecesController =
      TextEditingController();
  final TextEditingController _fabricationRedZone1Controller =
      TextEditingController();
  final TextEditingController _fabricationRedZone2Controller =
      TextEditingController();
  final Map<String, TextEditingController> _fabricationSectionLengthControllers =
      <String, TextEditingController>{};

  late NumberingMode _mode;
  late SizeInputMode _sizeInputMode;

  /// null = categories ka menu khula ha; warna wo section jo khula ha.
  String? _openSectionId;
  late final BillingSettingsRepository _billingSettingsRepository;
  late final EstimationSettingsRepository _estimationSettingsRepository;
  late final FabricationSettingsRepository _fabricationSettingsRepository;
  late final PaymentPreferencesApiClient _paymentPreferencesApiClient;
  final AppUpdateService _updateService = AppUpdateService();

  // --- Bill rates -------------------------------------------------------
  // Saved once here and filled in on every bill.
  final BillDefaultsApiClient _billDefaultsApiClient = BillDefaultsApiClient();
  final TextEditingController _labourRateController = TextEditingController();
  final TextEditingController _hardwareRateController = TextEditingController();
  final TextEditingController _aluminiumDiscountController =
      TextEditingController();
  final Map<String, TextEditingController> _glassRateControllers =
      <String, TextEditingController>{
        for (final String type in GlassTypes.all)
          type: TextEditingController(),
      };
  bool _savingBillDefaults = false;

  // --- City -------------------------------------------------------------
  // Which city's rate list this workshop works to. Saved with the rest of the
  // workshop details, because that is what it is: part of who they are.
  String _city = '';
  RateCitiesAvailability? _rateCities;

  Future<void> _loadRateCities() async {
    final RateCitiesAvailability availability = await RateCitiesApiClient()
        .fetch();
    if (mounted) setState(() => _rateCities = availability);
  }

  /// Saves the new city and reloads the rates, which now come from that city's
  /// master.
  ///
  /// The user's own edits are untouched -- they are stored as differences, not
  /// as a copy of the list, so they simply re-apply over the new master. Said
  /// plainly on screen, because "your rates changed" is alarming when you
  /// cannot see why.
  Future<void> _onCityChanged(String city) async {
    final String previous = _city;
    setState(() => _city = city);
    try {
      final BillingSettingsModel current = await _billingSettingsRepository
          .fetchBillingSettings();
      await _billingSettingsRepository.saveBillingSettings(
        current.copyWith(city: city),
      );
      if (mounted) {
        _showBillRatesMessage('City set to $city. Your rate list has changed.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _city = previous);
      _showBillRatesMessage('Could not save your city. Please try again.');
    }
  }

  void _showBillRatesMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadBillDefaults() async {
    try {
      final BillDefaults defaults = await _billDefaultsApiClient.fetch();
      if (!mounted) return;
      setState(() {
        _labourRateController.text = defaults.labourRate;
        _hardwareRateController.text = defaults.hardwareRate;
        _aluminiumDiscountController.text = defaults.aluminiumDiscount;
        for (final MapEntry<String, TextEditingController> e
            in _glassRateControllers.entries) {
          e.value.text = defaults.glass[e.key] ?? '';
        }
      });
    } catch (_) {
      // Leave the boxes as they are; the rest of Settings still works.
    }
  }

  Future<void> _saveBillDefaults() async {
    setState(() => _savingBillDefaults = true);
    try {
      await _billDefaultsApiClient.save(
        BillDefaults(
          labourRate: _labourRateController.text.trim(),
          hardwareRate: _hardwareRateController.text.trim(),
          aluminiumDiscount: _aluminiumDiscountController.text.trim(),
          glass: <String, String>{
            for (final MapEntry<String, TextEditingController> e
                in _glassRateControllers.entries)
              e.key: e.value.text.trim(),
          },
        ),
      );
      if (mounted) _showBillRatesMessage('Bill rates saved.');
    } on BillDefaultsApiException catch (error) {
      if (mounted) _showBillRatesMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showBillRatesMessage('Could not save your rates. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _savingBillDefaults = false);
    }
  }

  bool _deletingAccount = false;
  bool _updateChecking = false;
  bool _updateFound = false;
  AppUpdateStatus? _updateStatus;
  String? _updateMessage;
  final SettingsDefaultsApiClient _settingsDefaultsApiClient =
      SettingsDefaultsApiClient();

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
    _loadBillDefaults();
    _loadRateCities();
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
        settings: RouteSettings(name: FlowSteps.paymentSettings.id),
        builder: (BuildContext context) =>
            const SubscriptionGateScreen.manage(),
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
    _labourRateController.dispose();
    _hardwareRateController.dispose();
    _aluminiumDiscountController.dispose();
    for (final TextEditingController c in _glassRateControllers.values) {
      c.dispose();
    }
    _contractorController.dispose();
    _workshopController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _maxExtraPiecesController.dispose();
    _redZone1Controller.dispose();
    _redZone2Controller.dispose();
    _fabricationCuttingMarginController.dispose();
    _fabricationMaxExtraPiecesController.dispose();
    _fabricationRedZone1Controller.dispose();
    _fabricationRedZone2Controller.dispose();
    for (final TextEditingController controller
        in _sectionLengthControllers.values) {
      controller.dispose();
    }
    for (final TextEditingController controller
        in _fabricationSectionLengthControllers.values) {
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
        _city = settings.city;
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
      _fabricationMaxExtraPiecesController.text = ExtraPiecesAllowance.fromSettings(
        maxExtraPieces: settings.maxExtraPieces,
        enforce: settings.enforceMaxExtraPieces,
      ).text;
      _fabricationRedZone1Controller.text = _formatNumber(settings.redZoneEven);
      _fabricationRedZone2Controller.text = _formatNumber(settings.redZoneOdd);
      _syncSectionLengthControllers(
        _fabricationSectionLengthControllers,
        settings.sectionLengths,
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

      _maxExtraPiecesController.text = ExtraPiecesAllowance.fromSettings(
        maxExtraPieces: settings.maxExtraPieces,
        enforce: settings.enforceMaxExtraPieces,
      ).text;
      _redZone1Controller.text = _formatNumber(settings.redZoneEven);
      _redZone2Controller.text = _formatNumber(settings.redZoneOdd);

      _syncSectionLengthControllers(
        _sectionLengthControllers,
        settings.sectionLengths,
      );
      final Set<String> activeMarginKeys = settings.cuttingMargins.keys.toSet();
      final List<String> staleMarginKeys = _cuttingMarginControllers.keys
          .where((String key) => !activeMarginKeys.contains(key))
          .toList(growable: false);
      for (final String key in staleMarginKeys) {
        _cuttingMarginControllers.remove(key)?.dispose();
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
      final RenewalMode mode = await _paymentPreferencesApiClient
          .fetchRenewalMode();
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
      final RenewalMode saved = await _paymentPreferencesApiClient
          .saveRenewalMode(mode);
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

  String? _extraPiecesValidator(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Required';
    }
    if (ExtraPiecesAllowance.tryParse(text) == null) {
      return 'Enter * or a whole number';
    }
    return null;
  }

  /// Points one controller at each section the server sent, and drops the
  /// controllers for sections it no longer has.
  void _syncSectionLengthControllers(
    Map<String, TextEditingController> controllers,
    Map<String, List<int>> sectionLengths,
  ) {
    final Set<String> activeKeys = sectionLengths.keys.toSet();
    final List<String> staleKeys = controllers.keys
        .where((String key) => !activeKeys.contains(key))
        .toList(growable: false);
    for (final String key in staleKeys) {
      controllers.remove(key)?.dispose();
    }
    for (final MapEntry<String, List<int>> entry in sectionLengths.entries) {
      final TextEditingController controller = controllers.putIfAbsent(
        entry.key,
        TextEditingController.new,
      );
      controller.text = _joinLengths(entry.value);
    }
  }

  /// Starting the tour pops the user back to Home, because that is where it
  /// begins and where its first step points.
  /// A way to reach an update that is always there.
  ///
  /// The startup prompt is easy to miss and gone once dismissed, and Play's
  /// auto-update is off for plenty of people -- so a user could sit on an old
  /// build for weeks with no idea. This checks on demand and, when there is
  /// something newer, takes them straight to it.
  Widget _buildAppUpdateCard(BuildContext context) {
    return _buildSettingsCard(
      context,
      icon: Icons.system_update_rounded,
      title: 'App Update',
      subtitle: ApiConfig.isDirectWebsiteBuild
          ? 'Naya version mile to yahin se download aur install ho jayega.'
          : 'Naya version mile to Play Store se update kar sakte hain.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_updateMessage != null) ...<Widget>[
            Text(
              _updateMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _updateFound ? AppTheme.success : AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
          ],
          FilledButton.icon(
            onPressed: _updateChecking ? null : _checkForUpdate,
            icon: _updateChecking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            label: Text(
              _updateChecking ? 'Dekh rahe hain…' : 'Check for update',
            ),
          ),
          if (_updateFound) ...<Widget>[
            const SizedBox(height: 10),
            UpdateActionArea(
              apkUrl: _updateStatus!.apkUrl,
              storeUrl: _updateStatus!.storeUrl,
              service: _updateService,
              idleLabel: 'Update Now',
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _checkForUpdate() async {
    setState(() {
      _updateChecking = true;
      _updateMessage = null;
    });
    final AppUpdateStatus status = await _updateService.check();
    if (!mounted) return;
    setState(() {
      _updateChecking = false;
      _updateStatus = status;
      _updateFound = status.requirement != AppUpdateRequirement.none;
      _updateMessage = _updateFound
          ? (status.latestVersionName.isNotEmpty
                ? 'Naya version ${status.latestVersionName} maujood hai.'
                : 'Naya version maujood hai.')
          : 'Aap ke paas pehle se latest version hai.';
    });
  }

  /// Rates that are the same on every bill, kept once instead of retyped.
  ///
  /// Everything here is optional. A rate left blank arrives at the bill as an
  /// empty box to fill in — never as a zero, which would price that part of
  /// the job at nothing on a bill that otherwise looks correct.
  Widget _buildBillRatesCard(BuildContext context) {
    return _buildSettingsCard(
      context,
      icon: Icons.receipt_long_rounded,
      title: 'Bill Rates',
      subtitle:
          'Ye rates har bill par khud bhar jayenge, taake baar baar likhne na '
          'parein. Bill par jab chahein badal bhi sakte hain — yahan sirf '
          'shuruaati qeemat rakhi jati hai. Jo khali chhorenge wo bill par '
          'khali hi aayega.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildRateField(
            context,
            key: const Key('bill_default_labour'),
            controller: _labourRateController,
            label: 'Labour rate (per foot)',
          ),
          _buildRateField(
            context,
            key: const Key('bill_default_hardware'),
            controller: _hardwareRateController,
            label: 'Hardware rate (per window)',
          ),
          _buildRateField(
            context,
            key: const Key('bill_default_discount'),
            controller: _aluminiumDiscountController,
            label: 'Aluminium discount %',
          ),
          const SizedBox(height: 8),
          Text(
            'Glass ke rates (per sq ft)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Bill par jo glass likhenge, usi ka rate khud aa jayega.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          ...GlassTypes.all.map((String type) {
            return _buildRateField(
              context,
              key: Key('bill_default_glass_${type.replaceAll(' ', '_')}'),
              controller: _glassRateControllers[type]!,
              label: type,
            );
          }),
          const SizedBox(height: 4),
          FilledButton.icon(
            key: const Key('bill_defaults_save'),
            onPressed: _savingBillDefaults ? null : _saveBillDefaults,
            icon: _savingBillDefaults
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(_savingBillDefaults ? 'Saving...' : 'Save Rates'),
          ),
        ],
      ),
    );
  }

  Widget _buildRateField(
    BuildContext context, {
    required Key key,
    required TextEditingController controller,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        key: key,
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
        ],
        decoration: InputDecoration(
          labelText: label,
          hintText: 'Optional',
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildThemeCard(BuildContext context) {
    return _buildSettingsCard(
      context,
      icon: Icons.palette_outlined,
      title: 'Theme',
      subtitle:
          'Din mein light aur raat mein dark — ya phone ke sath chalne dein. '
          'Aap ki pasand yaad rehti hai.',
      child: ListenableBuilder(
        listenable: ThemeController.instance,
        builder: (BuildContext context, Widget? child) {
          final AppThemeMode current = ThemeController.instance.mode;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: AppThemeMode.values.map((AppThemeMode mode) {
              final bool selected = mode == current;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: selected
                      ? AppTheme.royalBlue.withValues(alpha: 0.10)
                      : AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    key: Key('theme_mode_${mode.name}'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => ThemeController.instance.setMode(mode),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            mode.icon,
                            size: 22,
                            color: selected
                                ? AppTheme.royalBlue
                                : AppTheme.slate,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  mode.label,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  mode.description,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          if (selected)
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 20,
                              color: AppTheme.royalBlue,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(growable: false),
          );
        },
      ),
    );
  }

  Widget _buildTutorialCard(BuildContext context) {
    return _buildSettingsCard(
      context,
      icon: Icons.play_circle_outline_rounded,
      title: 'App kaise istemal karein',
      subtitle:
          'Do alag rehnumai: Estimation — window ke naap se le kar tayyar bill '
          'tak. Fabrication — cutting list aur sheeshe ki report tak. Dono '
          'asli screens par, Urdu mein.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FilledButton.icon(
            onPressed: () => _startTour(context, TutorialTour.estimation),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              'ایسٹیمیشن کی رہنمائی',
              style: UrduText.body(color: Colors.white, fontSize: 15),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: () => _startTour(context, TutorialTour.fabrication),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              'فیبریکیشن کی رہنمائی',
              style: UrduText.body(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  /// Which bubble a settings section belongs to.
  ///
  /// Only the sections the owner named get their own bubble; the rest sit on
  /// Settings itself, so the chain never grows a leaf nobody asked for.
  FlowStep _flowStepForSection(String? sectionId) => switch (sectionId) {
    'window_input' => FlowSteps.windowSettings,
    'rates' => FlowSteps.rateSettings,
    'estimation' => FlowSteps.estimationSettings,
    'fabrication' => FlowSteps.fabricationSettings,
    'company' => FlowSteps.companySettings,
    'payment' => FlowSteps.paymentSettings,
    _ => FlowSteps.settings,
  };

  void _startTour(BuildContext context, TutorialTour tour) {
    TutorialController.instance.start(tour: tour);
    Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
  }

  /// Rates get their own full screen -- the table is far too wide to sit
  /// inside a settings card -- so this card is the door to it.
  /// Section rates and bill rates, one above the other, under one heading.
  ///
  /// They were two separate entries in Settings, which read as two unrelated
  /// jobs. They are not: both are "what this workshop charges", and someone
  /// setting up their prices wants to do it in one sitting rather than find
  /// half of it somewhere else in the list.
  ///
  /// Section rates stay on top -- they are the ones that change with the
  /// market and get opened again and again. The bill rates are set once and
  /// rarely touched, so they sit below.
  Widget _buildRatesOfSectionsAndBillCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildRatesCard(context),
        const SizedBox(height: AppTheme.space5),
        _buildBillRatesCard(context),
      ],
    );
  }

  Widget _buildRatesCard(BuildContext context) {
    return _buildSettingsCard(
      context,
      icon: Icons.price_change_rounded,
      title: 'Section Rates',
      videoKey: TutorialVideos.settingsRates,
      subtitle:
          'The rate for every section, by gauge and colour. Change any of '
          'them to price with your own.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CityPickerField(
            value: _city,
            availability: _rateCities,
            onChanged: _onCityChanged,
            helperText:
                'Rates differ from city to city. Changing this switches you to '
                'that city\'s list — any rate you have edited yourself stays '
                'as you set it.',
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  settings: RouteSettings(name: FlowSteps.rateSettings.id),
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

  /// A "restore defaults" button for one block of settings.
  ///
  /// Every group that can be edited needs a way back -- a mistyped figure in
  /// here is otherwise permanent unless the user remembers what was there.
  Widget _buildRestoreButton({
    required String label,
    required Future<void> Function() onRestore,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () async {
          final bool? sure = await showDialog<bool>(
            context: context,
            builder: (BuildContext ctx) => AlertDialog(
              title: Text('Restore $label?'),
              content: const Text(
                'Your values here will be replaced by the ones Quick AL '
                'ships with.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Keep mine'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Restore'),
                ),
              ],
            ),
          );
          if (sure != true) return;
          await onRestore();
        },
        icon: const Icon(Icons.restart_alt_rounded, size: 18),
        label: Text('Restore $label'),
      ),
    );
  }

  /// Asks the server to copy its shipped template over this user's copy, then
  /// reloads so the fields show what actually landed.
  Future<void> _restoreFromServer(
    List<SettingsGroup> groups,
    Future<void> Function() reload,
  ) async {
    try {
      await _settingsDefaultsApiClient.restore(groups);
      await reload();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Default values restored.')));
    } on SettingsDefaultsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  /// Puts every section back to the mill's standard bars.
  ///
  /// Sections whose name ends in F come in 15/17/19 ft; everything else comes
  /// in 14/16/18. Without this, a user who mistyped a length had no way back
  /// except remembering what had been there before.
  void _restoreStandardSectionLengths(
    Map<String, TextEditingController> controllers,
  ) {
    setState(() {
      for (final String key in controllers.keys) {
        final bool isF = key.toUpperCase().endsWith('F');
        controllers[key]!.text = isF ? '15, 17, 19' : '14, 16, 18';
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

    final Map<String, List<int>>? sectionLengths = _collectSectionLengths(
      _sectionLengthControllers,
    );
    if (sectionLengths == null) {
      return;
    }
    final Map<String, double> cuttingMargins = <String, double>{};
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

    final ExtraPiecesAllowance allowance =
        ExtraPiecesAllowance.tryParse(_maxExtraPiecesController.text) ??
        const ExtraPiecesAllowance.unlimited();

    try {
      final EstimationSettingsModel saved = await _estimationSettingsRepository
          .saveEstimationSettings(
            EstimationSettingsModel(
              sectionLengths: sectionLengths,
              cuttingMargins: cuttingMargins,
              maxExtraPieces: allowance.storedLimit,
              enforceMaxExtraPieces: allowance.enforce,
              redZoneEven: double.parse(_redZone1Controller.text.trim()),
              redZoneOdd: double.parse(_redZone2Controller.text.trim()),
            ),
          );

      if (!mounted) {
        return;
      }

      _maxExtraPiecesController.text = ExtraPiecesAllowance.fromSettings(
        maxExtraPieces: saved.maxExtraPieces,
        enforce: saved.enforceMaxExtraPieces,
      ).text;
      _redZone1Controller.text = _formatNumber(saved.redZoneEven);
      _redZone2Controller.text = _formatNumber(saved.redZoneOdd);
      _syncSectionLengthControllers(
        _sectionLengthControllers,
        saved.sectionLengths,
      );

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

    final Map<String, List<int>>? sectionLengths = _collectSectionLengths(
      _fabricationSectionLengthControllers,
    );
    if (sectionLengths == null) {
      return;
    }

    final ExtraPiecesAllowance allowance =
        ExtraPiecesAllowance.tryParse(
          _fabricationMaxExtraPiecesController.text,
        ) ??
        const ExtraPiecesAllowance.unlimited();

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
              sectionLengths: sectionLengths,
              maxExtraPieces: allowance.storedLimit,
              enforceMaxExtraPieces: allowance.enforce,
              redZoneEven: double.parse(
                _fabricationRedZone1Controller.text.trim(),
              ),
              redZoneOdd: double.parse(
                _fabricationRedZone2Controller.text.trim(),
              ),
            ),
          );

      if (!mounted) {
        return;
      }

      _fabricationCuttingMarginController.text = _formatNumber(
        saved.cuttingMarginCm,
      );
      _fabricationMaxExtraPiecesController.text =
          ExtraPiecesAllowance.fromSettings(
            maxExtraPieces: saved.maxExtraPieces,
            enforce: saved.enforceMaxExtraPieces,
          ).text;
      _fabricationRedZone1Controller.text = _formatNumber(saved.redZoneEven);
      _fabricationRedZone2Controller.text = _formatNumber(saved.redZoneOdd);
      _syncSectionLengthControllers(
        _fabricationSectionLengthControllers,
        saved.sectionLengths,
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

  List<String> _sortedSectionKeys([
    Map<String, TextEditingController>? controllers,
  ]) {
    final List<String> keys = (controllers ?? _sectionLengthControllers).keys
        .toList();
    keys.sort();
    return keys;
  }

  /// The typed-in lengths for every section, or null after telling the user
  /// which section it could not read.
  Map<String, List<int>>? _collectSectionLengths(
    Map<String, TextEditingController> controllers,
  ) {
    final Map<String, List<int>> sectionLengths = <String, List<int>>{};
    for (final String key in _sortedSectionKeys(controllers)) {
      final List<int>? parsed = _parseLengthList(controllers[key]?.text);
      if (parsed == null) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Invalid lengths for $key.')));
        return null;
      }
      sectionLengths[key] = parsed;
    }
    return sectionLengths;
  }

  List<String> _sortedCuttingMarginKeys() {
    final List<String> keys = _cuttingMarginControllers.keys.toList();
    keys.sort();
    return keys;
  }

  String _joinLengths(List<int> lengths) => lengths.join(', ');

  String _formatNumber(double value) {
    // replaceFirst does not expand $1 -- a 1.2cm margin came back as the
    // literal "1$1". Trimming the trailing zeros off a fixed-2 string needs
    // no capture group at all, and is what the rest of the app already does.
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
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

    /// A key from [TutorialVideos]. Puts the watch button in the header, where
    /// someone looks when a setting is not obvious — which is most of them,
    /// the first time.
    String? videoKey,
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
              // Carries the colour of whichever section is open, so opening a
              // row keeps the colour you just tapped instead of dropping back
              // to the same blue on every screen.
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _openAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: _openAccent),
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
              if (videoKey != null) ...<Widget>[
                const SizedBox(width: 8),
                HelpVideoButton(videoKey: videoKey),
              ],
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
      videoKey: TutorialVideos.settingsWindowInput,
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
      videoKey: TutorialVideos.settingsCompany,
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
      videoKey: TutorialVideos.settingsEstimation,
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
                  _buildSectionLengthsCluster(
                    context,
                    controllers: _sectionLengthControllers,
                  ),
                  _buildSettingsCluster(
                    context,
                    title: 'Cutting Margin of Each Section',
                    subtitle:
                        'These margins are applied per section during estimation calculations.',
                    children: <Widget>[
                      _buildRestoreButton(
                        label: 'cutting margins',
                        onRestore: () => _restoreFromServer(<SettingsGroup>[
                          SettingsGroup.cuttingMargins,
                        ], _loadEstimationSettings),
                      ),
                      const SizedBox(height: 4),
                      ..._sortedCuttingMarginKeys().map((String key) {
                        final TextEditingController controller =
                            _cuttingMarginControllers[key]!;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextFormField(
                            controller: controller,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: _requiredDecimalWithZeroValidator,
                            decoration: _inputDecoration(key),
                          ),
                        );
                      }),
                    ],
                  ),
                  _buildRedZoneCluster(
                    context,
                    evenController: _redZone1Controller,
                    oddController: _redZone2Controller,
                    onRestore: () => _restoreFromServer(<SettingsGroup>[
                      SettingsGroup.lengthRules,
                    ], _loadEstimationSettings),
                  ),
                  _buildExtraPiecesCluster(
                    context,
                    controller: _maxExtraPiecesController,
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

  /// The leftover-pieces allowance, shared by both modules.
  ///
  /// `*` is the default and the setting most people should never have to
  /// touch: the optimizer already prefers full lengths and only reaches for a
  /// leftover when nothing else fits, so capping the count mostly just turns
  /// workable jobs into failures. A number is there for anyone who wants the
  /// old strict behaviour back.
  Widget _buildExtraPiecesCluster(
    BuildContext context, {
    required TextEditingController controller,
  }) {
    return _buildSettingsCluster(
      context,
      title: 'Extra Pieces Allowance',
      subtitle:
          'How many leftover (offcut) bars a cutting plan may end up with. '
          'Keep it at * and Quick AL decides for itself, making as few '
          'leftovers as the job allows — full lengths always come first, and '
          'a leftover is only ever used when nothing else fits. Put a number '
          'here instead to cap them, for example 1 or 2.',
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              controller.text = ExtraPiecesAllowance.unlimitedText;
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Back to *. Save to apply it.'),
                ),
              );
            },
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Reset to *'),
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.text,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9*]')),
            LengthLimitingTextInputFormatter(3),
          ],
          validator: _extraPiecesValidator,
          decoration: _inputDecoration(
            'Max Extra Pieces',
            hint: '* (let Quick AL decide)',
          ),
        ),
      ],
    );
  }

  Widget _buildRedZoneCluster(
    BuildContext context, {
    required TextEditingController evenController,
    required TextEditingController oddController,
    required VoidCallback onRestore,
  }) {
    return _buildSettingsCluster(
      context,
      title: 'Red Zone Thresholds',
      subtitle:
          'These thresholds control when the optimizer may keep a custom extra piece before rounding up to the smallest stock length.',
      children: <Widget>[
        _buildRestoreButton(
          label: 'red zone and extra pieces',
          onRestore: () async => onRestore(),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: evenController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: _requiredDecimalValidator,
          decoration: _inputDecoration(
            'RedZoneEven',
            hint: 'Even groups: 14, 16, 18',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: oddController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: _requiredDecimalValidator,
          decoration: _inputDecoration(
            'RedZoneOdd',
            hint: 'Odd groups: 15, 17, 19',
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLengthsCluster(
    BuildContext context, {
    required Map<String, TextEditingController> controllers,
  }) {
    return _buildSettingsCluster(
      context,
      title: 'Assigned Lengths for Section',
      subtitle:
          'Lengths of the bars your dealer stocks, in feet. '
          'Use commas, for example 14, 16, 18.',
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _restoreStandardSectionLengths(controllers),
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Restore standard lengths'),
          ),
        ),
        const SizedBox(height: 4),
        ..._sortedSectionKeys(controllers).map((String key) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              controller: controllers[key]!,
              validator: _sectionLengthsValidator,
              decoration: _inputDecoration(key),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFabricationSettingsCard(BuildContext context) {
    return _buildSettingsCard(
      context,
      icon: Icons.construction_rounded,
      title: 'Fabrication Settings',
      videoKey: TutorialVideos.settingsFabrication,
      subtitle:
          'Fabrication has its own lengths, red zones and allowance. Nothing '
          'here touches Estimation, and nothing there touches fabrication.',
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
                      _buildRestoreButton(
                        label: 'fabrication margin',
                        onRestore: () => _restoreFromServer(<SettingsGroup>[
                          SettingsGroup.fabricator,
                        ], _loadFabricationSettings),
                      ),
                      const SizedBox(height: 4),
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
                  _buildSectionLengthsCluster(
                    context,
                    controllers: _fabricationSectionLengthControllers,
                  ),
                  _buildRedZoneCluster(
                    context,
                    evenController: _fabricationRedZone1Controller,
                    oddController: _fabricationRedZone2Controller,
                    onRestore: () => _restoreFromServer(<SettingsGroup>[
                      SettingsGroup.fabricationLengthRules,
                    ], _loadFabricationSettings),
                  ),
                  _buildExtraPiecesCluster(
                    context,
                    controller: _fabricationMaxExtraPiecesController,
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
      videoKey: TutorialVideos.settingsLegal,
      subtitle:
          'Our policies and how to reach us. Everything opens inside the app.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildSettingsCluster(
            context,
            title: 'Policies',
            subtitle:
                'The terms that apply to your subscription and your data.',
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
            ],
          ),
          const SizedBox(height: 16),
          _buildSettingsCluster(
            context,
            title: 'Delete account',
            subtitle:
                'Remove your account and everything saved in it. This cannot '
                'be undone.',
            children: <Widget>[_buildDeleteAccountButton(context)],
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
  /// The account-deletion path that actually works for this app's users.
  ///
  /// Sign-in is by Google, so those accounts have no password -- and the web
  /// form asks for one, which meant nobody could delete anything. Here the
  /// session already says who is asking.
  Widget _buildDeleteAccountButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _deletingAccount ? null : _confirmDeleteAccount,
        icon: _deletingAccount
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.person_remove_rounded),
        label: Text(_deletingAccount ? 'Deleting…' : 'Delete Account & Data'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.danger,
          side: BorderSide(color: AppTheme.danger.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  /// Two steps on purpose. The first says what goes; the second makes them
  /// type the word, so a mis-tap cannot destroy someone's projects.
  Future<void> _confirmDeleteAccount() async {
    final bool? first = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: AppTheme.danger,
          size: 34,
        ),
        title: const Text('Delete your account?'),
        content: const Text(
          'This removes your profile, every saved project, your settings and '
          'your subscription access. It cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep my account'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => _DeleteAccountConfirmDialog(),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingAccount = true);
    try {
      await AuthController.instance.deleteAccount();
      // Signed out by the deletion, so the app falls back to the sign-in
      // screen on its own; just clear this screen off the stack.
      if (mounted) {
        Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _deletingAccount = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is AuthApiException
                ? error.message
                : 'Could not delete the account. Nothing has been removed.',
          ),
        ),
      );
    }
  }

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
              Icon(
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
  List<_SettingsSection> get _allSections => <_SettingsSection>[
    // Ordered by how often a working day needs them: the settings that change
    // a job come first, then money, then the things you set up once. Help and
    // App Update sit near the bottom, just above Account -- useful, but not
    // what someone opens Settings for.
    _SettingsSection(
      id: 'window_input',
      icon: Icons.tune_rounded,
      title: 'Window Input',
      subtitle: 'Numbering aur size entry ka tareeqa.',
      builder: _buildWindowInputCard,
      accent: const Color(0xFF3882E4),
    ),
    _SettingsSection(
      id: 'rates',
      icon: Icons.price_change_rounded,
      title: 'Rates of Sections and Bill',
      subtitle:
          'Section ke rates, aur labour/hardware/glass ke bill rates — ek hi '
          'jagah.',
      builder: _buildRatesOfSectionsAndBillCard,
      accent: const Color(0xFF12A594),
    ),
    _SettingsSection(
      id: 'estimation',
      icon: Icons.straighten_outlined,
      title: 'Estimation Settings',
      subtitle: 'Lengths, cutting margins, red zone, extra pieces.',
      builder: _buildEstimationSettingsCard,
      accent: const Color(0xFF7C5CD6),
    ),
    _SettingsSection(
      id: 'fabrication',
      icon: Icons.handyman_outlined,
      title: 'Fabrication Settings',
      subtitle: 'Fabrication cutting margin.',
      builder: _buildFabricationSettingsCard,
      accent: const Color(0xFFE07B39),
    ),
    _SettingsSection(
      id: 'company',
      icon: Icons.apartment_rounded,
      title: 'Company Information',
      subtitle: 'Workshop ka naam, phone aur address.',
      builder: _buildCompanyInformationCard,
      accent: const Color(0xFF2E7D9A),
    ),
    // Bill Rates has no entry of its own: it lives inside "Rates of Sections
    // and Bill", directly under the section rates. Both answer the same
    // question -- what this workshop charges -- and splitting them meant
    // setting your prices in two places.
    _SettingsSection(
      id: 'theme',
      icon: Icons.palette_outlined,
      title: 'Theme',
      subtitle: 'Light ya dark — app ka rang apni pasand ka rakhein.',
      builder: _buildThemeCard,
      accent: const Color(0xFF6D4AC4),
    ),
    _SettingsSection(
      id: 'payment',
      icon: Icons.credit_card_rounded,
      title: 'Payment & Renewal',
      subtitle: 'Aap ka plan aur renewal.',
      builder: _buildPaymentRenewalCard,
      accent: const Color(0xFF1F9254),
      // Hidden while the app is free. Set this back to false to bring it back
      // exactly as it was -- nothing else has changed.
      hidden: true,
    ),
    _SettingsSection(
      id: 'legal',
      icon: Icons.gavel_rounded,
      title: 'Legal & Support',
      subtitle: 'Policies aur customer support.',
      builder: _buildLegalSupportCard,
      accent: const Color(0xFF5C6BC0),
    ),
    _SettingsSection(
      id: 'tutorial',
      icon: Icons.play_circle_outline_rounded,
      title: 'App kaise istemal karein',
      subtitle: 'Qadam ba qadam rehnumai — Urdu mein.',
      builder: _buildTutorialCard,
      accent: const Color(0xFFD4477E),
    ),
    _SettingsSection(
      id: 'app_update',
      icon: Icons.system_update_rounded,
      title: 'App Update',
      subtitle: 'Naya version aaya ya nahi, yahan se dekhein.',
      builder: _buildAppUpdateCard,
      accent: const Color(0xFF0E8FA8),
    ),
    _SettingsSection(
      id: 'account',
      icon: Icons.person_outline_rounded,
      title: 'Account',
      subtitle: 'Sign out.',
      builder: _buildAccountCard,
      accent: const Color(0xFF64748B),
    ),
  ];

  /// What the list actually shows.
  ///
  /// [_allSections] is the whole set, including anything switched off for
  /// now. Filtering here rather than deleting entries means a hidden section
  /// keeps its place, its colour and its card, and comes back by flipping one
  /// flag.
  List<_SettingsSection> get _sections =>
      _allSections.where((_SettingsSection s) => !s.hidden).toList(growable: false);

  /// The open section's colour, or the app blue when the menu is showing.
  ///
  /// Read rather than passed: [_buildSettingsCard] is called from every
  /// section builder, and threading a colour through all of them would be ten
  /// edits to say something only one of them can be at a time.
  Color get _openAccent {
    final String? id = _openSectionId;
    if (id == null) return AppTheme.violet;
    for (final _SettingsSection section in _sections) {
      if (section.id == id) return section.accent;
    }
    return AppTheme.violet;
  }

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
              // A tinted plate in the section's own colour, with the icon in
              // white on top. Enough to tell the rows apart at a glance
              // without turning the list into a paint chart.
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      section.accent,
                      Color.lerp(section.accent, Colors.black, 0.18)!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: section.accent.withValues(alpha: 0.32),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(section.icon, color: Colors.white, size: 22),
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
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppTheme.slate),
                    ),
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
        // Settings opens its sections in place rather than pushing routes, so
        // the bubble follows which section is open instead of the route stack.
        bottomNavigationBar: FlowProgressBar(
          stepId: _flowStepForSection(_openSectionId).id,
        ),
        body: Container(
          decoration: BoxDecoration(
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

  /// The tile's own colour.
  ///
  /// Ten identical blue rows made the list hard to scan -- you read every
  /// title to find the one you wanted. A colour per section gives each one a
  /// shape you remember, so the second visit is quicker than the first.
  final Color accent;

  /// Kept out of the list without being taken out of the app.
  ///
  /// Used while Quick AL is free: there is nothing to pay for, so a Payment
  /// entry only raises a question the app cannot answer. Everything behind it
  /// — the card, the plans, the whole subscription flow — is untouched and
  /// still reachable in code, so putting it back is this one flag.
  final bool hidden;

  const _SettingsSection({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.builder,
    required this.accent,
    this.hidden = false,
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

/// The second confirmation: typing the word is the deliberate act.
///
/// A plain "are you sure" is one mis-tap away from destroying every project a
/// workshop has saved, and there is no undo behind it.
class _DeleteAccountConfirmDialog extends StatefulWidget {
  @override
  State<_DeleteAccountConfirmDialog> createState() =>
      _DeleteAccountConfirmDialogState();
}

class _DeleteAccountConfirmDialogState
    extends State<_DeleteAccountConfirmDialog> {
  static const String _word = 'DELETE';
  final TextEditingController _controller = TextEditingController();

  bool get _matches => _controller.text.trim().toUpperCase() == _word;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Type DELETE to confirm'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'This is the last step. Once it is done your projects cannot be '
            'brought back.',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Type $_word',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
          child: const Text('Delete permanently'),
        ),
      ],
    );
  }
}
