import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/window_input_preferences_store.dart';
import 'window_input_handler.dart';
import '../../data/project_repository.dart';
import '../../models/window_review_item.dart';
import '../../models/window_type.dart';
import '../../state/estimate_session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../flow_nav/models/flow_step.dart';
import '../../../flow_nav/presentation/flow_progress_bar.dart';
import '../../../tutorial/tutorial_controller.dart';
import '../../../tutorial/tutorial_overlay.dart';
import '../../../tutorial/tutorial_step.dart';
import '../../../tutorial/tutorial_target.dart';
import '../../../../shared/widgets/option_switch.dart';
import '../../../../shared/widgets/suter_wheel.dart';
import '../../../settings/state/app_settings.dart';
import '../../../settings/state/numbering_mode.dart';
import '../../../settings/state/size_input_mode.dart';
import '../review_list_screen.dart';
import '../../models/window_material.dart';
import '../../widgets/window_material_picker.dart';
import '../../../formulas/data/formula_book.dart';
import '../../../formulas/data/formula_catalogue.dart';
import '../../../formulas/data/formula_catalogue_asset.dart';
import '../../../formulas/data/formula_overrides_store.dart';
import '../../../formulas/model/formula_overrides.dart';
import '../../../formulas/model/formula_window_key.dart';
import '../../../formulas/presentation/formula_editor_screen.dart';

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
  final WindowInputPreferencesStore _preferencesStore =
      WindowInputPreferencesStore();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _heightInchController = TextEditingController();
  final TextEditingController _heightSuterController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _widthInchController = TextEditingController();
  final TextEditingController _widthSuterController = TextEditingController();
  final TextEditingController _leftWidthController = TextEditingController();
  final TextEditingController _leftWidthInchController =
      TextEditingController();
  final TextEditingController _leftWidthSuterController =
      TextEditingController();
  final TextEditingController _archController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _winNoController = TextEditingController();
  final FocusNode _winNoFocusNode = FocusNode();
  final FocusNode _heightFocusNode = FocusNode();
  final FocusNode _widthFocusNode = FocusNode();
  final FocusNode _leftWidthFocusNode = FocusNode();
  final FocusNode _archFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();

  /// The sub-part boxes — inch in feet mode, suter in inches mode.
  ///
  /// They only take focus when sizes are typed rather than picked on the
  /// wheel, which is now the default. Without these the keyboard's next jumped
  /// straight from Height to Width, skipping the half of the measurement the
  /// user was about to type.
  final FocusNode _heightSubFocusNode = FocusNode();
  final FocusNode _widthSubFocusNode = FocusNode();
  final FocusNode _leftWidthSubFocusNode = FocusNode();

  final FocusNode _quantityFocusNode = FocusNode();

  /// The aluminium this window is cut from.
  ///
  /// Editing an existing window shows that window's own stock; a new one
  /// starts on whatever the last window was entered in, because a job is
  /// usually mostly one stock with a few exceptions.
  late WindowMaterial _material;

  final GlobalKey _winNoFieldKey = GlobalKey(debugLabel: 'winNoField');
  final GlobalKey _heightFieldKey = GlobalKey(debugLabel: 'heightField');
  final GlobalKey _widthFieldKey = GlobalKey(debugLabel: 'widthField');
  final GlobalKey _leftWidthFieldKey = GlobalKey(debugLabel: 'leftWidthField');
  final GlobalKey _archFieldKey = GlobalKey(debugLabel: 'archField');
  final GlobalKey _descriptionFieldKey = GlobalKey(
    debugLabel: 'descriptionField',
  );

  late final PageController _collarPageController;
  double _collarPageValue = 0;
  late UnitMode _unitMode;
  late _RubberType _rubberType;
  late _LockType _lockType;
  late int _selectedCollar;
  String? _selectedSectionCode;

  /// Door frame ke peeche wala collar: 1.7cm (purana) ya 2cm (naya).
  double _backCollarCm = kBackCollarDefaultCm;
  String? _winNoError;
  String? _heightError;
  String? _widthError;
  String? _leftWidthError;
  String? _archError;
  late final WindowInputHandler _handler;
  Future<void> _pendingProjectSync = Future<void>.value();

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

  /// The dimension inputs render as a "typed whole part + tape wheel" split
  /// whenever the unit has a sub-part that is picked on a wheel: inches
  /// (inch typed + suter wheel, both flows) and estimation feet (feet typed +
  /// inch wheel). CM and the fabrication "feet" slot (which is really cm) stay
  /// single typed fields.
  bool get _usesInchSuterSplit => _unitMode == UnitMode.inches;
  bool get _usesFeetInchSplit =>
      !_isFabricationFlow && _unitMode == UnitMode.feet;
  bool get _usesSplitInput => _usesInchSuterSplit || _usesFeetInchSplit;

  /// True when the active input is in centimetres — either fabrication's
  /// existing cm mode (which reuses the `feet` slot) or estimation's real
  /// [UnitMode.cm]. Both render a single numeric cm field and validate the
  /// same way.
  bool get _isCmMode =>
      _isFabricationCmMode || (!_isFabricationFlow && _unitMode == UnitMode.cm);

  /// Estimation-only: cm input is a quotation convenience. On save it is
  /// converted to inch + sutter so the rest of the estimation pipeline (which
  /// only understands inch/feet) processes it unchanged. Cutting is never
  /// performed from estimation, so snapping to the nearest 1/8" (real
  /// inch-tape resolution) is exactly right here.
  bool get _isEstimationCmMode =>
      !_isFabricationFlow && _unitMode == UnitMode.cm;
  bool get _showsDoorSectionToggles =>
      _handler is DoorSingleInputHandler || _handler is DoorDoubleInputHandler;
  bool get _showsOpenableNetToggle => _handler is OpenableInputHandler;

  /// Back collar sirf fabrication ke door formula par asar karta ha, is liye
  /// button bhi sirf fabrication flow ke doors mein dikhta ha.
  bool get _showsBackCollarOption =>
      _showsDoorSectionToggles && _isFabricationFlow;

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
    _persistSidebarSelections();
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
    _persistSidebarSelections();
  }

  void _setBackCollarCm(double value) {
    if (!_showsBackCollarOption || _backCollarCm == value) {
      return;
    }

    setState(() {
      _backCollarCm = value;
    });
    _persistSidebarSelections();
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
    _persistSidebarSelections();
  }

  String? _normalizedSelectedSectionCode(String? sectionCode, int collarIndex) {
    final String? normalized = sectionCode == null || sectionCode.trim().isEmpty
        ? null
        : sectionCode.trim();
    if (normalized == null) {
      return null;
    }
    final List<String> availableSections = _handler.sectionsForCollar(
      collarIndex,
    );
    return availableSections.contains(normalized) ? normalized : null;
  }

  /// Which set of formulas this window, as it is currently set up, is cut by.
  ///
  /// Null when the catalogue has nothing for it -- a collar type this window
  /// type does not offer, or a window whose formulas have not been brought
  /// across yet. The button is simply not shown then, rather than opening a
  /// screen that would have to apologise.
  FormulaWindowKey? _formulaKeyFor(FormulaCatalogue catalogue) {
    final String context = _isFabricationFlow ? 'fabrication' : 'estimation';
    if (!FormulaWindowKey.knows(_windowCode)) return null;

    // The dimensions come from the catalogue itself, so a window that gains or
    // loses a setting needs no change here.
    final FormulaWindowKey? probe = FormulaWindowKey.of(
      context: context,
      appWindowCode: _windowCode,
      dimensions: const <String>{},
      collarIndex: _selectedCollar,
    );
    if (probe == null) return null;

    return FormulaWindowKey.of(
      context: context,
      appWindowCode: _windowCode,
      dimensions: catalogue.dimensionsFor(probe.windowKey),
      collarIndex: _selectedCollar,
      lockType: _showsLockTypeSelector ? _lockTypeCode(_lockType) : null,
      rubberType: _rubberType == _RubberType.u ? 'U' : 'F',
      addBottom: _doorD46Enabled,
      addTee: _doorD52Enabled,
      addNet: _openableNetEnabled,
      backCollarCm: _backCollarCm,
    );
  }

  /// How this window is set up, in the words the fabricator chose it by.
  String get _formulaConfigSummary {
    final List<String> parts = <String>['Collar $_selectedCollar'];
    if (_showsLockTypeSelector) {
      parts.add(_lockTypeLabel(_lockType));
    }
    if (_isFabricationFlow) {
      parts.add(_rubberType == _RubberType.u ? 'U rubber' : 'F rubber');
    }
    if (_showsDoorSectionToggles) {
      if (_doorD46Enabled) parts.add('D46');
      if (_doorD52Enabled) parts.add('D52');
    }
    if (_showsOpenableNetToggle && _openableNetEnabled) {
      parts.add('Net');
    }
    if (_showsBackCollarOption) {
      parts.add('${_backCollarCm}cm collar');
    }
    return parts.join(' · ');
  }

  Future<void> _openFormulaEditor() async {
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final FormulaCatalogue catalogue;
    final FormulaOverrides overrides;
    try {
      catalogue = await FormulaCatalogueAsset.load();
      overrides = await const FormulaOverridesStore().load();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the formulas just now.')),
      );
      return;
    }
    if (!mounted) return;

    final FormulaWindowKey? key = _formulaKeyFor(catalogue);
    if (key == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('This window does not have editable formulas yet.'),
        ),
      );
      return;
    }

    // The drawer is over the screen it belongs to; leaving it open behind a
    // full screen means coming back to a sidebar nobody asked for.
    navigator.pop();

    await navigator.push(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => FormulaEditorScreen(
          windowKey: key,
          windowTitle: widget.node.label,
          configSummary: _formulaConfigSummary,
          book: FormulaBook(catalogue, overrides),
          onSaved: (FormulaOverrides edited) =>
              const FormulaOverridesStore().save(edited),
        ),
      ),
    );
  }

  WindowInputSidebarPreferences _currentSidebarPreferences() {
    return WindowInputSidebarPreferences(
      selectedCollar: _selectedCollar,
      selectedSectionCode: _selectedSectionCode,
      lockType: _showsLockTypeSelector ? _lockTypeCode(_lockType) : null,
      rubberType: _isFabricationFlow
          ? (_rubberType == _RubberType.u ? 'U' : 'F')
          : null,
      addBottom: _showsDoorSectionToggles ? _doorD46Enabled : null,
      addTee: _showsDoorSectionToggles ? _doorD52Enabled : null,
      addNet: _showsOpenableNetToggle ? _openableNetEnabled : null,
      backCollarCm: _showsBackCollarOption ? _backCollarCm : null,
    );
  }

  void _persistSidebarSelections() {
    unawaited(
      _preferencesStore.persistUnitMode(widget.session.flow, _unitMode),
    );
    if (_windowCode.trim().isEmpty) {
      return;
    }
    unawaited(
      _preferencesStore.persistSidebar(
        flow: widget.session.flow,
        windowCode: _windowCode,
        preferencesState: _currentSidebarPreferences(),
      ),
    );
  }

  Future<void> _restorePersistedSidebarState() async {
    if (widget.isEditMode) {
      return;
    }

    final UnitMode? storedUnitMode = await _preferencesStore.restoreUnitMode(
      widget.session.flow,
    );
    final WindowInputSidebarPreferences? preferencesState =
        await _preferencesStore.restoreSidebar(
          flow: widget.session.flow,
          windowCode: _windowCode,
        );

    if (!mounted) {
      return;
    }

    setState(() {
      if (storedUnitMode != null) {
        _unitMode = storedUnitMode;
      }
      if (preferencesState != null) {
        final int? storedCollar = preferencesState.selectedCollar;
        if (storedCollar != null) {
          _selectedCollar = storedCollar.clamp(1, _handler.collarCount);
        }
        if (_showsDoorSectionToggles) {
          if (_handler is DoorSingleInputHandler) {
            if (preferencesState.addBottom != null) {
              _handler.d46Enabled = preferencesState.addBottom!;
            }
            if (preferencesState.addTee != null) {
              _handler.d52Enabled = preferencesState.addTee!;
            }
          } else if (_handler is DoorDoubleInputHandler) {
            if (preferencesState.addBottom != null) {
              _handler.d46Enabled = preferencesState.addBottom!;
            }
            if (preferencesState.addTee != null) {
              _handler.d52Enabled = preferencesState.addTee!;
            }
          }
        }
        final WindowInputHandler activeHandler = _handler;
        if (_showsOpenableNetToggle &&
            preferencesState.addNet != null &&
            activeHandler is OpenableInputHandler) {
          activeHandler.netEnabled = preferencesState.addNet!;
        }
        if (_showsBackCollarOption && preferencesState.backCollarCm != null) {
          _backCollarCm = preferencesState.backCollarCm!;
        }
        if (_showsLockTypeSelector && preferencesState.lockType != null) {
          _lockType = _lockTypeFromStored(preferencesState.lockType);
        }
        if (_isFabricationFlow && preferencesState.rubberType != null) {
          _rubberType = _rubberTypeFromStored(preferencesState.rubberType);
        }
        _selectedSectionCode = _normalizedSelectedSectionCode(
          preferencesState.selectedSectionCode,
          _selectedCollar,
        );
      }
      if (_isFixOnlyRubberWindow) {
        _rubberType = _RubberType.fix;
      }
      _normalizeLockTypeSelectionForWindow();
      if (!_doorD46Enabled && _selectedSectionCode == 'D46') {
        _selectedSectionCode = null;
      }
      if (!_doorD52Enabled && _selectedSectionCode == 'D52') {
        _selectedSectionCode = null;
      }
      if (!_openableNetEnabled && _selectedSectionCode == 'D29') {
        _selectedSectionCode = null;
      }
      if (_usesSplitInput) {
        _syncSplitControllersFromCombined();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_collarPageController.hasClients) {
        return;
      }
      _collarPageController.jumpToPage(_selectedCollar - 1);
    });
  }

  void _restoreHandlerOptionsFromEditingItem(WindowReviewItem? editingItem) {
    if (editingItem == null) {
      return;
    }

    _backCollarCm = editingItem.backCollarCm;

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

  /// The lock as a fabricator names it, for saying which window a set of
  /// formulas belongs to.
  String _lockTypeLabel(_LockType value) {
    switch (value) {
      case _LockType.latch:
        return 'Latch';
      case _LockType.self:
        return 'Self';
      case _LockType.handal:
        return 'Handal';
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
    // orElse: an old window may carry none of its own, and the picker must
    // open on something the user can see.
    _material =
        widget.editingItem?.material.orElse(WindowMaterial.initial) ??
        widget.session.materialForNextWindow;
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
    _syncSplitControllersFromCombined();
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
    unawaited(_restorePersistedSidebarState());
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

  List<({FocusNode node, GlobalKey key})> get _focusTargets {
    final List<({FocusNode node, GlobalKey key})> targets =
        <({FocusNode node, GlobalKey key})>[];
    if (_numberingMode == NumberingMode.manual && !widget.isEditMode) {
      targets.add((node: _winNoFocusNode, key: _winNoFieldKey));
    }
    // A size is two boxes — whole and sub-part — and the order below is the
    // order a person reads a tape: height and its suter, then width and its
    // suter. The sub-part joins the chain only when it is a typing box; on the
    // wheel there is nothing to focus, and "next" hops the typed fields alone.
    targets.add((node: _heightFocusNode, key: _heightFieldKey));
    if (_usesKeypadSizeInput) {
      targets.add((node: _heightSubFocusNode, key: _heightFieldKey));
    }
    targets.add((node: _widthFocusNode, key: _widthFieldKey));
    if (_usesKeypadSizeInput) {
      targets.add((node: _widthSubFocusNode, key: _widthFieldKey));
    }
    if (_usesSplitWidthInputs) {
      targets.add((node: _leftWidthFocusNode, key: _leftWidthFieldKey));
      if (_usesKeypadSizeInput) {
        targets.add((node: _leftWidthSubFocusNode, key: _leftWidthFieldKey));
      }
    }
    if (_usesArchInput) {
      targets.add((node: _archFocusNode, key: _archFieldKey));
    }
    // Quantity before description: it is part of the measurement, and a
    // description is the last thing anyone types — if they type one at all.
    //
    // Only when it is on screen. Editing one saved window has no quantity
    // field, and a chain that steps onto a box that is not there loses the
    // cursor entirely.
    if (!widget.isEditMode) {
      targets.add((node: _quantityFocusNode, key: _descriptionFieldKey));
    }
    targets.add((node: _descriptionFocusNode, key: _descriptionFieldKey));

    return targets;
  }

  TextInputAction _textInputActionForField(FocusNode node) {
    final List<({FocusNode node, GlobalKey key})> targets = _focusTargets;
    if (targets.isEmpty) {
      return TextInputAction.done;
    }
    return identical(targets.last.node, node)
        ? TextInputAction.done
        : TextInputAction.next;
  }

  void _focusFirstField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final List<({FocusNode node, GlobalKey key})> targets = _focusTargets;
      if (targets.isEmpty) {
        return;
      }
      Future<void>.delayed(const Duration(milliseconds: 80), () {
        if (!mounted) {
          return;
        }
        targets.first.node.requestFocus();
      });
    });
  }

  bool _focusNextField(FocusNode currentNode) {
    final List<({FocusNode node, GlobalKey key})> targets = _focusTargets;
    if (targets.isEmpty) {
      return false;
    }
    final int currentIndex = targets.indexWhere(
      (({FocusNode node, GlobalKey key}) target) =>
          identical(target.node, currentNode),
    );
    if (currentIndex == -1 || currentIndex == targets.length - 1) {
      // The end of the chain is not a wrap. Saving is what returns the cursor
      // to the first box -- see the reset at the end of _onSavePressed -- and
      // it keeps the window that was just typed. Wrapping here instead would
      // put the cursor back at the top and quietly throw that window away.
      return false;
    }
    final ({FocusNode node, GlobalKey key}) nextTarget =
        targets[currentIndex + 1];
    nextTarget.node.requestFocus();
    return true;
  }

  void _submitFromField(FocusNode currentNode) {
    final bool movedToNextField = _focusNextField(currentNode);
    if (movedToNextField) {
      return;
    }
    _onSavePressed();
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
    _quantityController.dispose();
    _winNoController.dispose();
    _winNoFocusNode.dispose();
    _heightFocusNode.dispose();
    _widthFocusNode.dispose();
    _leftWidthFocusNode.dispose();
    _archFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _heightSubFocusNode.dispose();
    _widthSubFocusNode.dispose();
    _leftWidthSubFocusNode.dispose();
    _quantityFocusNode.dispose();
    _collarPageController.removeListener(_onCollarScroll);
    _collarPageController.dispose();
    super.dispose();
  }

  void _openSettings() {
    // Opening the sidebar is itself a step of the tour.
    TutorialController.instance.advanceAfterTap();
    _scaffoldKey.currentState?.openEndDrawer();
  }

  NumberingMode get _numberingMode => widget.session.numberingMode;

  void _openReview() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: FlowSteps.review.id),
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

  ({String inch, String suter}) _splitStoredDimensionForInches(
    String rawValue,
  ) {
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

  // For the feet+inch split, the "inch" slot of the shared split controllers
  // holds the whole feet and the "suter" slot holds the whole inch (0..11)
  // picked on the wheel. Storage stays in the shop's `feet.inch` notation.
  String _combineFeetInchForStorage(String rawFeet, String rawInch) {
    final String feet = rawFeet.trim();
    if (feet.isEmpty) {
      return '';
    }
    final int inch = int.tryParse(rawInch.trim()) ?? 0;
    return '$feet.$inch';
  }

  ({String inch, String suter}) _splitStoredDimensionForFeet(String stored) {
    final String value = stored.trim();
    if (value.isEmpty) {
      return (inch: '', suter: '');
    }
    final List<String> parts = value.split('.');
    final String feet = parts.first;
    if (parts.length < 2 || parts[1].trim().isEmpty) {
      return (inch: feet, suter: '');
    }
    final int inch = int.tryParse(parts[1].trim()) ?? 0;
    return (
      inch: feet,
      suter: InchWheel.snap(inch.toDouble()).round().toString(),
    );
  }

  /// Mode-aware split of a stored dimension into (whole, wheel) parts.
  ({String inch, String suter}) _splitStoredForSplit(String stored) {
    return _usesFeetInchSplit
        ? _splitStoredDimensionForFeet(stored)
        : _splitStoredDimensionForInches(stored);
  }

  /// Mode-aware combine of the split controllers back into stored notation.
  String _combineSplitForStorage(String whole, String wheel) {
    return _usesFeetInchSplit
        ? _combineFeetInchForStorage(whole, wheel)
        : _combineInchSuterForStorage(whole, wheel);
  }

  /// Feet-mode validation reuses the single-field feet rules on the combined
  /// value, so behaviour matches exactly what typing `feet.inch` used to do.
  String? _validateFeetSplitDimension(String feetValue, String inchValue) {
    final String combined = _combineFeetInchForStorage(feetValue, inchValue);
    if (combined.isEmpty) {
      return 'Required';
    }
    return _validateDimension(combined);
  }

  String? _validateSplitDimension(String whole, String wheel) {
    return _usesFeetInchSplit
        ? _validateFeetSplitDimension(whole, wheel)
        : _validateFabricationSplitDimension(
            inchValue: whole,
            suterValue: wheel,
          );
  }

  void _syncSplitControllersFromCombined() {
    if (!_usesSplitInput) {
      return;
    }
    final ({String inch, String suter}) height = _splitStoredForSplit(
      _heightController.text,
    );
    final ({String inch, String suter}) width = _splitStoredForSplit(
      _widthController.text,
    );
    _heightInchController.text = height.inch;
    _heightSuterController.text = height.suter;
    _widthInchController.text = width.inch;
    _widthSuterController.text = width.suter;
    if (_usesSplitWidthInputs) {
      final ({String inch, String suter}) left = _splitStoredForSplit(
        _leftWidthController.text,
      );
      _leftWidthInchController.text = left.inch;
      _leftWidthSuterController.text = left.suter;
    }
  }

  void _syncCombinedControllersFromSplit() {
    if (!_usesSplitInput) {
      return;
    }
    _heightController.text = _combineSplitForStorage(
      _heightInchController.text,
      _heightSuterController.text,
    );
    _widthController.text = _combineSplitForStorage(
      _widthInchController.text,
      _widthSuterController.text,
    );
    if (_usesSplitWidthInputs) {
      _leftWidthController.text = _combineSplitForStorage(
        _leftWidthInchController.text,
        _leftWidthSuterController.text,
      );
    }
  }

  String? _validateCmDimension(String rawValue) {
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
    if (_isCmMode) {
      instructionText =
          'CM mode:\n'
          'Enter a single numeric value in cm.\n'
          'Examples: 34 or 34.5'
          '${_isEstimationCmMode ? '\n\nYour sizes stay in cm everywhere — review, cutting sizes and reports.' : ''}';
    } else if (_usesInchSuterSplit) {
      instructionText =
          'Inches mode:\n'
          'Type the inch (a whole number, e.g. 45) and pick the suter by '
          'scrolling the tape wheel.\n'
          'Suter runs 0 to 7.5 in half-suter steps — pick half or full, '
          'whatever you need.';
    } else if (_usesFeetInchSplit) {
      instructionText =
          'Feet mode:\n'
          'Type the feet (a whole number, e.g. 4) and pick the inch by '
          'scrolling the tape wheel.\n'
          '12 inches make the next foot, so the inch wheel runs 0 to 11.';
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
          content: SingleChildScrollView(child: Text(instructionText)),
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

  /// The unit picker that sits on the input page itself, right above the size
  /// fields, so the chosen unit is never in doubt while typing a measurement.
  /// The same options still exist in the sidebar; this is the one people see.
  /// The controls a user touches while typing sizes -- unit, and on
  /// fabrication also lock and rubber.
  ///
  /// These used to live behind the sidebar, which meant opening a panel to
  /// check something that changes the numbers being typed. They sit on the page
  /// now, small enough to stay out of the way. Anything that is set once per
  /// window -- sections, D46/D52, back collar, net -- stays in the Sections
  /// panel.
  Widget _buildQuickControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildInlineUnitSelector(context),
        if (_showsLockTypeSelector) ...<Widget>[
          const SizedBox(height: 8),
          _buildInlineChipRow(
            context,
            label: 'Lock',
            chips: <Widget>[
              _buildInlineChip(
                chipKey: const Key('lock_latch_option'),
                label: 'Latch',
                selected: _lockType == _LockType.latch,
                onTap: () => _onLockTypeChanged(_LockType.latch),
              ),
              _buildInlineChip(
                chipKey: const Key('lock_self_option'),
                label: 'Self',
                selected: _lockType == _LockType.self,
                onTap: () => _onLockTypeChanged(_LockType.self),
              ),
              if (_allowsHandalLockType)
                _buildInlineChip(
                  chipKey: const Key('lock_handal_option'),
                  label: 'Handal',
                  selected: _lockType == _LockType.handal,
                  onTap: () => _onLockTypeChanged(_LockType.handal),
                ),
            ],
          ),
        ],
        if (_isFabricationFlow) ...<Widget>[
          const SizedBox(height: 8),
          _buildInlineChipRow(
            context,
            label: 'Rubber',
            chips: <Widget>[
              _buildInlineChip(
                chipKey: const Key('rubber_fix_option'),
                label: 'Fix',
                selected: _rubberType == _RubberType.fix,
                onTap: () => _onRubberTypeChanged(_RubberType.fix),
              ),
              // Some windows only ever take Fix, so U is not offered there
              // rather than offered and silently ignored.
              if (!_isFixOnlyRubberWindow)
                _buildInlineChip(
                  chipKey: const Key('rubber_u_option'),
                  label: 'U',
                  selected: _rubberType == _RubberType.u,
                  onTap: () => _onRubberTypeChanged(_RubberType.u),
                ),
            ],
          ),
        ],
      ],
    );
  }

  void _onLockTypeChanged(_LockType value) {
    setState(() => _lockType = value);
    _persistSidebarSelections();
  }

  void _onRubberTypeChanged(_RubberType value) {
    setState(() {
      _rubberType = _isFixOnlyRubberWindow ? _RubberType.fix : value;
    });
    _persistSidebarSelections();
  }

  Widget _buildInlineChipRow(
    BuildContext context, {
    required String label,
    required List<Widget> chips,
  }) {
    return OptionSwitchRow(label: label, options: chips);
  }

  /// Unit chips, and the keys the tests drive them by.
  ///
  /// Fabrication's centimetre mode is stored in the `feet` slot -- see
  /// [_isFabricationCmMode] -- so the CM chip there must set [UnitMode.feet],
  /// not [UnitMode.cm]. Setting the latter leaves the screen in neither cm nor
  /// inch handling and the size is read wrongly.
  List<(UnitMode, String, String)> get _unitOptions => _isFabricationFlow
      ? const <(UnitMode, String, String)>[
          (UnitMode.inches, 'Inches', 'unit_inches_radio'),
          (UnitMode.feet, 'CM', 'unit_cm_radio'),
        ]
      : const <(UnitMode, String, String)>[
          (UnitMode.feet, 'Feet', 'unit_feet_radio'),
          (UnitMode.inches, 'Inches', 'unit_inches_radio'),
          (UnitMode.cm, 'CM', 'unit_cm_radio'),
        ];

  Widget _buildInlineUnitSelector(BuildContext context) {
    return _buildInlineChipRow(
      context,
      label: 'Unit',
      chips: <Widget>[
        for (final (UnitMode mode, String label, String key) in _unitOptions)
          _buildInlineChip(
            chipKey: Key(key),
            label: label,
            selected: _unitMode == mode,
            onTap: () => _onUnitModeChanged(mode),
          ),
      ],
    );
  }

  /// Unit, lock and rubber all draw from the same set as the gauge switches,
  /// so the three rows of the input screen read as one control rather than
  /// three borrowed ones.
  Widget _buildInlineChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Key? chipKey,
  }) {
    return OptionSwitch(
      key: chipKey,
      label: label,
      selected: selected,
      onTap: onTap,
      expand: true,
    );
  }

  void _onUnitModeChanged(UnitMode mode) {
    if (_unitMode == mode) {
      return;
    }
    final bool wasSplit = _usesSplitInput;

    setState(() {
      // Leaving a split mode: fold the split controllers back into the single
      // combined controller so the entered value survives the unit switch.
      if (wasSplit) {
        _syncCombinedControllersFromSplit();
      }
      _unitMode = mode;
      // Entering a split mode: seed the split controllers from the combined one.
      if (_usesSplitInput) {
        _syncSplitControllersFromCombined();
      }
      _heightError = _dimensionErrorForCurrentMode(
        _heightController,
        _heightInchController,
        _heightSuterController,
      );
      _widthError = _dimensionErrorForCurrentMode(
        _widthController,
        _widthInchController,
        _widthSuterController,
      );
      _leftWidthError = _usesSplitWidthInputs
          ? _dimensionErrorForCurrentMode(
              _leftWidthController,
              _leftWidthInchController,
              _leftWidthSuterController,
            )
          : null;
      // Arch stays a single typed field, even in split modes.
      _archError = _usesArchInput
          ? (_isCmMode
                ? _validateCmDimension(_archController.text)
                : _validateDimension(_archController.text))
          : null;
    });
    _persistSidebarSelections();
  }

  /// Validates one dimension using whichever input style the current unit mode
  /// shows: the split (whole + wheel) controllers, the cm field, or the plain
  /// typed field.
  String? _dimensionErrorForCurrentMode(
    TextEditingController combined,
    TextEditingController wholeController,
    TextEditingController wheelController,
  ) {
    if (_usesSplitInput) {
      return _validateSplitDimension(
        wholeController.text,
        wheelController.text,
      );
    }
    if (_isCmMode) {
      return _validateCmDimension(combined.text);
    }
    return _validateDimension(combined.text);
  }

  // Aluminium stock tops out around 19 ft, and real windows are well under
  // that. A feet-mode dimension this large almost always means the user typed
  // inch numbers (e.g. 46) while the unit was set to Feet — which otherwise
  // fails deep in optimization with a confusing "rate review failed".
  static const double _feetWarnThresholdFt = 15;

  /// Largest whole-feet value across the currently entered dimensions, used to
  /// detect the "inches typed as feet" mistake. Only meaningful in feet mode.
  double _maxEnteredFeet() {
    double maxFeet = 0;
    void consider(String raw) {
      final String v = raw.trim();
      if (v.isEmpty) return;
      final double? feet = double.tryParse(v.split('.').first);
      if (feet != null && feet > maxFeet) {
        maxFeet = feet;
      }
    }

    consider(_heightController.text);
    consider(_widthController.text);
    if (_usesSplitWidthInputs) consider(_leftWidthController.text);
    if (_usesArchInput) consider(_archController.text);
    return maxFeet;
  }

  /// Asks the user whether an oversized feet entry was meant to be inches.
  /// Returns 'inches', 'feet', or null (cancel).
  Future<String?> _showOversizedFeetDialog(double maxFeet) {
    return showDialog<String>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          icon: const Icon(
            Icons.straighten_rounded,
            color: AppTheme.amberAccent,
            size: 32,
          ),
          title: const Text('Check the unit'),
          content: Text(
            'A size of ${maxFeet.toStringAsFixed(0)} feet is very large for a '
            'window. Aluminium sections are only about 19 feet long, so sizes '
            'this big cannot be optimized and the bill will fail.\n\n'
            'Did you mean inches?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('feet'),
              child: const Text('Keep Feet'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop('inches'),
              child: const Text('Switch to Inches'),
            ),
          ],
        );
      },
    );
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
    final String? heightError = _dimensionErrorForCurrentMode(
      _heightController,
      _heightInchController,
      _heightSuterController,
    );
    final String? widthError = _dimensionErrorForCurrentMode(
      _widthController,
      _widthInchController,
      _widthSuterController,
    );
    final String? leftWidthError = _usesSplitWidthInputs
        ? _dimensionErrorForCurrentMode(
            _leftWidthController,
            _leftWidthInchController,
            _leftWidthSuterController,
          )
        : null;
    final String? archError = _usesArchInput
        ? (_isCmMode
              ? _validateCmDimension(_archController.text)
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

  void _resetInputsForNextEntry() {
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
      _quantityController.clear();
      if (_numberingMode == NumberingMode.manual) {
        _winNoController.clear();
      }
      _heightError = null;
      _widthError = null;
      _leftWidthError = null;
      _archError = null;
      _winNoError = null;
    });
    _focusFirstField();
  }

  void _scheduleProjectSessionSync() {
    _pendingProjectSync = _pendingProjectSync.then(
      (_) => _syncProjectSession(),
    );
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

    // Fold the split (whole + wheel) controllers into the single combined
    // controller now, so the oversized-feet check and the storage below both
    // read the final value the user picked.
    if (_usesSplitInput) {
      _syncCombinedControllersFromSplit();
    }

    // Catch the common "inches typed as feet" mistake before it fails later
    // in optimization / rate review with a confusing backend-looking error.
    if (!_isFabricationFlow && _unitMode == UnitMode.feet) {
      final double maxFeet = _maxEnteredFeet();
      if (maxFeet >= _feetWarnThresholdFt) {
        final String? choice = await _showOversizedFeetDialog(maxFeet);
        if (!mounted || choice == null) {
          return;
        }
        if (choice == 'inches') {
          setState(() {
            _unitMode = UnitMode.inches;
            // Re-seed the inch + suter wheel from the value just entered as feet.
            _syncSplitControllersFromCombined();
          });
          _preferencesStore.persistUnitMode(
            widget.session.flow,
            UnitMode.inches,
          );
          // The same numbers must still be valid as inches (sutter 0..7).
          if (!_validateAndShowErrors()) {
            return;
          }
        }
        // 'feet' → the user confirmed; continue saving as feet.
      }
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
    // Every unit (including estimation cm) is stored exactly as entered so
    // the review list and editing always show the user's own numbers. The
    // engine-facing inch conversion for cm items happens on the wire, in
    // OptimizationWindowRequest.fromReviewItem.
    final UnitMode storedUnitMode = _unitMode;
    String dimForStorage(String raw) => _normalizeDimensionForStorage(raw);

    final String heightValue = dimForStorage(_heightController.text);
    final String rightWidthValue = dimForStorage(_widthController.text);
    final String? leftWidthValue = _usesSplitWidthInputs
        ? dimForStorage(_leftWidthController.text)
        : null;
    final String? archValue = _usesArchInput
        ? dimForStorage(_archController.text)
        : null;
    final int? lockTypeValue = _showsLockTypeSelector
        ? _lockTypeCode(_lockType)
        : null;
    final String? rubberTypeValue = _isFabricationFlow && _isLockSupportedWindow
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
        unitMode: storedUnitMode,
        heightValue: heightValue,
        widthValue: rightWidthValue,
        rightWidthValue: _usesSplitWidthInputs ? rightWidthValue : null,
        leftWidthValue: leftWidthValue,
        archValue: archValue,
        addBottom: _doorD46Enabled,
        addTee: _doorD52Enabled,
        addNet: _openableNetEnabled,
        backCollarCm: _backCollarCm,
        lockType: lockTypeValue,
        rubberType: rubberTypeValue,
        description: description,
        material: _material,
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

    final int quantity = (int.tryParse(_quantityController.text.trim()) ?? 1)
        .clamp(1, 500);

    try {
      for (int q = 0; q < quantity; q++) {
        // For quantity > 1 always use auto-numbering; for qty 1 respect manual mode
        final int itemWinNo =
            (quantity == 1 && _numberingMode == NumberingMode.manual)
            ? winNo
            : widget.session.nextWinNo;
        widget.session.addItem(
          winNo: itemWinNo,
          windowLabel: widget.node.label,
          windowCode: windowCode,
          windowIndex: windowIndex,
          collarIndex: _selectedCollar,
          unitMode: storedUnitMode,
          heightValue: heightValue,
          widthValue: rightWidthValue,
          rightWidthValue: _usesSplitWidthInputs ? rightWidthValue : null,
          leftWidthValue: leftWidthValue,
          archValue: archValue,
          addBottom: _doorD46Enabled,
          addTee: _doorD52Enabled,
          addNet: _openableNetEnabled,
          backCollarCm: _backCollarCm,
          lockType: lockTypeValue,
          rubberType: rubberTypeValue,
          description: description,
          material: _material,
        );
      }
    } on ArgumentError catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Window number already exists.')),
      );
      return;
    }

    _persistSidebarSelections();
    _resetInputsForNextEntry();
    _scheduleProjectSessionSync();
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
          _selectedSectionCode = _normalizedSelectedSectionCode(
            _selectedSectionCode,
            collarIndex,
          );
        });
        _persistSidebarSelections();
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

  /// The "Height" / "Width" label on a size field.
  ///
  /// Heavier and darker than a normal field label: these two fields sit right
  /// on top of each other and hold numbers that look alike, so a glance has to
  /// be enough to tell which one is being typed into. The error state still
  /// turns red -- that is resolved rather than hardcoded, or a wrong size would
  /// lose its warning colour.
  WidgetStateTextStyle get _dimensionLabelStyle =>
      WidgetStateTextStyle.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.error)) {
          return const TextStyle(
            color: AppTheme.danger,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          );
        }
        return const TextStyle(
          color: AppTheme.deepTeal,
          fontWeight: FontWeight.w900,
          fontSize: 16,
        );
      });

  Widget _buildSingleDimensionField({
    required GlobalKey fieldKey,
    required TextEditingController controller,
    required String label,
    required String? errorText,
    required TextStyle? numberInputStyle,
    required TextStyle? hintStyle,
    required String hintText,
    required ValueChanged<String> onChanged,
    required FocusNode focusNode,
  }) {
    return TextField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      textInputAction: _textInputActionForField(focusNode),
      style: numberInputStyle,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      onSubmitted: (_) => _submitFromField(focusNode),
      scrollPadding: EdgeInsets.zero,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: _dimensionLabelStyle,
        floatingLabelStyle: _dimensionLabelStyle,
        hintText: hintText,
        hintStyle: hintStyle,
        errorText: errorText,
      ),
    );
  }

  /// A dimension entered as a typed whole part + a tape wheel for the sub-part.
  /// Inches mode: inch (typed) + suter wheel (0..7.5). Feet mode: feet (typed) +
  /// inch wheel (0..11). The two shared controllers carry the (whole, wheel)
  /// parts for whichever mode is active.
  Widget _buildSplitDimensionField({
    required String label,
    required GlobalKey wholeFieldKey,
    required TextEditingController wholeController,
    required TextEditingController wheelController,
    required String? errorText,
    required TextStyle? numberInputStyle,
    required VoidCallback onChanged,
    required FocusNode wholeFocusNode,

    /// Focus for the sub-part box. Only used when sizes are typed — the wheel
    /// takes no focus, so the chain skips it there.
    FocusNode? subFocusNode,
    // Only the first field on screen carries the tour's wheel target; ids are
    // unique, so registering it on all three would leave the spotlight
    // pointing at whichever built last.
    bool isTourWheelExample = false,
  }) {
    final bool feetMode = _usesFeetInchSplit;
    final double wheelValue = double.tryParse(wheelController.text.trim()) ?? 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            key: wholeFieldKey,
            controller: wholeController,
            focusNode: wholeFocusNode,
            textInputAction: _textInputActionForField(wholeFocusNode),
            style: numberInputStyle,
            keyboardType: const TextInputType.numberWithOptions(signed: false),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _submitFromField(wholeFocusNode),
            scrollPadding: EdgeInsets.zero,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              labelText: feetMode ? '$label (Feet)' : '$label (Inch)',
              labelStyle: _dimensionLabelStyle,
              floatingLabelStyle: _dimensionLabelStyle,
              hintText: feetMode ? 'e.g. 4' : 'e.g. 45',
              errorText: errorText,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // The sub-part is picked on a tape wheel — inch (0..11) in feet mode,
        // suter (0..7.5) in inches mode — so it always matches the real
        // inchi-tape resolution. Kuch log seedha likhna pasand karte hain, is
        // liye settings se ise typing box mein badla ja sakta ha.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _maybeTourTarget(
              id: 'input.wheel',
              enabled: isTourWheelExample,
              child: _usesKeypadSizeInput
                  ? _buildSubPartField(
                      controller: wheelController,
                      feetMode: feetMode,
                      numberInputStyle: numberInputStyle,
                      onChanged: onChanged,
                      focusNode: subFocusNode,
                    )
                  : feetMode
                  ? InchWheel(
                      value: wheelValue,
                      onChanged: (double value) {
                        wheelController.text = InchWheel.format(value);
                        onChanged();
                      },
                    )
                  : SuterWheel(
                      value: wheelValue,
                      onChanged: (double value) {
                        wheelController.text = SuterWheel.format(value);
                        onChanged();
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }

  /// Wraps [child] in a tour target only where the tour actually wants one,
  /// so a builder shared by several fields registers the id just once.
  Widget _maybeTourTarget({
    required String id,
    required bool enabled,
    required Widget child,
  }) {
    if (!enabled) return child;
    return TutorialTarget(id: id, child: child);
  }

  /// Settings se aane wala faisla: wheel ya seedha typing box.
  bool get _usesKeypadSizeInput =>
      AppSettings.instance.sizeInputMode == SizeInputMode.keypad;

  /// Wheel ka typing-box wala badal. Feet mode mein inch (0..11), inches mode
  /// mein suter (0..7.5) — wahi range jo wheel deta ha.
  Widget _buildSubPartField({
    required TextEditingController controller,
    required bool feetMode,
    required TextStyle? numberInputStyle,
    required VoidCallback onChanged,
    FocusNode? focusNode,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: numberInputStyle,
      keyboardType: TextInputType.numberWithOptions(
        signed: false,
        decimal: !feetMode,
      ),
      textInputAction: focusNode == null
          ? TextInputAction.next
          : _textInputActionForField(focusNode),
      onSubmitted: (_) {
        if (focusNode != null) _submitFromField(focusNode);
      },
      inputFormatters: <TextInputFormatter>[
        if (feetMode)
          FilteringTextInputFormatter.digitsOnly
        else
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d?')),
      ],
      scrollPadding: EdgeInsets.zero,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: feetMode ? 'Inch' : 'Suter',
        hintText: feetMode ? '0-11' : '0-7.5',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle? hintStyle = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: AppTheme.slate.withValues(alpha: 0.6));
    final TextStyle? numberInputStyle = Theme.of(context).textTheme.titleLarge
        ?.copyWith(
          color: AppTheme.inkBlue,
          fontWeight: FontWeight.w700,
          fontSize: 22,
          // Tabular figures: every digit takes the same width, so a column of
          // sizes lines up and a number does not shuffle sideways as it is
          // typed. It is what a measurement should look like.
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        );
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    // The overlay wraps the whole Scaffold, not just its body: the settings
    // drawer is painted above the body, so a spotlight inside the body could
    // never reach the section buttons the tour has to point at.
    return TutorialOverlay(
      screen: TutorialScreen.windowInput,
      child: Scaffold(
        key: _scaffoldKey,
        resizeToAvoidBottomInset: false,
        // Hidden while the keyboard is up: on a phone the chain would sit on
        // top of the field being typed into.
        bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
            ? null
            : FlowProgressBar(stepId: FlowSteps.sizeInput.id),
        endDrawer: Drawer(
          key: const Key('settings_drawer'),
          width: _handler.showDrawerForCollar(_selectedCollar)
              ? MediaQuery.sizeOf(context).width * 0.38
              : null,
          child: SafeArea(
            // Chhoti screen par sab options ek saath nahi aate, is liye poora
            // sidebar upar-neeche scroll hota ha -- sirf sections ki list nahi.
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sections',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.deepTeal,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // The arithmetic behind this window's cut lengths. It sits
                  // at the top of the sidebar rather than in settings because
                  // it belongs to the window on the bench, not to the app: a
                  // formula only means anything alongside the collar and lock
                  // it is cut with.
                  _FormulaEditorButton(onTap: _openFormulaEditor),
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
                  if (_showsBackCollarOption) ...[
                    Text(
                      'Back Collar',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.deepTeal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSidebarToggleOption(
                      label: '1.7 cm',
                      selected: _backCollarCm != kBackCollarTwoCm,
                      onTap: () => _setBackCollarCm(kBackCollarDefaultCm),
                    ),
                    const SizedBox(height: 6),
                    _buildSidebarToggleOption(
                      label: '2 cm',
                      selected: _backCollarCm == kBackCollarTwoCm,
                      onTap: () => _setBackCollarCm(kBackCollarTwoCm),
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
                    // Poora drawer scroll hota ha, is liye ye list apna scroll
                    // nahi chalati -- warna do scroll ek doosre sa larte hain.
                    TutorialTarget(
                      id: 'input.sidebarSections',
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
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
                                  _selectedSectionCode = isSelected
                                      ? null
                                      : code;
                                });
                                _persistSidebarSelections();
                                TutorialController.instance.advanceAfterTap();
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
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
                ],
              ),
            ),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
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
                      TutorialTarget(
                        id: 'input.next',
                        child: IconButton(
                          key: const Key('open_review_button'),
                          onPressed: () {
                            TutorialController.instance.advanceAfterTap();
                            _openReview();
                          },
                          icon: const Icon(Icons.arrow_forward_rounded),
                          color: AppTheme.deepTeal,
                        ),
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
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: AppTheme.deepTeal,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      // Was three dots, which said nothing about what was
                      // behind it. The panel is about sections, so the button
                      // says so.
                      TutorialTarget(
                        id: 'input.sectionsButton',
                        child: TextButton.icon(
                          key: const Key('open_settings_drawer_button'),
                          onPressed: _openSettings,
                          icon: const Icon(Icons.view_list_rounded, size: 19),
                          label: const Text('Sections'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.royalBlue,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      18,
                      6,
                      18,
                      math.max(24, keyboardInset + 140),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TutorialTarget(
                          id: 'input.winNo',
                          child: Container(
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
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TutorialTarget(
                          id: 'input.collarCards',
                          child: SizedBox(
                            height: _collarCardSize + 30,
                            child: LayoutBuilder(
                              builder:
                                  (
                                    BuildContext context,
                                    BoxConstraints constraints,
                                  ) {
                                    final double availableWidth =
                                        constraints.maxWidth;
                                    final double side = math.min(
                                      _collarCardSize,
                                      availableWidth *
                                          _collarViewportFraction *
                                          0.9,
                                    );
                                    return PageView.builder(
                                      key: const Key('collar_page_view'),
                                      controller: _collarPageController,
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: _handler.collarCount,
                                      onPageChanged: (int index) {
                                        setState(() {
                                          _selectedCollar = index + 1;
                                          _selectedSectionCode =
                                              _normalizedSelectedSectionCode(
                                                _selectedSectionCode,
                                                _selectedCollar,
                                              );
                                        });
                                        _persistSidebarSelections();
                                      },
                                      itemBuilder:
                                          (BuildContext context, int index) {
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
                        ),
                        const SizedBox(height: 12),
                        if (_numberingMode == NumberingMode.manual) ...[
                          TextField(
                            key: _winNoFieldKey,
                            controller: _winNoController,
                            focusNode: _winNoFocusNode,
                            enabled: !widget.isEditMode,
                            keyboardType: const TextInputType.numberWithOptions(
                              signed: false,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            textInputAction: _textInputActionForField(
                              _winNoFocusNode,
                            ),
                            onSubmitted: (_) =>
                                _submitFromField(_winNoFocusNode),
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
                        // Unit, lock and rubber used to live behind the sidebar,
                        // so people typed a size without being sure which unit
                        // was set. They sit with the size fields now.
                        TutorialTarget(
                          id: 'input.unit',
                          child: _buildQuickControls(context),
                        ),
                        // Which aluminium this one is made from, before the
                        // sizes are typed. The stock is settled first -- it is
                        // decided for the job, or carried over from the last
                        // window -- and the measuring is the part that needs
                        // attention, so it sits closest to the save button
                        // with only the optional description after it.
                        const SizedBox(height: 12),
                        TutorialTarget(
                          id: 'input.material',
                          child: WindowMaterialPicker(
                            value: _material,
                            onChanged: (WindowMaterial next) {
                              setState(() => _material = next);
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        TutorialTarget(
                          id: 'input.sizes',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              if (_usesSplitInput)
                                _buildSplitDimensionField(
                                  isTourWheelExample: true,
                                  label: 'Height',
                                  wholeFieldKey: _heightFieldKey,
                                  wholeController: _heightInchController,
                                  wheelController: _heightSuterController,
                                  errorText: _heightError,
                                  numberInputStyle: numberInputStyle,
                                  wholeFocusNode: _heightFocusNode,
                                  subFocusNode: _heightSubFocusNode,
                                  onChanged: () {
                                    setState(() {
                                      _heightController.text =
                                          _combineSplitForStorage(
                                            _heightInchController.text,
                                            _heightSuterController.text,
                                          );
                                      _heightError = _validateSplitDimension(
                                        _heightInchController.text,
                                        _heightSuterController.text,
                                      );
                                    });
                                  },
                                )
                              else
                                _buildSingleDimensionField(
                                  fieldKey: _heightFieldKey,
                                  controller: _heightController,
                                  focusNode: _heightFocusNode,
                                  label: 'Height',
                                  errorText: _heightError,
                                  numberInputStyle: numberInputStyle,
                                  hintStyle: hintStyle,
                                  hintText: _isCmMode
                                      ? 'cm'
                                      : _unitMode.inputHint,
                                  onChanged: (_) {
                                    if (_heightError != null) {
                                      setState(() {
                                        _heightError = _isCmMode
                                            ? _validateCmDimension(
                                                _heightController.text,
                                              )
                                            : _validateDimension(
                                                _heightController.text,
                                              );
                                      });
                                    }
                                  },
                                ),
                              const SizedBox(height: 12),
                              if (_usesSplitInput)
                                _buildSplitDimensionField(
                                  label: _usesSplitWidthInputs
                                      ? 'Right Width'
                                      : 'Width',
                                  wholeFieldKey: _widthFieldKey,
                                  wholeController: _widthInchController,
                                  wheelController: _widthSuterController,
                                  errorText: _widthError,
                                  numberInputStyle: numberInputStyle,
                                  wholeFocusNode: _widthFocusNode,
                                  subFocusNode: _widthSubFocusNode,
                                  onChanged: () {
                                    setState(() {
                                      _widthController.text =
                                          _combineSplitForStorage(
                                            _widthInchController.text,
                                            _widthSuterController.text,
                                          );
                                      _widthError = _validateSplitDimension(
                                        _widthInchController.text,
                                        _widthSuterController.text,
                                      );
                                    });
                                  },
                                )
                              else
                                _buildSingleDimensionField(
                                  fieldKey: _widthFieldKey,
                                  controller: _widthController,
                                  focusNode: _widthFocusNode,
                                  label: _usesSplitWidthInputs
                                      ? 'Right Width'
                                      : 'Width',
                                  errorText: _widthError,
                                  numberInputStyle: numberInputStyle,
                                  hintStyle: hintStyle,
                                  hintText: _isCmMode
                                      ? 'cm'
                                      : _unitMode.inputHint,
                                  onChanged: (_) {
                                    if (_widthError != null) {
                                      setState(() {
                                        _widthError = _isCmMode
                                            ? _validateCmDimension(
                                                _widthController.text,
                                              )
                                            : _validateDimension(
                                                _widthController.text,
                                              );
                                      });
                                    }
                                  },
                                ),
                              if (_usesSplitWidthInputs) ...[
                                const SizedBox(height: 12),
                                if (_usesSplitInput)
                                  _buildSplitDimensionField(
                                    label: 'Left Width',
                                    wholeFieldKey: _leftWidthFieldKey,
                                    wholeController: _leftWidthInchController,
                                    wheelController: _leftWidthSuterController,
                                    errorText: _leftWidthError,
                                    numberInputStyle: numberInputStyle,
                                    wholeFocusNode: _leftWidthFocusNode,
                                    subFocusNode: _leftWidthSubFocusNode,
                                    onChanged: () {
                                      setState(() {
                                        _leftWidthController.text =
                                            _combineSplitForStorage(
                                              _leftWidthInchController.text,
                                              _leftWidthSuterController.text,
                                            );
                                        _leftWidthError =
                                            _validateSplitDimension(
                                              _leftWidthInchController.text,
                                              _leftWidthSuterController.text,
                                            );
                                      });
                                    },
                                  )
                                else
                                  _buildSingleDimensionField(
                                    fieldKey: _leftWidthFieldKey,
                                    controller: _leftWidthController,
                                    focusNode: _leftWidthFocusNode,
                                    label: 'Left Width',
                                    errorText: _leftWidthError,
                                    numberInputStyle: numberInputStyle,
                                    hintStyle: hintStyle,
                                    hintText: _isCmMode
                                        ? 'cm'
                                        : _unitMode.inputHint,
                                    onChanged: (_) {
                                      if (_leftWidthError != null) {
                                        setState(() {
                                          _leftWidthError = _isCmMode
                                              ? _validateCmDimension(
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
                                  fieldKey: _archFieldKey,
                                  controller: _archController,
                                  focusNode: _archFocusNode,
                                  label: 'Arch',
                                  errorText: _archError,
                                  numberInputStyle: numberInputStyle,
                                  hintStyle: hintStyle,
                                  hintText: _isCmMode
                                      ? 'cm'
                                      : _unitMode.inputHint,
                                  onChanged: (_) {
                                    if (_archError != null) {
                                      setState(() {
                                        _archError = _isCmMode
                                            ? _validateCmDimension(
                                                _archController.text,
                                              )
                                            : _validateDimension(
                                                _archController.text,
                                              );
                                      });
                                    }
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Quantity sits above the description: it belongs with
                        // the measurement, and a description is the last thing
                        // anyone types — when they type one at all.
                        if (!widget.isEditMode) ...[
                          const SizedBox(height: 12),
                          TutorialTarget(
                            id: 'input.quantity',
                            child: TextField(
                              controller: _quantityController,
                              focusNode: _quantityFocusNode,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    signed: false,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              textInputAction: _textInputActionForField(
                                _quantityFocusNode,
                              ),
                              onSubmitted: (_) =>
                                  _submitFromField(_quantityFocusNode),
                              decoration: InputDecoration(
                                labelText: 'Quantity (Optional)',
                                hintText: 'e.g. 6  (default: 1)',
                                hintStyle: hintStyle,
                                prefixIcon: const Icon(Icons.copy_all_rounded),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TutorialTarget(
                          id: 'input.description',
                          child: TextField(
                            key: _descriptionFieldKey,
                            controller: _descriptionController,
                            focusNode: _descriptionFocusNode,
                            textInputAction: _textInputActionForField(
                              _descriptionFocusNode,
                            ),
                            maxLength: _maxDescriptionLength,
                            maxLines: 2,
                            onSubmitted: (_) =>
                                _submitFromField(_descriptionFocusNode),
                            decoration: InputDecoration(
                              labelText: 'Description (Optional)',
                              hintText: 'e.g. bath room window',
                              hintStyle: hintStyle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.fromLTRB(
                    18,
                    8,
                    18,
                    math.max(16, keyboardInset + 16),
                  ),
                  child: TutorialTarget(
                    id: 'input.save',
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        key: const Key('input_save_button'),
                        onPressed: () {
                          TutorialController.instance.advanceAfterTap();
                          _onSavePressed();
                        },
                        icon: const Icon(Icons.save_outlined),
                        label: Text(widget.isEditMode ? 'Update' : 'Save'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
    const double w = 96;
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
            'Collar $number',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
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

/// Opens the arithmetic behind this window's cut lengths.
///
/// Given its own look rather than the sidebar's plain rows: it leaves the
/// screen, which the rows do not, and what it opens is the one place in Quick
/// AL where a workshop can change what the saw is told. That deserves to look
/// like a door rather than another switch.
class _FormulaEditorButton extends StatelessWidget {
  const _FormulaEditorButton({required this.onTap});

  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => unawaited(onTap()),
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppTheme.brandGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: <Widget>[
                const Icon(Icons.functions_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Edit formulas',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
