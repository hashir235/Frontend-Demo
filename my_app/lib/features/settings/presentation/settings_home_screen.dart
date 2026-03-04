import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../data/billing_settings_repository.dart';
import '../data/estimation_settings_repository.dart';
import '../models/billing_settings.dart';
import '../models/estimation_settings.dart';
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

  late NumberingMode _mode;
  late final BillingSettingsRepository _billingSettingsRepository;
  late final EstimationSettingsRepository _estimationSettingsRepository;

  bool _isLoadingBillingSettings = true;
  bool _isSavingBillingSettings = false;
  String? _billingSettingsError;

  bool _isLoadingEstimationSettings = true;
  bool _isSavingEstimationSettings = false;
  String? _estimationSettingsError;
  bool _enforceMaxExtraPieces = false;

  @override
  void initState() {
    super.initState();
    _mode = AppSettings.instance.numberingMode;
    _billingSettingsRepository = BillingSettingsRepository();
    _estimationSettingsRepository = EstimationSettingsRepository();
    AppSettings.instance.addListener(_onSettingsChanged);
    _loadBillingSettings();
    _loadEstimationSettings();
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
      final BillingSettingsModel settings =
          await _billingSettingsRepository.fetchBillingSettings();
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
      _redZone1Controller.text = _formatNumber(settings.redZone1);
      _redZone2Controller.text = _formatNumber(settings.redZone2);
      _enforceMaxExtraPieces = settings.enforceMaxExtraPieces;

      final Set<String> activeKeys = settings.sectionLengths.keys.toSet();
      final List<String> staleKeys =
          _sectionLengthControllers.keys
              .where((String key) => !activeKeys.contains(key))
              .toList(growable: false);
      for (final String key in staleKeys) {
        _sectionLengthControllers.remove(key)?.dispose();
      }
      final Set<String> activeMarginKeys = settings.cuttingMargins.keys.toSet();
      final List<String> staleMarginKeys =
          _cuttingMarginControllers.keys
              .where((String key) => !activeMarginKeys.contains(key))
              .toList(growable: false);
      for (final String key in staleMarginKeys) {
        _cuttingMarginControllers.remove(key)?.dispose();
      }

      for (final MapEntry<String, List<int>> entry
          in settings.sectionLengths.entries) {
        final TextEditingController controller =
            _sectionLengthControllers.putIfAbsent(
              entry.key,
              TextEditingController.new,
            );
        controller.text = _joinLengths(entry.value);
      }
      for (final MapEntry<String, double> entry in settings.cuttingMargins.entries) {
        final TextEditingController controller =
            _cuttingMarginControllers.putIfAbsent(
              entry.key,
              TextEditingController.new,
            );
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
      final BillingSettingsModel saved =
          await _billingSettingsRepository.saveBillingSettings(
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('General settings saved.')),
      );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _billingSettingsError = error.toString();
        _isSavingBillingSettings = false;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
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
      final List<int>? parsed =
          _parseLengthList(_sectionLengthControllers[key]?.text);
      if (parsed == null) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid lengths for $key.')),
        );
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
      final EstimationSettingsModel saved =
          await _estimationSettingsRepository.saveEstimationSettings(
            EstimationSettingsModel(
              sectionLengths: sectionLengths,
              cuttingMargins: cuttingMargins,
              maxExtraPieces: int.parse(
                _maxExtraPiecesController.text.trim(),
              ),
              enforceMaxExtraPieces: _enforceMaxExtraPieces,
              redZone1: double.parse(_redZone1Controller.text.trim()),
              redZone2: double.parse(_redZone2Controller.text.trim()),
            ),
          );

      if (!mounted) {
        return;
      }

      _maxExtraPiecesController.text = saved.maxExtraPieces.toString();
      _redZone1Controller.text = _formatNumber(saved.redZone1);
      _redZone2Controller.text = _formatNumber(saved.redZone2);
      _enforceMaxExtraPieces = saved.enforceMaxExtraPieces;

      for (final MapEntry<String, List<int>> entry in saved.sectionLengths.entries) {
        final TextEditingController controller =
            _sectionLengthControllers.putIfAbsent(
              entry.key,
              TextEditingController.new,
            );
        controller.text = _joinLengths(entry.value);
      }
      for (final MapEntry<String, double> entry in saved.cuttingMargins.entries) {
        final TextEditingController controller =
            _cuttingMarginControllers.putIfAbsent(
              entry.key,
              TextEditingController.new,
            );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
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
      ),
    );
  }

  Widget _buildEstimationSubheading(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppTheme.deepTeal,
          fontWeight: FontWeight.w700,
        ),
      ),
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
              _buildSectionTitle(context, 'Window Numbering'),
              const SizedBox(height: 8),
              _buildSectionSubtitle(
                context,
                'Choose how window numbers are assigned in Estimation.',
              ),
              const SizedBox(height: 18),
              RadioListTile<NumberingMode>(
                value: NumberingMode.auto,
                groupValue: _mode,
                title: const Text('Auto (default)'),
                subtitle: const Text(
                  'Automatically increments window numbers for each new entry.',
                ),
                onChanged: (NumberingMode? value) {
                  if (value != null) {
                    _updateMode(value);
                  }
                },
              ),
              RadioListTile<NumberingMode>(
                value: NumberingMode.manual,
                groupValue: _mode,
                title: const Text('Manual'),
                subtitle: const Text(
                  'User must enter a window number before height/width.',
                ),
                onChanged: (NumberingMode? value) {
                  if (value != null) {
                    _updateMode(value);
                  }
                },
              ),
              const SizedBox(height: 28),
              _buildSectionTitle(context, 'Company Information'),
              const SizedBox(height: 8),
              _buildSectionSubtitle(
                context,
                'These values are auto-filled in billing.',
              ),
              const SizedBox(height: 18),
              if (_isLoadingBillingSettings)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Form(
                  key: _billingFormKey,
                  child: Column(
                    children: <Widget>[
                      if (_billingSettingsError != null) ...<Widget>[
                        Text(
                          _billingSettingsError!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _loadBillingSettings,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry Load'),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
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
                      const SizedBox(height: 16),
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
              const SizedBox(height: 32),
              _buildSectionTitle(context, 'Estimation Settings'),
              const SizedBox(height: 8),
              _buildSectionSubtitle(
                context,
                'Manage assigned section lengths and optimization limits.',
              ),
              const SizedBox(height: 18),
              if (_isLoadingEstimationSettings)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Form(
                  key: _estimationFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (_estimationSettingsError != null) ...<Widget>[
                        Text(
                          _estimationSettingsError!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _loadEstimationSettings,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry Load'),
                          ),
                        ),
                      ],
                      _buildEstimationSubheading(
                        context,
                        'Assigned Lengths for Section',
                      ),
                      _buildSectionSubtitle(
                        context,
                        'Use comma-separated whole numbers, for example 14, 16, 18.',
                      ),
                      const SizedBox(height: 12),
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
                      _buildEstimationSubheading(
                        context,
                        'Cutting Margin of Each Section',
                      ),
                      ..._sortedCuttingMarginKeys().map((String key) {
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
                      }),
                      _buildEstimationSubheading(context, 'Red Zone Theory'),
                      TextFormField(
                        controller: _redZone1Controller,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: _requiredDecimalValidator,
                        decoration: _inputDecoration('Red Zone 1'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _redZone2Controller,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: _requiredDecimalValidator,
                        decoration: _inputDecoration('Red Zone 2'),
                      ),
                      _buildEstimationSubheading(
                        context,
                        'Extra Pieces Allowance',
                      ),
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
                      const SizedBox(height: 12),
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
            ],
          ),
        ),
      ),
    );
  }
}
