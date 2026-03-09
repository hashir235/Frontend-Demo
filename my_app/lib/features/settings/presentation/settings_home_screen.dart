import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/state/auth_controller.dart';
import '../data/billing_settings_repository.dart';
import '../data/estimation_settings_repository.dart';
import '../data/fabrication_settings_repository.dart';
import '../models/billing_settings.dart';
import '../models/estimation_settings.dart';
import '../models/fabrication_settings.dart';
import '../state/app_settings.dart';
import '../state/numbering_mode.dart';

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
  late final BillingSettingsRepository _billingSettingsRepository;
  late final EstimationSettingsRepository _estimationSettingsRepository;
  late final FabricationSettingsRepository _fabricationSettingsRepository;

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
    _billingSettingsRepository = BillingSettingsRepository();
    _estimationSettingsRepository = EstimationSettingsRepository();
    _fabricationSettingsRepository = FabricationSettingsRepository();
    AppSettings.instance.addListener(_onSettingsChanged);
    _loadBillingSettings();
    _loadEstimationSettings();
    _loadFabricationSettings();
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
    });
  }

  void _updateMode(NumberingMode mode) {
    AppSettings.instance.setNumberingMode(mode);
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

  String? _sectionLengthsValidator(String? value) {
    final List<int>? lengths = _parseLengthList(value);
    if (lengths == null) {
      return 'Use comma-separated whole numbers';
    }
    if (lengths.isEmpty) {
      return 'Enter at least one length';
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

  Widget _buildWindowNumberingCard(BuildContext context) {
    return _buildSettingsCard(
      context,
      icon: Icons.pin_outlined,
      title: 'Window Numbering',
      subtitle: 'Choose how new windows receive numbers in Estimation.',
      child: Container(
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
                        'Use comma-separated whole numbers, for example 14, 16, 18.',
                    children: _sortedSectionKeys()
                        .map((String key) {
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
                        })
                        .toList(growable: false),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('General Settings'), centerTitle: true),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[AppTheme.ice, AppTheme.mist],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: <Widget>[
              _buildPageHero(context),
              const SizedBox(height: 20),
              _buildWindowNumberingCard(context),
              const SizedBox(height: 20),
              _buildCompanyInformationCard(context),
              const SizedBox(height: 20),
              _buildEstimationSettingsCard(context),
              const SizedBox(height: 20),
              _buildFabricationSettingsCard(context),
              const SizedBox(height: 20),
              _buildAccountCard(context),
            ],
          ),
        ),
      ),
    );
  }
}
