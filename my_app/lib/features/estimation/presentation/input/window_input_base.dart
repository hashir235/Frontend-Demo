import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'window_input_handler.dart';
import '../../data/project_repository.dart';
import '../../models/window_review_item.dart';
import '../../models/window_type.dart';
import '../../state/estimate_session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../settings/state/numbering_mode.dart';
import '../review_list_screen.dart';

class WindowInputScreen extends StatefulWidget {
  final WindowType node;
  final EstimateSessionStore session;
  final WindowReviewItem? editingItem;

  const WindowInputScreen({
    super.key,
    required this.node,
    required this.session,
    this.editingItem,
  });

  bool get isEditMode => editingItem != null;

  @override
  State<WindowInputScreen> createState() => _WindowInputScreenState();
}

enum _RubberType { fix, u }
enum _LockType { latch, self, handal }

class _WindowInputScreenState extends State<WindowInputScreen> {
  static const int _maxDescriptionLength = 120;
  static const double _collarCardSize = 258;
  static const double _collarCardWidthFactor = 1.16;
  static const double _collarViewportFraction = 0.78;
  final ProjectRepository _projectRepository = ProjectRepository();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _heightInchController = TextEditingController();
  final TextEditingController _heightSuterController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _widthInchController = TextEditingController();
  final TextEditingController _widthSuterController = TextEditingController();
  final TextEditingController _leftWidthController = TextEditingController();
  final TextEditingController _leftWidthInchController = TextEditingController();
  final TextEditingController _leftWidthSuterController = TextEditingController();
  final TextEditingController _archController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _winNoController = TextEditingController();
  final FocusNode _heightFocusNode = FocusNode();

  late final PageController _collarPageController;
  double _collarPageValue = 0;
  late UnitMode _unitMode;
  late _RubberType _rubberType;
  late _LockType _lockType;
  late int _selectedCollar;
  String? _selectedSectionCode;
  String? _winNoError;
  String? _heightError;
  String? _widthError;
  String? _leftWidthError;
  String? _archError;
  late final WindowInputHandler _handler;

  int get _visibleWinNo {
    if (widget.isEditMode) {
      return widget.editingItem!.winNo;
    }
    if (_numberingMode == NumberingMode.manual) {
      final int? parsed = int.tryParse(_winNoController.text.trim());
      return parsed ?? widget.session.nextWinNo;
    }
    return widget.session.nextWinNo;
  }

  bool get _usesSplitWidthInputs => _handler.usesSplitWidthInputs;
  bool get _usesArchInput => _handler.usesArchInput;
  bool get _isFixOnlyRubberWindow {
    final String? windowCode = widget.node.codeName;
    return windowCode == 'F_win' ||
        windowCode == 'FC_win' ||
        windowCode == 'Single_Door' ||
        windowCode == 'Double_Door';
  }

  String get _windowCode => widget.node.codeName ?? '';

  bool get _isCenterSlideLockWindow {
    final String windowCode = _windowCode;
    return windowCode == 'PS4_win' ||
        windowCode == 'MPS4_win' ||
        windowCode == 'SCS_win' ||
        windowCode == 'MSCS_win';
  }

  bool get _isLockSupportedWindow {
    final String windowCode = _windowCode;
    return windowCode == 'S_win' ||
        windowCode == 'MS_win' ||
        windowCode == 'PF3_win' ||
        windowCode == 'PS4_win' ||
        windowCode == 'EF3_win' ||
        windowCode == 'MPF3_win' ||
        windowCode == 'MPS4_win' ||
        windowCode == 'MEF3_win' ||
        windowCode == 'SCF_win' ||
        windowCode == 'SCS_win' ||
        windowCode == 'SCL_win' ||
        windowCode == 'SCR_win' ||
        windowCode == 'MSCF_win' ||
        windowCode == 'MSCS_win' ||
        windowCode == 'MSCL_win' ||
        windowCode == 'MSCR_win';
  }

  bool get _showsLockTypeSelector =>
      _isFabricationFlow && _isLockSupportedWindow;

  bool get _allowsHandalLockType => !_isCenterSlideLockWindow;
  bool get _isFabricationFlow => widget.session.isFabrication;
  bool get _isFabricationCmMode =>
      _isFabricationFlow && _unitMode == UnitMode.feet;
  bool get _isFabricationInchesMode =>
      _isFabricationFlow && _unitMode == UnitMode.inches;
  bool get _showsDoorSectionToggles =>
      _handler is DoorSingleInputHandler || _handler is DoorDoubleInputHandler;
  bool get _showsOpenableNetToggle => _handler is OpenableInputHandler;

  bool get _doorD46Enabled {
    if (_handler is DoorSingleInputHandler) {
      return _handler.d46Enabled;
    }
    if (_handler is DoorDoubleInputHandler) {
      return _handler.d46Enabled;
    }
    return false;
  }

  bool get _doorD52Enabled {
    if (_handler is DoorSingleInputHandler) {
      return _handler.d52Enabled;
    }
    if (_handler is DoorDoubleInputHandler) {
      return _handler.d52Enabled;
    }
    return false;
  }

