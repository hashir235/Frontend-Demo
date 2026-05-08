import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/core/downloads/pdf_download_workflow.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_hero_header.dart';
import '../../../shared/widgets/app_screen_shell.dart';
import '../../../shared/widgets/bottom_action_bar.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/project_meta_strip.dart';
import '../../../shared/widgets/section_surface_card.dart';
import '../../../shared/widgets/state_message_card.dart';
import '../data/glass_sheet_optimization_api_client.dart';
import '../models/glass_report.dart';
import '../models/glass_sheet_optimization.dart';

class GlassSheetOptimizationScreen extends StatefulWidget {
  final String? projectId;
  final GlassReport glassReport;
  final GlassSheetOptimizationApiClient? apiClient;

  const GlassSheetOptimizationScreen({
    super.key,
    required this.glassReport,
    this.projectId,
    this.apiClient,
  });

  @override
  State<GlassSheetOptimizationScreen> createState() =>
      _GlassSheetOptimizationScreenState();
}

class _GlassSheetOptimizationScreenState
    extends State<GlassSheetOptimizationScreen> {
  late final GlassSheetOptimizationApiClient _apiClient;
  final TextEditingController _widthController = TextEditingController(
    text: '7',
  );
  final TextEditingController _heightController = TextEditingController(
    text: '12',
  );

  bool _useCustomSize = false;
  bool _allowRotation = true;
  bool _isRunning = false;
  GlassSheetOptimizationResult? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? GlassSheetOptimizationApiClient();
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  double _readSheetFt(TextEditingController controller, double fallback) {
    final double? parsed = double.tryParse(controller.text.trim());
    if (parsed == null || parsed <= 0) {
      return fallback;
    }
    return parsed;
  }

  Future<void> _runOptimization() async {
    final double sheetWidthFt = _useCustomSize
        ? _readSheetFt(_widthController, 7)
        : 7;
    final double sheetHeightFt = _useCustomSize
        ? _readSheetFt(_heightController, 12)
        : 12;

    setState(() {
      _isRunning = true;
      _errorMessage = null;
    });

    try {
      final GlassSheetOptimizationResult result = await _apiClient.optimize(
        glassReport: widget.glassReport,
        sheetWidthFt: sheetWidthFt,
        sheetHeightFt: sheetHeightFt,
        allowRotation: _allowRotation,
        projectId: widget.projectId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
        _isRunning = false;
      });
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
        _isRunning = false;
      });
    }
  }

  Future<void> _downloadPdf() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      final String fileName = await PdfDownloadWorkflow.generateAndDownload(
        endpoint: '/api/pdf/glass-sheets',
        payload: <String, Object?>{'projectId': widget.projectId},
        generationFailureMessage: 'Unable to generate glass sheet PDF.',
      );
      messenger.showSnackBar(
        SnackBar(content: Text('PDF downloaded to Downloads: $fileName')),
      );
    } on PdfDownloadException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to reach PDF service.')),
      );
    }
  }

  Future<void> _sharePdf() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      final String fileName = await PdfDownloadWorkflow.generateAndShare(
        endpoint: '/api/pdf/glass-sheets',
        payload: <String, Object?>{'projectId': widget.projectId},
        generationFailureMessage: 'Unable to generate glass sheet PDF.',
      );
      messenger.showSnackBar(
        SnackBar(content: Text('Opening share sheet: $fileName')),
      );
    } on PdfDownloadException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to reach PDF service.')),
      );
    }
  }

  Widget? _buildBottomActions() {
    return BottomActionBar(
      children: <Widget>[
        Expanded(
          child: FilledButton.icon(
            onPressed: _isRunning ? null : _runOptimization,
            icon: _isRunning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_mosaic_rounded),
            label: Text(_isRunning ? 'Optimizing' : 'Run'),
          ),
        ),
        const SizedBox(width: AppTheme.space4),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: _result == null ? null : _downloadPdf,
            icon: const Icon(Icons.download_rounded),
            label: const Text('PDF'),
          ),
        ),
        const SizedBox(width: AppTheme.space4),
        IconButton.filledTonal(
          tooltip: 'Share',
          onPressed: _result == null ? null : _sharePdf,
          icon: const Icon(Icons.share_outlined),
        ),
      ],
    );
  }

  String _glassSizeForRow(GlassReportRow row) {
    return '${row.widthDisplay} x ${row.heightDisplay}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Glass Sheets')),
      bottomNavigationBar: _buildBottomActions(),
      body: AppScreenShell(
        child: ListView(
          children: <Widget>[
            const AppHeroHeader(
              eyebrow: 'GLASS SHEETS',
              title: 'Sheet cutting optimization',
              subtitle: '',
            ),
            const SizedBox(height: AppTheme.space5),
            ProjectMetaStrip(
              projectName: widget.glassReport.projectName,
              projectLocation: widget.glassReport.projectLocation,
              extras: <Widget>[
                _MetaChip(
                  label: 'Rows',
                  value: '${widget.glassReport.rows.length}',
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space6),
            _buildSetupCard(context),
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: AppTheme.space5),
              StateMessageCard(
                icon: Icons.warning_amber_rounded,
                title: 'Optimization failed',
                message: _errorMessage,
                iconColor: AppTheme.danger,
              ),
            ],
            if (_result != null) ...<Widget>[
              const SizedBox(height: AppTheme.space6),
              _buildSummary(context, _result!),
              const SizedBox(height: AppTheme.space6),
              ..._result!.sheets.map(_buildSheetCard),
              if (_result!.rejectedPieces.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppTheme.space6),
                _buildRejectedCard(_result!),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSetupCard(BuildContext context) {
    return SectionSurfaceCard(
      title: 'Cut List',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: AppTheme.space3,
            runSpacing: AppTheme.space3,
            children: <Widget>[
              _MetaChip(
                label: 'Glass Rows',
                value: '${widget.glassReport.rows.length}',
              ),
              const _MetaChip(label: 'Default Sheet', value: '84 x 144 in'),
              _MetaChip(
                label: 'Rotation',
                value: _allowRotation ? 'On' : 'Off',
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space5),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const <DataColumn>[
                DataColumn(label: Text('WinNo')),
                DataColumn(label: Text('Label')),
                DataColumn(label: Text('Rub')),
                DataColumn(label: Text('Qty')),
                DataColumn(label: Text('Glass Size')),
              ],
              rows: widget.glassReport.rows
                  .map((GlassReportRow row) {
                    return DataRow(
                      cells: <DataCell>[
                        DataCell(Text('${row.windowNo}')),
                        DataCell(Text(row.windowName)),
                        DataCell(Text(row.rubberType)),
                        DataCell(Text('${row.quantity}')),
                        DataCell(Text(_glassSizeForRow(row))),
                      ],
                    );
                  })
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: AppTheme.space5),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _useCustomSize,
            title: const Text('Custom Sheet Size'),
            subtitle: const Text('Default: 7 ft x 12 ft = 84 x 144 in'),
            onChanged: (bool value) {
              setState(() {
                _useCustomSize = value;
              });
            },
          ),
          if (_useCustomSize) ...<Widget>[
            const SizedBox(height: AppTheme.space4),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _widthController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(labelText: 'Width ft'),
                  ),
                ),
                const SizedBox(width: AppTheme.space4),
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(labelText: 'Height ft'),
                  ),
                ),
              ],
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _allowRotation,
            title: const Text('Allow Rotation'),
            onChanged: (bool value) {
              setState(() {
                _allowRotation = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(
    BuildContext context,
    GlassSheetOptimizationResult result,
  ) {
    final List<MetricCard> cards = <MetricCard>[
      MetricCard(
        label: 'Sheets',
        value: '${result.summary.totalSheets}',
        icon: Icons.grid_view_rounded,
      ),
      MetricCard(
        label: 'Placed',
        value: '${result.summary.placedPieces}/${result.summary.totalPieces}',
        icon: Icons.widgets_rounded,
        accent: AppTheme.tealAccent,
      ),
      MetricCard(
        label: 'Used',
        value: formatArea(result.summary.usedArea),
        icon: Icons.crop_square_rounded,
        accent: AppTheme.success,
      ),
      MetricCard(
        label: 'Wastage',
        value: formatPercent(result.summary.wastagePercentage),
        icon: Icons.pie_chart_rounded,
        accent: AppTheme.amberAccent,
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 720
            ? 4
            : constraints.maxWidth >= 420
            ? 2
            : 1;
        final double spacing = AppTheme.space4;
        final double cardWidth =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map((MetricCard card) => SizedBox(width: cardWidth, child: card))
              .toList(growable: false),
        );
      },
    );
  }

  Widget _buildSheetCard(GlassSheetLayout sheet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space5),
      child: SectionSurfaceCard(
        title: 'Sheet ${sheet.sheetNo}',
        trailing: _MetaChip(
          label: 'Waste',
          value: formatPercent(sheet.wastagePercentage),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: AppTheme.space3,
              runSpacing: AppTheme.space3,
              children: <Widget>[
                _MetaChip(
                  label: 'Size',
                  value: '${sheet.widthDisplay} x ${sheet.heightDisplay}',
                ),
                _MetaChip(label: 'Used', value: '${sheet.placements.length}'),
                _MetaChip(label: 'Waste', value: '${sheet.wasteRects.length}'),
              ],
            ),
            const SizedBox(height: AppTheme.space4),
            AspectRatio(
              aspectRatio: sheet.width <= 0 || sheet.height <= 0
                  ? 0.58
                  : sheet.width / sheet.height,
              child: CustomPaint(
                painter: _GlassSheetPainter(sheet),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: AppTheme.space4),
            Wrap(
              spacing: AppTheme.space3,
              runSpacing: AppTheme.space3,
              children: <Widget>[
                _MetaChip(label: 'Pieces', value: '${sheet.placements.length}'),
                _MetaChip(label: 'Used', value: formatArea(sheet.usedArea)),
                _MetaChip(label: 'Waste', value: formatArea(sheet.wasteArea)),
              ],
            ),
            const SizedBox(height: AppTheme.space4),
            _buildSheetBreakdown(sheet),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetBreakdown(GlassSheetLayout sheet) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget usedPanel = _NumberedPanel(
          title: 'Used Pieces',
          icon: Icons.crop_square_rounded,
          rows: sheet.placements
              .asMap()
              .entries
              .map((entry) {
                final int index = entry.key;
                final GlassSheetPlacement piece = entry.value;
                final int number = piece.pieceNo > 0
                    ? piece.pieceNo
                    : index + 1;
                return _NumberedPanelRow(
                  badge: '$number',
                  text: piece.glassSizeDisplay,
                  helper: formatArea(piece.width * piece.height),
                  color: _GlassSheetPainter.colorForIndex(index),
                );
              })
              .toList(growable: false),
        );

        final Widget wastePanel = _NumberedPanel(
          title: 'Waste Pieces',
          icon: Icons.select_all_rounded,
          rows: sheet.wasteRects
              .map((GlassSheetWasteRect waste) {
                final int number = waste.wasteNo > 0 ? waste.wasteNo : 0;
                return _NumberedPanelRow(
                  badge: number > 0 ? 'W$number' : waste.id,
                  text: waste.sizeDisplay,
                  helper: formatArea(waste.area),
                  color: AppTheme.slate,
                );
              })
              .toList(growable: false),
          emptyText: 'No waste pieces',
        );

        if (constraints.maxWidth >= 620) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: usedPanel),
              const SizedBox(width: AppTheme.space4),
              Expanded(child: wastePanel),
            ],
          );
        }
        return Column(
          children: <Widget>[
            usedPanel,
            const SizedBox(height: AppTheme.space4),
            wastePanel,
          ],
        );
      },
    );
  }

  Widget _buildRejectedCard(GlassSheetOptimizationResult result) {
    return SectionSurfaceCard(
      title: 'Rejected Pieces',
      child: Column(
        children: result.rejectedPieces
            .map((GlassSheetPiece piece) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.warning_rounded,
                  color: AppTheme.danger,
                ),
                title: Text(piece.label.isEmpty ? piece.id : piece.label),
                subtitle: Text(piece.reason),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _GlassSheetPainter extends CustomPainter {
  final GlassSheetLayout sheet;

  _GlassSheetPainter(this.sheet);

  static const List<Color> _palette = <Color>[
    Color(0xFF2F6FED),
    AppTheme.tealAccent,
    AppTheme.amberAccent,
    AppTheme.success,
    Color(0xFF7B5CD6),
    AppTheme.danger,
  ];

  static Color colorForIndex(int index) => _palette[index % _palette.length];

  @override
  void paint(Canvas canvas, Size size) {
    final Paint sheetPaint = Paint()..color = AppTheme.surfaceAlt;
    final Paint borderPaint = Paint()
      ..color = AppTheme.inkBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final RRect sheetRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    canvas.drawRRect(sheetRect, sheetPaint);
    canvas.drawRRect(sheetRect, borderPaint);

    if (sheet.width <= 0 || sheet.height <= 0) {
      return;
    }

    final double scaleX = size.width / sheet.width;
    final double scaleY = size.height / sheet.height;
    for (final GlassSheetWasteRect waste in sheet.wasteRects) {
      final Rect rect = Rect.fromLTWH(
        waste.x * scaleX,
        waste.y * scaleY,
        math.max(1, waste.width * scaleX),
        math.max(1, waste.height * scaleY),
      ).deflate(1);
      final Paint wastePaint = Paint()..color = const Color(0xFFE7EDF2);
      canvas.drawRect(rect, wastePaint);
      canvas.drawRect(
        rect,
        Paint()
          ..color = AppTheme.slate.withValues(alpha: 0.34)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );
      if (rect.width >= 24 && rect.height >= 18) {
        _paintCenterText(
          canvas,
          rect,
          'W${waste.wasteNo}',
          AppTheme.slate,
          math.min(12, math.max(8, math.min(rect.width, rect.height) / 3)),
        );
      }
    }

    for (int index = 0; index < sheet.placements.length; index += 1) {
      final GlassSheetPlacement piece = sheet.placements[index];
      final Rect rect = Rect.fromLTWH(
        piece.x * scaleX,
        piece.y * scaleY,
        math.max(1, piece.width * scaleX),
        math.max(1, piece.height * scaleY),
      ).deflate(1);
      final Paint piecePaint = Paint()..color = colorForIndex(index);
      canvas.drawRect(rect, piecePaint);
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );

      final int pieceNo = piece.pieceNo > 0 ? piece.pieceNo : index + 1;
      if (rect.width >= 18 && rect.height >= 18) {
        _paintBadge(canvas, rect, '$pieceNo');
      }

      final String pieceText = piece.glassSizeDisplay.trim();
      if (pieceText.isEmpty || rect.width < 42 || rect.height < 30) {
        continue;
      }
      final double fontSize = math.max(
        6,
        math.min(
          10,
          math.min(
            rect.width / math.max(8, pieceText.length) * 1.55,
            rect.height / 3.2,
          ),
        ),
      );
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: pieceText,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        maxLines: 2,
        textDirection: TextDirection.ltr,
        ellipsis: '',
      )..layout(maxWidth: math.max(0, rect.width - 10));
      final double textY = rect.top + (rect.height - textPainter.height) / 2;
      textPainter.paint(canvas, Offset(rect.left + 5, textY));
    }
  }

  void _paintBadge(Canvas canvas, Rect rect, String text) {
    const double size = 20;
    final double resolvedSize = math.min(
      size,
      math.min(rect.width, rect.height) - 3,
    );
    if (resolvedSize < 12) {
      _paintCenterText(canvas, rect, text, Colors.white, 9);
      return;
    }
    final Rect badgeRect = Rect.fromLTWH(
      rect.left + 4,
      rect.top + 4,
      resolvedSize,
      resolvedSize,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, Radius.circular(resolvedSize / 2)),
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
    _paintCenterText(
      canvas,
      badgeRect,
      text,
      AppTheme.inkBlue,
      resolvedSize * 0.48,
    );
  }

  void _paintCenterText(
    Canvas canvas,
    Rect rect,
    String text,
    Color color,
    double fontSize,
  ) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: rect.width);
    textPainter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - textPainter.width) / 2,
        rect.top + (rect.height - textPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _GlassSheetPainter oldDelegate) {
    return oldDelegate.sheet != sheet;
  }
}

