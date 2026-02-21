import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'window_input_handler.dart';
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

class _WindowInputScreenState extends State<WindowInputScreen> {
  static const int _maxDescriptionLength = 120;
  static const double _collarCardSize = 240;
  static const double _collarViewportFraction = 0.78;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _winNoController = TextEditingController();
  final FocusNode _heightFocusNode = FocusNode();

  late final PageController _collarPageController;
  double _collarPageValue = 0;
  late UnitMode _unitMode;
  late int _selectedCollar;
  String? _selectedSectionCode;
  String? _winNoError;
  String? _heightError;
  String? _widthError;
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

  @override
  void initState() {
    super.initState();
    _handler = handlerForWindow(widget.node);
    _unitMode = widget.editingItem?.unitMode ?? UnitMode.inches;
    _selectedCollar = widget.editingItem?.collarIndex ?? 1;
    _heightController.text = widget.editingItem?.heightValue ?? '';
    _widthController.text = widget.editingItem?.widthValue ?? '';
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
    _widthController.dispose();
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

  void _showDimensionInfo() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Input Instructions'),
          content: const SingleChildScrollView(
            child: Text(
              'eg. inch.suter => 45.7\n'
              'inch = 45\n'
              'suter = 7\n'
              'suter will not be greater than 7.\n'
              '____________________________________\n'
              'eg feet.inchs => 4.9\n'
              '4 = feet\n'
              '9 = inch will not be greater than 11',
            ),
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
    setState(() {
      _unitMode = mode;
      _heightError = _validateDimension(_heightController.text);
      _widthError = _validateDimension(_widthController.text);
    });
  }

  String? _validateDimension(String rawValue) {
    final String value = rawValue.trim();
    if (value.isEmpty) {
      return 'Required';
    }

    final RegExp basicPattern = RegExp(r'^\d+\.\d+$');
    if (!basicPattern.hasMatch(value)) {
      return 'Use format ${_unitMode.inputHint}';
    }

    final List<String> parts = value.split('.');
    if (parts.length != 2) {
      return 'Invalid value';
    }

    final int? rightPart = int.tryParse(parts[1]);
    if (rightPart == null) {
      return 'Invalid value';
    }

    if (_unitMode == UnitMode.inches) {
      if (parts[1].length != 1) {
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
    final String? heightError = _validateDimension(_heightController.text);
    final String? widthError = _validateDimension(_widthController.text);

    setState(() {
      _winNoError = winNoError;
      _heightError = heightError;
      _widthError = widthError;
    });

    return winNoError == null && heightError == null && widthError == null;
  }

  String? _normalizedDescription() {
    final String trimmed = _descriptionController.text.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  void _onSavePressed() {
    if (!_validateAndShowErrors()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix Window No. / Height / Width input errors.'),
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
        heightValue: _heightController.text.trim(),
        widthValue: _widthController.text.trim(),
        description: description,
        clearDescription: description == null,
      );
      widget.session.updateItem(updated);
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
        heightValue: _heightController.text.trim(),
        widthValue: _widthController.text.trim(),
        description: description,
      );
    } on ArgumentError catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Window number already exists.')),
      );
      return;
    }

    setState(() {
      _heightController.clear();
      _widthController.clear();
      _descriptionController.clear();
      if (_numberingMode == NumberingMode.manual) {
        _winNoController.clear();
      }
      _heightError = null;
      _widthError = null;
      _winNoError = null;
    });
    _heightFocusNode.requestFocus();
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
          constraints: BoxConstraints(maxWidth: side, maxHeight: side),
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
                aspectRatio: 1,
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
                          if (overlayWidget != null) overlayWidget,
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

  @override
  Widget build(BuildContext context) {
    final TextStyle? hintStyle = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: AppTheme.slate.withValues(alpha: 0.6));

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
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
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
                  segments: const <ButtonSegment<UnitMode>>[
                    ButtonSegment<UnitMode>(
                      value: UnitMode.feet,
                      label: Text('Feet', key: Key('unit_feet_radio')),
                    ),
                    ButtonSegment<UnitMode>(
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
                        'Estimation',
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
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.menu_rounded),
                      color: AppTheme.deepTeal,
                    ),
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
                      itemCount: 14,
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
                      TextField(
                        key: const Key('input_height_field'),
                        controller: _heightController,
                        focusNode: _heightFocusNode,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        onChanged: (_) {
                          if (_heightError != null) {
                            setState(() {
                              _heightError = _validateDimension(
                                _heightController.text,
                              );
                            });
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Height',
                          hintText: _unitMode.inputHint,
                          hintStyle: hintStyle,
                          errorText: _heightError,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('input_width_field'),
                        controller: _widthController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        onChanged: (_) {
                          if (_widthError != null) {
                            setState(() {
                              _widthError = _validateDimension(
                                _widthController.text,
                              );
                            });
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Width',
                          hintText: _unitMode.inputHint,
                          hintStyle: hintStyle,
                          errorText: _widthError,
                        ),
                      ),
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