  void _setDoorD46Enabled(bool enabled) {
    if (!_showsDoorSectionToggles || _doorD46Enabled == enabled) {
      return;
    }

    setState(() {
      if (_handler is DoorSingleInputHandler) {
        _handler.d46Enabled = enabled;
      } else if (_handler is DoorDoubleInputHandler) {
        _handler.d46Enabled = enabled;
      }
      if (!enabled && _selectedSectionCode == 'D46') {
        _selectedSectionCode = null;
      }
    });
  }

  void _setDoorD52Enabled(bool enabled) {
    if (!_showsDoorSectionToggles || _doorD52Enabled == enabled) {
      return;
    }

    setState(() {
      if (_handler is DoorSingleInputHandler) {
        _handler.d52Enabled = enabled;
      } else if (_handler is DoorDoubleInputHandler) {
        _handler.d52Enabled = enabled;
      }
      if (!enabled && _selectedSectionCode == 'D52') {
        _selectedSectionCode = null;
      }
    });
  }

  bool get _openableNetEnabled {
    final WindowInputHandler handler = _handler;
    if (handler is OpenableInputHandler) {
      return handler.netEnabled;
    }
    return false;
  }

  void _setOpenableNetEnabled(bool enabled) {
    final WindowInputHandler handler = _handler;
    if (handler is! OpenableInputHandler || handler.netEnabled == enabled) {
      return;
    }

    setState(() {
      handler.netEnabled = enabled;
      if (!enabled && _selectedSectionCode == 'D29') {
        _selectedSectionCode = null;
      }
    });
  }

  void _restoreHandlerOptionsFromEditingItem(WindowReviewItem? editingItem) {
    if (editingItem == null) {
      return;
    }

    if (_handler is DoorSingleInputHandler) {
      _handler.d46Enabled = editingItem.addBottom;
      _handler.d52Enabled = editingItem.addTee;
    } else if (_handler is DoorDoubleInputHandler) {
      _handler.d46Enabled = editingItem.addBottom;
      _handler.d52Enabled = editingItem.addTee;
    } else if (_handler is OpenableInputHandler) {
      _handler.netEnabled = editingItem.addNet;
    }
  }

  Widget _buildSidebarToggleOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected
          ? AppTheme.violet.withValues(alpha: 0.12)
          : Colors.grey.shade200,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 18,
                color: selected ? AppTheme.violet : AppTheme.deepTeal,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.deepTeal,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _RubberType _rubberTypeFromStored(String? stored) {
    return (stored ?? '').trim().toUpperCase() == 'U'
        ? _RubberType.u
        : _RubberType.fix;
  }

  _LockType _lockTypeFromStored(int? stored) {
    switch (stored) {
      case 2:
        return _LockType.self;
      case 3:
        return _LockType.handal;
      default:
        return _LockType.latch;
    }
  }

  int _lockTypeCode(_LockType value) {
    switch (value) {
      case _LockType.latch:
        return 1;
      case _LockType.self:
        return 2;
      case _LockType.handal:
        return 3;
    }
  }

  void _normalizeLockTypeSelectionForWindow() {
    if (_allowsHandalLockType) {
      return;
    }
    if (_lockType == _LockType.handal) {
      _lockType = _LockType.latch;
    }
  }