class _NumberedPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_NumberedPanelRow> rows;
  final String emptyText;

  const _NumberedPanel({
    required this.title,
    required this.icon,
    required this.rows,
    this.emptyText = 'No pieces',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space4),
      decoration: AppTheme.softPanelDecoration(radius: AppTheme.radiusSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 18, color: AppTheme.royalBlue),
              const SizedBox(width: AppTheme.space3),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _MiniCount(value: '${rows.length}'),
            ],
          ),
          const SizedBox(height: AppTheme.space3),
          if (rows.isEmpty)
            Text(
              emptyText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            ...rows,
        ],
      ),
    );
  }
}

class _NumberedPanelRow extends StatelessWidget {
  final String badge;
  final String text;
  final String helper;
  final Color color;

  const _NumberedPanelRow({
    required this.badge,
    required this.text,
    required this.helper,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.space3),
      child: Row(
        children: <Widget>[
          Container(
            constraints: const BoxConstraints(minWidth: 30),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space3,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.34)),
            ),
            child: Text(
              badge,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  text.isEmpty ? '--' : text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  helper,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniCount extends StatelessWidget {
  final String value;

  const _MiniCount({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.royalBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppTheme.royalBlue,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetaChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space4,
        vertical: AppTheme.space3,
      ),
      decoration: AppTheme.infoChipDecoration(emphasized: true),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