  @override
  void initState() {
    super.initState();
    _handler = handlerForWindow(widget.node);
    _restoreHandlerOptionsFromEditingItem(widget.editingItem);
    _rubberType = _rubberTypeFromStored(widget.editingItem?.rubberType);
    if (_isFixOnlyRubberWindow) {
      _rubberType = _RubberType.fix;
    }
    _lockType = _lockTypeFromStored(widget.editingItem?.lockType);
    _normalizeLockTypeSelectionForWindow();
    _unitMode =
        widget.editingItem?.unitMode ??
        (_isFabricationFlow ? UnitMode.feet : UnitMode.inches);
    final int initialCollar = widget.editingItem?.collarIndex ?? 1;
    if (initialCollar < 1) {
      _selectedCollar = 1;
    } else if (initialCollar > _handler.collarCount) {
      _selectedCollar = _handler.collarCount;
    } else {
      _selectedCollar = initialCollar;
    }
    final WindowReviewItem? editingItem = widget.editingItem;
    _heightController.text = editingItem?.heightValue ?? '';
    if (_usesSplitWidthInputs) {
      _widthController.text =
          editingItem?.rightWidthValue ?? editingItem?.widthValue ?? '';
      _leftWidthController.text =
          editingItem?.leftWidthValue ?? editingItem?.widthValue ?? '';
    } else {
      _widthController.text = editingItem?.widthValue ?? '';
    }
    _archController.text = editingItem?.archValue ?? '';
    _syncFabricationSplitControllersFromCombined();
    _descriptionController.text = widget.editingItem?.description ?? '';
    if (widget.editingItem != null) {
      _winNoController.text = widget.editingItem!.winNo.toString();
    }
    _collarPageController = PageController(
      initialPage: _selectedCollar - 1,
      viewportFraction: _collarViewportFraction,
    );
    _collarPageValue = (_selectedCollar - 1).toDouble();
    _collarPageController.addListener(_onCollarScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _heightFocusNode.requestFocus();
      }
    });
  }

  void _onCollarScroll() {
    if (!_collarPageController.hasClients) {
      return;
    }

    final double nextPage = _collarPageController.page ?? 0;
    if (nextPage == _collarPageValue) {
      return;
    }

    setState(() {
      _collarPageValue = nextPage;
    });
  }

  @override
  void dispose() {
    _heightController.dispose();
    _heightInchController.dispose();
    _heightSuterController.dispose();
    _widthController.dispose();
    _widthInchController.dispose();
    _widthSuterController.dispose();
    _leftWidthController.dispose();
    _leftWidthInchController.dispose();
    _leftWidthSuterController.dispose();
    _archController.dispose();
    _descriptionController.dispose();
    _winNoController.dispose();
    _heightFocusNode.dispose();
    _collarPageController.removeListener(_onCollarScroll);
    _collarPageController.dispose();
    super.dispose();
  }

  void _openSettings() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  NumberingMode get _numberingMode => widget.session.numberingMode;

  void _openReview() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewListScreen(session: widget.session),
      ),
    );
  }

  String _combineInchSuterForStorage(String rawInch, String rawSuter) {
    final String inchValue = rawInch.trim();
    final String suterValue = rawSuter.trim();
    if (suterValue.isEmpty) {
      return '$inchValue.0';
    }
    if (!suterValue.contains('.')) {
      return '$inchValue.$suterValue';
    }
    final List<String> parts = suterValue.split('.');
    final String left = parts.first;
    final String right = parts.length > 1 ? parts[1] : '';
    if (right.isEmpty) {
      return '$inchValue.$left';
    }
    return '$inchValue.${left[0]}${right[0]}';
  }

  ({String inch, String suter}) _splitStoredDimensionForInches(String rawValue) {
    final String value = rawValue.trim();
    if (value.isEmpty) {
      return (inch: '', suter: '');
    }
    final List<String> parts = value.split('.');
    final String inchValue = parts.first;
    if (parts.length < 2) {
      return (inch: inchValue, suter: '');
    }
    final String right = parts[1];
    if (right.isEmpty || right == '0') {
      return (inch: inchValue, suter: '');
    }
    if (right.length == 1) {
      return (inch: inchValue, suter: right);
    }
    return (inch: inchValue, suter: '${right[0]}.${right[1]}');
  }

  void _syncFabricationSplitControllersFromCombined() {
    if (!_isFabricationFlow) {
      return;
    }
    final ({String inch, String suter}) height = _splitStoredDimensionForInches(
      _heightController.text,
    );
    final ({String inch, String suter}) width = _splitStoredDimensionForInches(
      _widthController.text,
    );
    _heightInchController.text = height.inch;
    _heightSuterController.text = height.suter;
    _widthInchController.text = width.inch;
    _widthSuterController.text = width.suter;
    if (_usesSplitWidthInputs) {
      final ({String inch, String suter}) left =
          _splitStoredDimensionForInches(_leftWidthController.text);
      _leftWidthInchController.text = left.inch;
      _leftWidthSuterController.text = left.suter;
    }
  }

  void _syncCombinedControllersFromFabricationSplit() {
    if (!_isFabricationFlow) {
      return;
    }
    _heightController.text = _combineInchSuterForStorage(
      _heightInchController.text,
      _heightSuterController.text,
    );
    _widthController.text = _combineInchSuterForStorage(
      _widthInchController.text,
      _widthSuterController.text,
    );
    if (_usesSplitWidthInputs) {
      _leftWidthController.text = _combineInchSuterForStorage(
        _leftWidthInchController.text,
        _leftWidthSuterController.text,
      );
    }
  }

  String? _validateFabricationCmDimension(String rawValue) {
    final String value = rawValue.trim();
    if (value.isEmpty) {
      return 'Required';
    }
    final RegExp pattern = RegExp(r'^\d+(?:\.\d+)?$');
    if (!pattern.hasMatch(value)) {
      return 'Use format cm';
    }
    final double? parsed = double.tryParse(value);
    if (parsed == null || parsed <= 0) {
      return 'Must be greater than zero';
    }
    return null;
  }

  String? _validateFabricationInchPart(String rawValue) {
    final String value = rawValue.trim();
    if (value.isEmpty) {
      return 'Required';
    }
    final int? parsed = int.tryParse(value);
    if (parsed == null) {
      return 'Use whole number';
    }
    if (parsed <= 0) {
      return 'Must be greater than zero';
    }
    return null;
  }

  String? _validateFabricationSuterPart(String rawValue) {
    final String value = rawValue.trim();
    if (value.isEmpty) {
      return null;
    }
    final RegExp pattern = RegExp(r'^\d(?:\.\d)?$');
    if (!pattern.hasMatch(value)) {
      return 'Use 0..7.9 (one decimal)';
    }
    final double? parsed = double.tryParse(value);
    if (parsed == null || parsed < 0 || parsed >= 8) {
      return 'Suter must be less than 8';
    }
    return null;
  }

  String? _validateFabricationSplitDimension({
    required String inchValue,
    required String suterValue,
  }) {
    final String? inchError = _validateFabricationInchPart(inchValue);
    if (inchError != null) {
      return inchError;
    }
    return _validateFabricationSuterPart(suterValue);
  }

  void _showDimensionInfo() {
    final String instructionText;
    if (_isFabricationCmMode) {
      instructionText =
          'CM mode:\n'
          'Enter a single numeric value in cm.\n'
          'Examples: 34 or 34.5';
    } else if (_isFabricationInchesMode) {
      instructionText =
          'Inches mode:\n'
          'Use two fields for each dimension.\n'
          'Inch = whole number (example: 45)\n'
          'Suter = optional decimal (example: 3.5)\n'
          'Suter range is 0 to less than 8,\n'
          'with max one digit after decimal.';
    } else {
      instructionText =
          'eg. inch.suter => 45.7\n'
          'inch = 45\n'
          'suter = 7\n'
          'suter will not be greater than 7.\n'
          '____________________________________\n'
          'eg feet.inchs => 4.9\n'
          '4 = feet\n'
          '9 = inch will not be greater than 11';
    }

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Input Instructions'),
          content: SingleChildScrollView(
            child: Text(instructionText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _onUnitModeChanged(UnitMode mode) {
    if (_unitMode == mode) {
      return;
    }
    final bool wasFabricationInchesMode = _isFabricationInchesMode;
    final bool nextFabricationInchesMode =
        _isFabricationFlow && mode == UnitMode.inches;
    final bool nextFabricationCmMode =
        _isFabricationFlow && mode == UnitMode.feet;

    setState(() {
      if (wasFabricationInchesMode && !nextFabricationInchesMode) {
        _syncCombinedControllersFromFabricationSplit();
      }
      _unitMode = mode;
      if (nextFabricationInchesMode) {
        _syncFabricationSplitControllersFromCombined();
        _heightError = _validateFabricationSplitDimension(
          inchValue: _heightInchController.text,
          suterValue: _heightSuterController.text,
        );
        _widthError = _validateFabricationSplitDimension(
          inchValue: _widthInchController.text,
          suterValue: _widthSuterController.text,
        );
        _leftWidthError = _usesSplitWidthInputs
            ? _validateFabricationSplitDimension(
                inchValue: _leftWidthInchController.text,
                suterValue: _leftWidthSuterController.text,
              )
            : null;
        _archError = _usesArchInput ? _validateDimension(_archController.text) : null;
        return;
      }
      if (nextFabricationCmMode) {
        _heightError = _validateFabricationCmDimension(_heightController.text);
        _widthError = _validateFabricationCmDimension(_widthController.text);
        _leftWidthError = _usesSplitWidthInputs
            ? _validateFabricationCmDimension(_leftWidthController.text)
            : null;
        _archError = _usesArchInput
            ? _validateFabricationCmDimension(_archController.text)
            : null;
        return;
      }
      _heightError = _validateDimension(_heightController.text);
      _widthError = _validateDimension(_widthController.text);
      _leftWidthError = _usesSplitWidthInputs
          ? _validateDimension(_leftWidthController.text)
          : null;
      _archError = _usesArchInput ? _validateDimension(_archController.text) : null;
    });
  }

  String? _validateDimension(String rawValue) {
    final String value = rawValue.trim();
    if (value.isEmpty) {
      return 'Required';
    }

    final RegExp basicPattern = RegExp(r'^\d+(?:\.\d+)?$');
    if (!basicPattern.hasMatch(value)) {
      return 'Use format ${_unitMode.inputHint}';
    }

    final List<String> parts = value.split('.');
    if (parts.length > 2) {
      return 'Invalid value';
    }

    final String rightText = parts.length == 2 ? parts[1] : '0';
    final int? rightPart = int.tryParse(rightText);
    if (rightPart == null) {
      return 'Invalid value';
    }

    if (_unitMode == UnitMode.inches) {
      if (parts.length == 2 && rightText.length != 1) {
        return 'Use one digit after point';
      }
      if (rightPart < 0 || rightPart >= 8) {
        return 'Right side must be 0..7';
      }
      return null;
    }

    if (rightPart < 0 || rightPart >= 12) {
      return 'Right side must be less than 12';
    }
    return null;
  }

  String _normalizeDimensionForStorage(String rawValue) {
    final String value = rawValue.trim();
    if (value.contains('.')) {
      return value;
    }
    return '$value.0';
  }

  String? _validateWinNo(String rawValue) {
    final String value = rawValue.trim();
    if (value.isEmpty) {
      return 'Required';
    }
    final int? parsed = int.tryParse(value);
    if (parsed == null) {
      return 'Use whole number';
    }
    if (parsed <= 0) {
      return 'Must be greater than zero';
    }
    if (!widget.isEditMode && widget.session.existsWinNo(parsed)) {
      return 'Already used';
    }
    return null;
  }

  bool _validateAndShowErrors() {
    String? winNoError;
    if (_numberingMode == NumberingMode.manual) {
      winNoError = _validateWinNo(_winNoController.text);
    }
    final bool useFabricationInchesSplit = _isFabricationInchesMode;
    final String? heightError = useFabricationInchesSplit
        ? _validateFabricationSplitDimension(
            inchValue: _heightInchController.text,
            suterValue: _heightSuterController.text,
          )
        : (_isFabricationCmMode
              ? _validateFabricationCmDimension(_heightController.text)
              : _validateDimension(_heightController.text));
    final String? widthError = useFabricationInchesSplit
        ? _validateFabricationSplitDimension(
            inchValue: _widthInchController.text,
            suterValue: _widthSuterController.text,
          )
        : (_isFabricationCmMode
              ? _validateFabricationCmDimension(_widthController.text)
              : _validateDimension(_widthController.text));
    final String? leftWidthError = _usesSplitWidthInputs
        ? (useFabricationInchesSplit
              ? _validateFabricationSplitDimension(
                  inchValue: _leftWidthInchController.text,
                  suterValue: _leftWidthSuterController.text,
                )
              : (_isFabricationCmMode
                    ? _validateFabricationCmDimension(_leftWidthController.text)
                    : _validateDimension(_leftWidthController.text)))
        : null;
    final String? archError = _usesArchInput
        ? (_isFabricationCmMode
              ? _validateFabricationCmDimension(_archController.text)
              : _validateDimension(_archController.text))
        : null;

    setState(() {
      _winNoError = winNoError;
      _heightError = heightError;
      _widthError = widthError;
      _leftWidthError = leftWidthError;
      _archError = archError;
    });

    return winNoError == null &&
        heightError == null &&
        widthError == null &&
        leftWidthError == null &&
        archError == null;
  }

  String? _normalizedDescription() {
    final String trimmed = _descriptionController.text.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  Future<void> _onSavePressed() async {
    if (!_validateAndShowErrors()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix Window No. / dimension input errors.'),
        ),
      );
      return;
    }

    final int? windowIndex = widget.node.displayIndex;
    final String? windowCode = widget.node.codeName;
    if (windowIndex == null || windowCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Window details are missing for save.')),
      );
      return;
    }

    final String? description = _normalizedDescription();
    if (_isFabricationInchesMode) {
      _syncCombinedControllersFromFabricationSplit();
    }
    final String heightValue = _normalizeDimensionForStorage(
      _heightController.text,
    );
    final String rightWidthValue = _normalizeDimensionForStorage(
      _widthController.text,
    );
    final String? leftWidthValue = _usesSplitWidthInputs
        ? _normalizeDimensionForStorage(_leftWidthController.text)
        : null;
    final String? archValue = _usesArchInput
        ? _normalizeDimensionForStorage(_archController.text)
        : null;
    final int? lockTypeValue = _showsLockTypeSelector
        ? _lockTypeCode(_lockType)
        : null;
    final String? rubberTypeValue =
        _isFabricationFlow && _isLockSupportedWindow
        ? (_rubberType == _RubberType.u ? 'U' : 'F')
        : null;
    final int winNo = widget.isEditMode
        ? widget.editingItem!.winNo
        : (_numberingMode == NumberingMode.manual
              ? int.parse(_winNoController.text.trim())
              : _visibleWinNo);

    if (widget.isEditMode) {
      final WindowReviewItem updated = widget.editingItem!.copyWith(
        winNo: winNo,
        collarIndex: _selectedCollar,
        unitMode: _unitMode,
        heightValue: heightValue,
        widthValue: rightWidthValue,
        rightWidthValue: _usesSplitWidthInputs ? rightWidthValue : null,
        leftWidthValue: leftWidthValue,
        archValue: archValue,
        addBottom: _doorD46Enabled,
        addTee: _doorD52Enabled,
        addNet: _openableNetEnabled,
        lockType: lockTypeValue,
        rubberType: rubberTypeValue,
        description: description,
        clearDescription: description == null,
        clearRightWidthValue: !_usesSplitWidthInputs,
        clearLeftWidthValue: !_usesSplitWidthInputs,
        clearArchValue: !_usesArchInput,
        clearLockType: !_showsLockTypeSelector,
        clearRubberType: !_isFabricationFlow || !_isLockSupportedWindow,
      );
      widget.session.updateItem(updated);
      await _syncProjectSession();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      return;
    }

    try {
      widget.session.addItem(
        winNo: winNo,
        windowLabel: widget.node.label,
        windowCode: windowCode,
        windowIndex: windowIndex,
        collarIndex: _selectedCollar,
        unitMode: _unitMode,
        heightValue: heightValue,
        widthValue: rightWidthValue,
        rightWidthValue: _usesSplitWidthInputs ? rightWidthValue : null,
        leftWidthValue: leftWidthValue,
        archValue: archValue,
        addBottom: _doorD46Enabled,
        addTee: _doorD52Enabled,
        addNet: _openableNetEnabled,
        lockType: lockTypeValue,
        rubberType: rubberTypeValue,
        description: description,
      );
    } on ArgumentError catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Window number already exists.')),
      );
      return;
    }

    await _syncProjectSession();
    if (!mounted) {
      return;
    }

    setState(() {
      _heightController.clear();
      _heightInchController.clear();
      _heightSuterController.clear();
      _widthController.clear();
      _widthInchController.clear();
      _widthSuterController.clear();
      _leftWidthController.clear();
      _leftWidthInchController.clear();
      _leftWidthSuterController.clear();
      _archController.clear();
      _descriptionController.clear();
      if (_numberingMode == NumberingMode.manual) {
        _winNoController.clear();
      }
      _heightError = null;
      _widthError = null;
      _leftWidthError = null;
      _archError = null;
      _winNoError = null;
    });
    _heightFocusNode.requestFocus();
  }

  Future<void> _syncProjectSession() async {
    try {
      await _projectRepository.syncSession(widget.session);
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Widget _buildCollarCard(
    int index, {
    required bool isFocused,
    required double side,
  }) {
    final int collarIndex = index + 1;
    final bool isSelected = _selectedCollar == collarIndex;
    final Color borderColor = isSelected
        ? AppTheme.violet
        : (isFocused ? AppTheme.sky : AppTheme.ice.withValues(alpha: 0.9));

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCollar = collarIndex;
          _selectedSectionCode = null;
        });
        _collarPageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOutCubic,
        );
      },
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: side * _collarCardWidthFactor,
            maxHeight: side,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: -18,
                left: 0,
                right: 0,
                child: Center(child: _CollarArchBadge(number: collarIndex)),
              ),
              AspectRatio(
                aspectRatio: _collarCardWidthFactor,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOutCubic,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 14,
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF8FBFD), Color(0xFFEAF1F5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: borderColor,
                      width: isSelected ? 2.2 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.deepTeal.withValues(alpha: 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Builder(
                    builder: (BuildContext context) {
                      final Widget? overlayWidget = _handler.overlayForCollar(
                        collarIndex,
                        _selectedSectionCode,
                      );
                      return Stack(
                        children: [
                          if (overlayWidget case final Widget overlay) overlay,
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSingleDimensionField({
    required Key fieldKey,
    required TextEditingController controller,
    required String label,
    required String? errorText,
    required TextStyle? numberInputStyle,
    required TextStyle? hintStyle,
    required String hintText,
    required ValueChanged<String> onChanged,
    FocusNode? focusNode,
  }) {
    return TextField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      style: numberInputStyle,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        hintStyle: hintStyle,
        errorText: errorText,
      ),
    );
  }

  Widget _buildFabricationInchesDimensionField({
    required String label,
    required TextEditingController inchController,
    required TextEditingController suterController,
    required String? errorText,
    required TextStyle? numberInputStyle,
    required VoidCallback onChanged,
    FocusNode? inchFocusNode,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: inchController,
            focusNode: inchFocusNode,
            style: numberInputStyle,
            keyboardType: const TextInputType.numberWithOptions(
              signed: false,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              labelText: '$label (Inch)',
              hintText: 'e.g. 45',
              errorText: errorText,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: suterController,
            style: numberInputStyle,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              labelText: 'Suter',
              hintText: 'e.g. 3.5',
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle? hintStyle = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: AppTheme.slate.withValues(alpha: 0.6));
    final TextStyle? numberInputStyle = Theme.of(context).textTheme.titleLarge
        ?.copyWith(
          color: AppTheme.deepTeal,
          fontWeight: FontWeight.w700,
          fontSize: 22,
        );
    final List<ButtonSegment<_RubberType>> rubberSegments =
        _isFixOnlyRubberWindow
        ? const <ButtonSegment<_RubberType>>[
            ButtonSegment<_RubberType>(
              value: _RubberType.fix,
              label: Text('Fix', key: Key('rubber_fix_option')),
            ),
          ]
        : const <ButtonSegment<_RubberType>>[
            ButtonSegment<_RubberType>(
              value: _RubberType.fix,
              label: Text('Fix', key: Key('rubber_fix_option')),
            ),
            ButtonSegment<_RubberType>(
              value: _RubberType.u,
              label: Text('U', key: Key('rubber_u_option')),
            ),
          ];
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: Drawer(
        key: const Key('settings_drawer'),
        width: _handler.showDrawerForCollar(_selectedCollar)
            ? MediaQuery.sizeOf(context).width * 0.38
            : null,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Windows settings',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.deepTeal,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                if (_showsDoorSectionToggles) ...[
                  Text(
                    'D46 Option',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.deepTeal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSidebarToggleOption(
                    label: 'D46 Off',
                    selected: !_doorD46Enabled,
                    onTap: () => _setDoorD46Enabled(false),
                  ),
                  const SizedBox(height: 6),
                  _buildSidebarToggleOption(
                    label: 'D46 On',
                    selected: _doorD46Enabled,
                    onTap: () => _setDoorD46Enabled(true),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'D52 Option',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.deepTeal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSidebarToggleOption(
                    label: 'D52 Off',
                    selected: !_doorD52Enabled,
                    onTap: () => _setDoorD52Enabled(false),
                  ),
                  const SizedBox(height: 6),
                  _buildSidebarToggleOption(
                    label: 'D52 On',
                    selected: _doorD52Enabled,
                    onTap: () => _setDoorD52Enabled(true),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_showsOpenableNetToggle) ...[
                  Text(
                    'Net Option',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.deepTeal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSidebarToggleOption(
                    label: 'Net Off',
                    selected: !_openableNetEnabled,
                    onTap: () => _setOpenableNetEnabled(false),
                  ),
                  const SizedBox(height: 6),
                  _buildSidebarToggleOption(
                    label: 'Net On',
                    selected: _openableNetEnabled,
                    onTap: () => _setOpenableNetEnabled(true),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_handler.showDrawerForCollar(_selectedCollar)) ...[
                  Text(
                    'Sections',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.deepTeal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _handler
                          .sectionsForCollar(_selectedCollar)
                          .length,
                      separatorBuilder: (BuildContext context, int index) =>
                          const SizedBox(height: 6),
                      itemBuilder: (BuildContext context, int index) {
                        final String code = _handler.sectionsForCollar(
                          _selectedCollar,
                        )[index];
                        final bool isSelected = code == _selectedSectionCode;
                        return Material(
                          color: isSelected
                              ? AppTheme.violet.withValues(alpha: 0.12)
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              setState(() {
                                _selectedSectionCode = isSelected ? null : code;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    code,
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: AppTheme.deepTeal,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const Spacer(),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle,
                                      size: 18,
                                      color: AppTheme.violet,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_showsLockTypeSelector) ...[
                  Text(
                    'Lock Type',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.deepTeal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    key: const Key('lock_type_segmented_control'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSidebarToggleOption(
                        label: 'Latch',
                        selected: _lockType == _LockType.latch,
                        onTap: () {
                          setState(() {
                            _lockType = _LockType.latch;
                          });
                        },
                      ),
                      const SizedBox(height: 6),
                      _buildSidebarToggleOption(
                        label: 'Self',
                        selected: _lockType == _LockType.self,
                        onTap: () {
                          setState(() {
                            _lockType = _LockType.self;
                          });
                        },
                      ),
                      if (_allowsHandalLockType) ...[
                        const SizedBox(height: 6),
                        _buildSidebarToggleOption(
                          label: 'Handal',
                          selected: _lockType == _LockType.handal,
                          onTap: () {
                            setState(() {
                              _lockType = _LockType.handal;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  'Rubber Type',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.deepTeal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<_RubberType>(
                  key: const Key('rubber_type_segmented_control'),
                  segments: rubberSegments,
                  selected: <_RubberType>{_rubberType},
                  showSelectedIcon: false,
                  onSelectionChanged: (Set<_RubberType> selection) {
                    if (selection.isEmpty) {
                      return;
                    }
                    setState(() {
                      _rubberType = _isFixOnlyRubberWindow
                          ? _RubberType.fix
                          : selection.first;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Units',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.deepTeal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<UnitMode>(
                  key: const Key('unit_segmented_control'),
                  segments: <ButtonSegment<UnitMode>>[
                    ButtonSegment<UnitMode>(
                      value: UnitMode.feet,
                      label: Text(
                        _isFabricationFlow ? 'cm' : 'Feet',
                        key: const Key('unit_feet_radio'),
                      ),
                    ),
                    const ButtonSegment<UnitMode>(
                      value: UnitMode.inches,
                      label: Text('Inches', key: Key('unit_inches_radio')),
                    ),
                  ],
                  selected: <UnitMode>{_unitMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (Set<UnitMode> selection) {
                    if (selection.isNotEmpty) {
                      _onUnitModeChanged(selection.first);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.mist, AppTheme.ice],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppTheme.deepTeal,
                    ),
                    Expanded(
                      child: Text(
                        widget.session.isFabrication
                            ? 'Fabrication'
                            : 'Estimation',
                        key: const Key('input_estimation_heading'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(fontSize: 30, height: 1),
                      ),
                    ),
                    IconButton(
                      key: const Key('open_review_button'),
                      onPressed: _openReview,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      color: AppTheme.deepTeal,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: [
                    const SizedBox(width: 48),
                    Expanded(
                      child: Text(
                        widget.node.label,
                        key: const Key('input_window_label'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.deepTeal,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('open_settings_drawer_button'),
                      onPressed: _openSettings,
                      icon: const Icon(Icons.more_horiz_rounded),
                      color: AppTheme.deepTeal,
                    ),
                  ],
                ),
              ),
              Container(
                key: const Key('current_win_no_label'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.deepTeal,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  'winNo: ${_numberingMode == NumberingMode.manual ? (_winNoController.text.trim().isEmpty ? '--' : _winNoController.text.trim()) : _visibleWinNo}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: _collarCardSize + 30,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double availableWidth = constraints.maxWidth;
                    final double side = math.min(
                      _collarCardSize,
                      availableWidth * _collarViewportFraction * 0.9,
                    );
                    return PageView.builder(
                      key: const Key('collar_page_view'),
                      controller: _collarPageController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _handler.collarCount,
                      onPageChanged: (int index) {
                        setState(() {
                          _selectedCollar = index + 1;
                        });
                      },
                      itemBuilder: (BuildContext context, int index) {
                        return _buildCollarCard(
                          index,
                          isFocused: true,
                          side: side,
                        );
                      },
                    );
                  },
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_numberingMode == NumberingMode.manual) ...[
                        TextField(
                          key: const Key('input_win_no_field'),
                          controller: _winNoController,
                          enabled: !widget.isEditMode,
                          keyboardType: const TextInputType.numberWithOptions(
                            signed: false,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) {
                            if (_winNoError != null) {
                              setState(() {
                                _winNoError = _validateWinNo(
                                  _winNoController.text,
                                );
                              });
                            } else {
                              setState(() {}); // refresh winNo badge display
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Window Number',
                            errorText: _winNoError,
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      Row(
                        children: [
                          Text(
                            'Dimensions',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: AppTheme.deepTeal,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _showDimensionInfo,
                            icon: const Icon(Icons.info_outline_rounded),
                            color: AppTheme.deepTeal,
                          ),
                        ],
                      ),
                      if (_isFabricationInchesMode)
                        _buildFabricationInchesDimensionField(
                          label: 'Height',
                          inchController: _heightInchController,
                          suterController: _heightSuterController,
                          errorText: _heightError,
                          numberInputStyle: numberInputStyle,
                          inchFocusNode: _heightFocusNode,
                          onChanged: () {
                            setState(() {
                              _heightController.text = _combineInchSuterForStorage(
                                _heightInchController.text,
                                _heightSuterController.text,
                              );
                              _heightError = _validateFabricationSplitDimension(
                                inchValue: _heightInchController.text,
                                suterValue: _heightSuterController.text,
                              );
                            });
                          },
                        )
                      else
                        _buildSingleDimensionField(
                          fieldKey: const Key('input_height_field'),
                          controller: _heightController,
                          focusNode: _heightFocusNode,
                          label: 'Height',
                          errorText: _heightError,
                          numberInputStyle: numberInputStyle,
                          hintStyle: hintStyle,
                          hintText: _isFabricationCmMode ? 'cm' : _unitMode.inputHint,
                          onChanged: (_) {
                            if (_heightError != null) {
                              setState(() {
                                _heightError = _isFabricationCmMode
                                    ? _validateFabricationCmDimension(
                                        _heightController.text,
                                      )
                                    : _validateDimension(_heightController.text);
                              });
                            }
                          },
                        ),
                      const SizedBox(height: 12),
                      if (_isFabricationInchesMode)
                        _buildFabricationInchesDimensionField(
                          label: _usesSplitWidthInputs ? 'Right Width' : 'Width',
                          inchController: _widthInchController,
                          suterController: _widthSuterController,
                          errorText: _widthError,
                          numberInputStyle: numberInputStyle,
                          onChanged: () {
                            setState(() {
                              _widthController.text = _combineInchSuterForStorage(
                                _widthInchController.text,
                                _widthSuterController.text,
                              );
                              _widthError = _validateFabricationSplitDimension(
                                inchValue: _widthInchController.text,
                                suterValue: _widthSuterController.text,
                              );
                            });
                          },
                        )
                      else
                        _buildSingleDimensionField(
                          fieldKey: const Key('input_width_field'),
                          controller: _widthController,
                          label: _usesSplitWidthInputs ? 'Right Width' : 'Width',
                          errorText: _widthError,
                          numberInputStyle: numberInputStyle,
                          hintStyle: hintStyle,
                          hintText: _isFabricationCmMode ? 'cm' : _unitMode.inputHint,
                          onChanged: (_) {
                            if (_widthError != null) {
                              setState(() {
                                _widthError = _isFabricationCmMode
                                    ? _validateFabricationCmDimension(
                                        _widthController.text,
                                      )
                                    : _validateDimension(_widthController.text);
                              });
                            }
                          },
                        ),
                      if (_usesSplitWidthInputs) ...[
                        const SizedBox(height: 12),
                        if (_isFabricationInchesMode)
                          _buildFabricationInchesDimensionField(
                            label: 'Left Width',
                            inchController: _leftWidthInchController,
                            suterController: _leftWidthSuterController,
                            errorText: _leftWidthError,
                            numberInputStyle: numberInputStyle,
                            onChanged: () {
                              setState(() {
                                _leftWidthController.text =
                                    _combineInchSuterForStorage(
                                      _leftWidthInchController.text,
                                      _leftWidthSuterController.text,
                                    );
                                _leftWidthError =
                                    _validateFabricationSplitDimension(
                                      inchValue: _leftWidthInchController.text,
                                      suterValue: _leftWidthSuterController.text,
                                    );
                              });
                            },
                          )
                        else
                          _buildSingleDimensionField(
                            fieldKey: const Key('input_left_width_field'),
                            controller: _leftWidthController,
                            label: 'Left Width',
                            errorText: _leftWidthError,
                            numberInputStyle: numberInputStyle,
                            hintStyle: hintStyle,
                            hintText: _isFabricationCmMode ? 'cm' : _unitMode.inputHint,
                            onChanged: (_) {
                              if (_leftWidthError != null) {
                                setState(() {
                                  _leftWidthError = _isFabricationCmMode
                                      ? _validateFabricationCmDimension(
                                          _leftWidthController.text,
                                        )
                                      : _validateDimension(
                                          _leftWidthController.text,
                                        );
                                });
                              }
                            },
                          ),
                      ],
                      if (_usesArchInput) ...[
                        const SizedBox(height: 12),
                        _buildSingleDimensionField(
                          fieldKey: const Key('input_arch_field'),
                          controller: _archController,
                          label: 'Arch',
                          errorText: _archError,
                          numberInputStyle: numberInputStyle,
                          hintStyle: hintStyle,
                          hintText: _isFabricationCmMode ? 'cm' : _unitMode.inputHint,
                          onChanged: (_) {
                            if (_archError != null) {
                              setState(() {
                                _archError = _isFabricationCmMode
                                    ? _validateFabricationCmDimension(
                                        _archController.text,
                                      )
                                    : _validateDimension(_archController.text);
                              });
                            }
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('input_description_field'),
                        controller: _descriptionController,
                        maxLength: _maxDescriptionLength,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Description (Optional)',
                          hintText: 'e.g. bath room window',
                          hintStyle: hintStyle,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          key: const Key('input_save_button'),
                          onPressed: _onSavePressed,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(widget.isEditMode ? 'Update' : 'Save'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollarArchBadge extends StatelessWidget {
  final int number;

  const _CollarArchBadge({required this.number});

  @override
  Widget build(BuildContext context) {
    const double w = 72;
    const double h = 30;
    final Color color = AppTheme.deepTeal;

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(w, h),
            painter: _ArchPainter(color: color),
          ),
          Text(
            '$number',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchPainter extends CustomPainter {
  final Color color;

  _ArchPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.55)
      ..quadraticBezierTo(size.width / 2, 0, size.width, size.height * 0.55)
      ..lineTo(size.width, size.height)
      ..close();

    final Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArchPainter oldDelegate) =>
      oldDelegate.color != color;
}
