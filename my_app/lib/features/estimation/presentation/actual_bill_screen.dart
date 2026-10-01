import 'package:flutter/material.dart';
import 'package:my_app/core/downloads/pdf_download_workflow.dart';

import '../../../core/theme/app_theme.dart';
import '../../flow_nav/models/flow_step.dart';
import '../../flow_nav/presentation/flow_progress_bar.dart';
import '../../tutorial/tutorial_controller.dart';
import '../../tutorial/tutorial_overlay.dart';
import '../../tutorial/tutorial_step.dart';
import '../../tutorial/tutorial_target.dart';
import '../../../shared/widgets/app_hero_header.dart';
import '../../../shared/widgets/app_screen_shell.dart';
import '../../../shared/widgets/bottom_action_bar.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/project_meta_strip.dart';
import '../../../shared/widgets/section_surface_card.dart';
import '../../../shared/widgets/state_message_card.dart';
import '../data/billing_repository.dart';
import '../models/bill_request.dart';
import '../models/bill_snapshot.dart';
import '../models/estimate_flow_state.dart';
import '../state/estimate_session_store.dart';
import '../state/invoice_print_choices.dart';
import '../../help_videos/tutorial_videos.dart';

/// One label/value line of a detail card. [figure] names it on the invoice
/// PDF when it prints there, which makes the line a print switch.
class _BillLine {
  final String label;
  final String value;
  final String? figure;

  const _BillLine(this.label, this.value, {this.figure});
}

/// A column of a figure table. The first column of a table is the name of
/// the row (window type, glass) and is never a switch.
class _FigureColumn {
  final String title;
  final int flex;
  final String? figure;

  const _FigureColumn(this.title, {this.flex = 2, this.figure});
}

class ActualBillScreen extends StatefulWidget {
  final EstimateSessionStore session;
  final BillRequest request;
  final BillingRepository? repository;

  const ActualBillScreen({
    super.key,
    required this.session,
    required this.request,
    this.repository,
  });

  @override
  State<ActualBillScreen> createState() => _ActualBillScreenState();
}

class _ActualBillScreenState extends State<ActualBillScreen> {
  late final BillingRepository _repository;
  final InvoicePrintChoices _print = InvoicePrintChoices.instance;
  BillSnapshot? _snapshot;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? BillingRepository();
    _print.addListener(_onPrintChoicesChanged);
    _loadBill();
  }

  @override
  void dispose() {
    _print.removeListener(_onPrintChoicesChanged);
    super.dispose();
  }

  void _onPrintChoicesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadBill() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final BillSnapshot snapshot = await _repository.estimateBill(
        widget.request,
      );
      if (!mounted) {
        return;
      }
      widget.session.setMaterialSelection(
        EstimateMaterialSelection(
          gaugeValue: snapshot.gauge,
          colorValue: snapshot.aluminiumColor,
        ),
      );
      widget.session.setBillDraft(
        EstimateBillDraft(
          glassRatePerSqFt: _formatNumber(snapshot.rates.glassPerSqFt),
          laborRatePerSqFt: _formatNumber(snapshot.rates.laborPerSqFt),
          hardwareRatePerWindow: _formatNumber(
            snapshot.rates.hardwarePerWindow,
          ),
          aluminiumDiscountPercent: _formatNumber(
            snapshot.rates.aluminiumDiscountPercent,
          ),
          extraCharges: _formatNumber(snapshot.totals.extraCharges),
          advancePaid: _formatNumber(snapshot.totals.advancePaid),
          glassColor: snapshot.glassColor,
          aluminiumCompany: snapshot.aluminiumCompany,
          customerName: snapshot.customer.name,
          customerPhone: snapshot.customer.phone,
          customerAddress: snapshot.customer.address,
        ),
      );
      setState(() {
        _snapshot = snapshot;
        _isLoading = false;
      });
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  /// The glass rows worth printing.
  ///
  /// A job entered before glass was picked per window comes back as one
  /// unnamed group; there is nothing to break out there, and a row reading
  /// "  · 240 sq.ft" would only look broken.
  static List<BillGlassSummary> _namedGlass(BillSnapshot snapshot) {
    return snapshot.glassSummary
        .where((BillGlassSummary row) => !row.isUnnamed)
        .toList(growable: false);
  }

  static String _formatArea(double value) => value.toStringAsFixed(1);

  static String _formatNumber(double value, {int decimals = 2}) {
    final String fixed = value.toStringAsFixed(decimals);
    if (!fixed.contains('.')) {
      return fixed;
    }
    return fixed
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _displayText(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? '--' : trimmed;
  }

  double _netAmountPerSqFt(BillSnapshot snapshot) {
    if (snapshot.totals.totalArea <= 0) {
      return 0;
    }
    return snapshot.totals.grandTotal / snapshot.totals.totalArea;
  }

  /// The figures this bill's PDF prints, by the same rules InvoicePDF.py
  /// uses: the window table when there are windows, the glass table when the
  /// glass is named, Other Charges and Advance Paid when not nothing, and
  /// Remaining Due only under an advance. Only these get a print switch, so
  /// a printer mark on the screen always means "this is on the PDF".
  static Set<String> _figuresOnBill(BillSnapshot snapshot) {
    final BillTotals totals = snapshot.totals;
    return <String>{
      if (snapshot.windowSummary.isNotEmpty) ...<String>{
        InvoiceFigure.windowQuantity,
        InvoiceFigure.windowArea,
        InvoiceFigure.windowHardwareRate,
        InvoiceFigure.windowHardwareCost,
      },
      if (_namedGlass(snapshot).isNotEmpty) ...<String>{
        InvoiceFigure.glassArea,
        InvoiceFigure.glassRate,
        InvoiceFigure.glassCost,
      },
      InvoiceFigure.totalGlassCost,
      InvoiceFigure.totalLaborCost,
      InvoiceFigure.totalHardwareCost,
      InvoiceFigure.aluminiumOriginal,
      InvoiceFigure.aluminiumDiscount,
      InvoiceFigure.aluminiumAfterDiscount,
      if (totals.extraCharges != 0) InvoiceFigure.extraCharges,
      if (totals.advancePaid != 0) InvoiceFigure.advancePaid,
      InvoiceFigure.grandTotal,
      if (totals.advancePaid != 0) InvoiceFigure.remainingDue,
    };
  }

  /// [figure] when this bill prints it, else null (no switch).
  static String? _onBill(BillSnapshot snapshot, String figure) =>
      _figuresOnBill(snapshot).contains(figure) ? figure : null;

  /// What goes with the PDF request: the figures switched off.
  Map<String, Object?> get _invoicePayload => <String, Object?>{
    'projectId': widget.request.projectId,
    'hiddenFigures': _print.hidden,
  };

  Future<void> _downloadInvoicePdf() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      final String fileName = await PdfDownloadWorkflow.generateAndDownload(
        endpoint: '/api/pdf/invoice',
        payload: _invoicePayload,
        generationFailureMessage: 'Unable to generate invoice PDF.',
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

  Future<void> _shareInvoicePdf() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      final String fileName = await PdfDownloadWorkflow.generateAndShare(
        endpoint: '/api/pdf/invoice',
        payload: _invoicePayload,
        generationFailureMessage: 'Unable to generate invoice PDF.',
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

  Future<void> _showShareOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text('Download PDF'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _downloadInvoicePdf();
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share PDF'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _shareInvoicePdf();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _goHome() {
    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
  }

  Widget? _buildBottomActions() {
    if (_isLoading || _errorMessage != null || _snapshot == null) {
      return null;
    }

    return BottomActionBar(
      children: <Widget>[
        Expanded(
          child: TutorialTarget(
            id: 'bill.downloadPdf',
            child: FilledButton.icon(
              onPressed: () {
                TutorialController.instance.advanceAfterTap();
                _downloadInvoicePdf();
              },
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download PDF'),
            ),
          ),
        ),
        const SizedBox(width: AppTheme.space4),
        TutorialTarget(
          id: 'bill.home',
          child: FilledButton.tonalIcon(
            onPressed: () {
              // Ending the tour here: the Home screen below is still mounted
              // and would otherwise try to resume it at an earlier step.
              TutorialController.instance.finish();
              _goHome();
            },
            icon: const Icon(Icons.home_rounded),
            label: const Text('Home'),
          ),
        ),
        const SizedBox(width: AppTheme.space4),
        IconButton.filledTonal(
          tooltip: 'Share',
          onPressed: _showShareOptions,
          icon: const Icon(Icons.share_outlined),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Wraps the Scaffold: the tour ends on the Download PDF and Home buttons,
    // which live in the bottom bar rather than the body.
    return TutorialOverlay(
      screen: TutorialScreen.actualBill,
      child: Scaffold(
        appBar: AppBar(title: const Text('Final Bill')),
        bottomNavigationBar: FlowBottomBar(
          stepId: FlowSteps.invoice.id,
          actions: _buildBottomActions(),
        ),
        body: AppScreenShell(child: _buildBody(context)),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: StateMessageCard(
          icon: Icons.receipt_long_rounded,
          title: 'Bill generation failed',
          message: _errorMessage,
          iconColor: AppTheme.danger,
          action: FilledButton.icon(
            onPressed: _loadBill,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ),
      );
    }

    final BillSnapshot? snapshot = _snapshot;
    if (snapshot == null) {
      return const Center(
        child: StateMessageCard(
          icon: Icons.receipt_long_rounded,
          title: 'No bill data found',
        ),
      );
    }

    return ListView(
      children: <Widget>[
        const AppHeroHeader(
          eyebrow: 'FINAL BILL',
          title: 'Final Bill',
          videoKey: TutorialVideos.estimationFinalBill,
          subtitle:
              'Review the full cost breakdown, workshop details, and totals before downloading the invoice PDF.',
        ),
        const SizedBox(height: AppTheme.space5),
        ProjectMetaStrip(
          projectName: snapshot.project.name,
          projectLocation: snapshot.project.location,
          extras: <Widget>[
            _MetaChip(label: 'Gage', value: _displayText(snapshot.gauge)),
            _MetaChip(
              label: 'Aluminium',
              value: _displayText(snapshot.aluminiumColor),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space5),
        _buildPrintHint(context, snapshot),
        const SizedBox(height: AppTheme.space5),
        Row(
          children: <Widget>[
            Expanded(
              child: TutorialTarget(
                id: 'bill.grandTotal',
                child: _printSwitchCard(
                  _onBill(snapshot, InvoiceFigure.grandTotal),
                  MetricCard(
                    label: 'Grand Total',
                    value: _formatNumber(snapshot.totals.grandTotal),
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.space4),
            Expanded(
              child: TutorialTarget(
                id: 'bill.remainingDue',
                child: _printSwitchCard(
                  _onBill(snapshot, InvoiceFigure.remainingDue),
                  MetricCard(
                    label: 'Remaining Due',
                    value: _formatNumber(snapshot.totals.remainingDue),
                    icon: Icons.payments_rounded,
                    accent: AppTheme.tealAccent,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space4),
        Row(
          children: <Widget>[
            Expanded(
              child: MetricCard(
                label: 'Total Windows',
                value: '${snapshot.totals.totalWindows}',
                icon: Icons.grid_view_rounded,
                accent: AppTheme.amberAccent,
              ),
            ),
            const SizedBox(width: AppTheme.space4),
            Expanded(
              child: MetricCard(
                label: 'Total Area',
                value: '${_formatNumber(snapshot.totals.totalArea)} ${snapshot.areaUnit}',
                icon: Icons.square_foot_rounded,
                accent: AppTheme.tealAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space4),
        Row(
          children: <Widget>[
            Expanded(
              child: _printSwitchCard(
                _onBill(snapshot, InvoiceFigure.aluminiumOriginal),
                MetricCard(
                  label: 'Before Discount',
                  value: _formatNumber(snapshot.totals.aluminiumOriginal),
                  icon: Icons.sell_outlined,
                  accent: AppTheme.amberAccent,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.space4),
            Expanded(
              child: _printSwitchCard(
                _onBill(snapshot, InvoiceFigure.aluminiumAfterDiscount),
                MetricCard(
                  label: 'After Discount',
                  value: _formatNumber(snapshot.totals.aluminiumAfterDiscount),
                  icon: Icons.local_offer_outlined,
                  accent: AppTheme.royalBlue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space4),
        MetricCard(
          label: 'Net Amount / ${snapshot.areaUnit}',
          value: _formatNumber(_netAmountPerSqFt(snapshot)),
          icon: Icons.functions_rounded,
          accent: AppTheme.tealAccent,
        ),
        const SizedBox(height: AppTheme.space6),
        _buildDetailCard(
          context,
          title: 'Input Details',
          tourId: 'bill.inputDetails',
          lines: <_BillLine>[
            _BillLine('Gage', _displayText(snapshot.gauge)),
            _BillLine('Aluminium Color', _displayText(snapshot.aluminiumColor)),
            _BillLine('Glass Color', _displayText(snapshot.glassColor)),
            _BillLine(
              'Aluminium Company',
              _displayText(snapshot.aluminiumCompany),
            ),
            _BillLine('Customer Name', _displayText(snapshot.customer.name)),
            _BillLine('Phone', _displayText(snapshot.customer.phone)),
            _BillLine('Address', _displayText(snapshot.customer.address)),
          ],
        ),
        const SizedBox(height: AppTheme.space5),
        _buildDetailCard(
          context,
          title: 'Company / Workshop',
          // Not 'bill.company' -- that id belongs to the Aluminium Company
          // field on Bill Inputs, which is still mounted underneath this
          // screen and would fight over the same registration.
          tourId: 'bill.companyCard',
          lines: <_BillLine>[
            _BillLine(
              'Contractor Name',
              _displayText(snapshot.company.contractorName),
            ),
            _BillLine(
              'Workshop Name',
              _displayText(snapshot.company.workshopName),
            ),
            _BillLine(
              'Workshop Phone',
              _displayText(snapshot.company.workshopPhone),
            ),
            _BillLine(
              'Workshop Address',
              _displayText(snapshot.company.workshopAddress),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space5),
        _buildDetailCard(
          context,
          title: 'Rates Used',
          tourId: 'bill.ratesUsed',
          lines: <_BillLine>[
            _BillLine(
              'Glass Rate / ${snapshot.areaUnit}',
              _formatNumber(snapshot.rates.glassPerSqFt),
            ),
            _BillLine(
              'Labor Rate / ${snapshot.areaUnit}',
              _formatNumber(snapshot.rates.laborPerSqFt),
            ),
            _BillLine(
              'Hardware Rate / window',
              _formatNumber(snapshot.rates.hardwarePerWindow),
            ),
            _BillLine(
              'Aluminium Discount %',
              _formatNumber(snapshot.rates.aluminiumDiscountPercent),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space5),
        _buildDetailCard(
          context,
          title: 'Project Summary',
          lines: <_BillLine>[
            _BillLine(
              'Summary of Used Windows',
              '${snapshot.windowSummary.length}',
            ),
            _BillLine('Total Quantity', '${snapshot.totals.totalWindows}'),
            _BillLine(
              'Total Area',
              '${_formatNumber(snapshot.totals.totalArea)} ${snapshot.areaUnit}',
            ),
            _BillLine(
              'Before Discount Amount',
              _formatNumber(snapshot.totals.aluminiumOriginal),
              figure: _onBill(snapshot, InvoiceFigure.aluminiumOriginal),
            ),
            _BillLine(
              'Discount Amount',
              _formatNumber(snapshot.totals.aluminiumDiscount),
              figure: _onBill(snapshot, InvoiceFigure.aluminiumDiscount),
            ),
            _BillLine(
              'After Discount Amount',
              _formatNumber(snapshot.totals.aluminiumAfterDiscount),
              figure: _onBill(snapshot, InvoiceFigure.aluminiumAfterDiscount),
            ),
            _BillLine(
              'Net Amount / ${snapshot.areaUnit}',
              _formatNumber(_netAmountPerSqFt(snapshot)),
            ),
          ],
        ),
        // Glazing and ironmongery, line by line, before the totals that add
        // them up. Both are figures a customer questions, and "which windows
        // is this for" and "which glass at what rate" are the questions. One
        // lump labelled Glass Cost cannot answer either.
        if (_namedGlass(snapshot).isNotEmpty) ...<Widget>[
          const SizedBox(height: AppTheme.space5),
          SectionSurfaceCard(
            title: 'Glass by Color',
            child: _buildFigureTable(
              context,
              snapshot,
              columns: const <_FigureColumn>[
                _FigureColumn('Glass', flex: 3),
                _FigureColumn('Area', flex: 3, figure: InvoiceFigure.glassArea),
                _FigureColumn('Rate', figure: InvoiceFigure.glassRate),
                _FigureColumn('Cost', flex: 3, figure: InvoiceFigure.glassCost),
              ],
              rows: <List<String>>[
                for (final BillGlassSummary row in _namedGlass(snapshot))
                  <String>[
                    row.color,
                    '${_formatArea(row.areaSqFt)} ${snapshot.areaUnit}',
                    _formatNumber(row.rate),
                    _formatNumber(row.cost),
                  ],
              ],
            ),
          ),
        ],
        // Shown for a single window type too: the PDF's window table carries
        // the hardware rate and cost columns either way, and this is where
        // they are switched.
        if (snapshot.windowSummary.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppTheme.space5),
          SectionSurfaceCard(
            title: 'Hardware by Window',
            child: _buildFigureTable(
              context,
              snapshot,
              columns: const <_FigureColumn>[
                _FigureColumn('Window', flex: 3),
                _FigureColumn(
                  'H/W Rate',
                  flex: 3,
                  figure: InvoiceFigure.windowHardwareRate,
                ),
                _FigureColumn(
                  'H/W Cost',
                  flex: 3,
                  figure: InvoiceFigure.windowHardwareCost,
                ),
              ],
              rows: <List<String>>[
                for (final BillWindowSummary row in snapshot.windowSummary)
                  <String>[
                    _displayText(row.type),
                    _formatNumber(row.hardwareRate),
                    _formatNumber(row.hardwareCost),
                  ],
              ],
            ),
          ),
        ],
        const SizedBox(height: AppTheme.space5),
        _buildDetailCard(
          context,
          title: 'Cost Breakdown',
          tourId: 'bill.costBreakdown',
          lines: <_BillLine>[
            _BillLine(
              'Glass Cost',
              _formatNumber(snapshot.totals.glassCost),
              figure: _onBill(snapshot, InvoiceFigure.totalGlassCost),
            ),
            _BillLine(
              'Labor Cost',
              _formatNumber(snapshot.totals.laborCost),
              figure: _onBill(snapshot, InvoiceFigure.totalLaborCost),
            ),
            _BillLine(
              'Hardware Cost',
              _formatNumber(snapshot.totals.hardwareCost),
              figure: _onBill(snapshot, InvoiceFigure.totalHardwareCost),
            ),
            _BillLine(
              'Before Discount Amount',
              _formatNumber(snapshot.totals.aluminiumOriginal),
              figure: _onBill(snapshot, InvoiceFigure.aluminiumOriginal),
            ),
            _BillLine(
              'Discount Amount',
              _formatNumber(snapshot.totals.aluminiumDiscount),
              figure: _onBill(snapshot, InvoiceFigure.aluminiumDiscount),
            ),
            _BillLine(
              'After Discount Amount',
              _formatNumber(snapshot.totals.aluminiumAfterDiscount),
              figure: _onBill(snapshot, InvoiceFigure.aluminiumAfterDiscount),
            ),
            _BillLine(
              'Extra Charges',
              _formatNumber(snapshot.totals.extraCharges),
              figure: _onBill(snapshot, InvoiceFigure.extraCharges),
            ),
            _BillLine(
              'Advance Paid',
              _formatNumber(snapshot.totals.advancePaid),
              figure: _onBill(snapshot, InvoiceFigure.advancePaid),
            ),
            _BillLine(
              'Grand Total',
              _formatNumber(snapshot.totals.grandTotal),
              figure: _onBill(snapshot, InvoiceFigure.grandTotal),
            ),
            _BillLine(
              'Remaining Due',
              _formatNumber(snapshot.totals.remainingDue),
              figure: _onBill(snapshot, InvoiceFigure.remainingDue),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space5),
        _buildWindowSummaryCard(context, snapshot),
      ],
    );
  }

  /// How the screen says which figures go on the PDF, and how many of this
  /// bill's are switched off -- with one tap to put them all back.
  Widget _buildPrintHint(BuildContext context, BillSnapshot snapshot) {
    final int off = _figuresOnBill(
      snapshot,
    ).where((String figure) => !_print.prints(figure)).length;
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space4,
        AppTheme.space4,
        AppTheme.space3,
        AppTheme.space4,
      ),
      decoration: AppTheme.softPanelDecoration(radius: AppTheme.radiusMd),
      child: Row(
        children: <Widget>[
          const Icon(Icons.print_rounded, size: 22, color: AppTheme.royalBlue),
          const SizedBox(width: AppTheme.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Figures with a printer mark go on the PDF bill. Tap one to '
                  'leave it off: it dims, and stays off on your next bills too '
                  'until you tap it again.',
                  style: text.bodySmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (off > 0) ...<Widget>[
                  const SizedBox(height: AppTheme.space2),
                  Text(
                    off == 1
                        ? '1 figure is off the PDF'
                        : '$off figures are off the PDF',
                    style: text.bodySmall?.copyWith(
                      color: AppTheme.warning,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (off > 0)
            TextButton(
              onPressed: () {
                _print.printAll();
              },
              child: const Text('Print all'),
            ),
        ],
      ),
    );
  }

  /// The printer mark: on the PDF, or switched off.
  static Widget _printMark(bool prints) {
    return Icon(
      prints ? Icons.print_rounded : Icons.print_disabled_outlined,
      size: 18,
      color: prints ? AppTheme.royalBlue : AppTheme.textSecondary,
      semanticLabel: prints ? 'Prints on PDF' : 'Off the PDF',
    );
  }

  /// [child] as the print switch for [figure]: a tap leaves the figure off
  /// the PDF (dimmed here) or puts it back. Saved there and then.
  Widget _printSwitch(
    String figure, {
    required Widget child,
    BorderRadius? radius,
  }) {
    final bool prints = _print.prints(figure);
    return Semantics(
      toggled: prints,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius ?? BorderRadius.circular(AppTheme.radiusSm),
          onTap: () {
            _print.toggle(figure);
          },
          child: AnimatedOpacity(
            opacity: prints ? 1 : _dimmedOpacity,
            duration: const Duration(milliseconds: 150),
            child: child,
          ),
        ),
      ),
    );
  }

  static const double _dimmedOpacity = 0.35;

  /// A metric card as a print switch, with the mark in its corner. [figure]
  /// null: the figure is not on the PDF, and the card stays as it was.
  Widget _printSwitchCard(String? figure, Widget card) {
    if (figure == null) {
      return card;
    }
    return _printSwitch(
      figure,
      radius: BorderRadius.circular(AppTheme.radiusMd),
      // Passthrough: the card keeps the full width its row gives it. A loose
      // Stack would let it shrink to its text.
      child: Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          card,
          Positioned(
            top: AppTheme.space4,
            right: AppTheme.space4,
            child: _printMark(_print.prints(figure)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(
    BuildContext context, {
    required String title,
    required List<_BillLine> lines,
    // The tour walks card by card, so each one it explains carries an id.
    String? tourId,
  }) {
    if (tourId != null) {
      return TutorialTarget(
        id: tourId,
        child: _buildDetailCardBody(context, title: title, lines: lines),
      );
    }
    return _buildDetailCardBody(context, title: title, lines: lines);
  }

  Widget _buildDetailCardBody(
    BuildContext context, {
    required String title,
    required List<_BillLine> lines,
  }) {
    // Where any line is a switch, every line keeps room for the mark, so the
    // figures still stand in one column.
    final bool marks = lines.any((_BillLine line) => line.figure != null);
    return SectionSurfaceCard(
      title: title,
      child: Column(
        children: lines
            .map((_BillLine line) => _buildLine(context, line, marks: marks))
            .toList(growable: false),
      ),
    );
  }

  Widget _buildLine(
    BuildContext context,
    _BillLine line, {
    required bool marks,
  }) {
    final String? figure = line.figure;
    final bool prints = figure == null || _print.prints(figure);
    final TextStyle? valueStyle = Theme.of(context).textTheme.bodyLarge
        ?.copyWith(fontWeight: FontWeight.w700);
    final Widget row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            line.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: AppTheme.space4),
        Expanded(
          child: Text(
            line.value,
            textAlign: TextAlign.right,
            style: prints
                ? valueStyle
                : valueStyle?.copyWith(decoration: TextDecoration.lineThrough),
          ),
        ),
        if (marks) ...<Widget>[
          const SizedBox(width: AppTheme.space3),
          SizedBox(width: 18, child: figure == null ? null : _printMark(prints)),
        ],
      ],
    );
    if (!marks) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.space3),
        child: row,
      );
    }
    final Widget spaced = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space2),
      child: row,
    );
    return figure == null ? spaced : _printSwitch(figure, child: spaced);
  }

  /// A table whose figure columns are print switches, the way the PDF's
  /// tables are: tap a heading, or any figure under it, and that column
  /// leaves the PDF for every row (dimmed here). The first column is the
  /// row's name and always prints.
  Widget _buildFigureTable(
    BuildContext context,
    BillSnapshot snapshot, {
    required List<_FigureColumn> columns,
    required List<List<String>> rows,
  }) {
    final Set<String> onBill = _figuresOnBill(snapshot);
    final TextStyle? headStyle = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.w900);
    final TextStyle? cellStyle = Theme.of(context).textTheme.bodyLarge
        ?.copyWith(fontWeight: FontWeight.w800, color: AppTheme.textPrimary);

    Widget cell(int index, String value, {required bool heading}) {
      final _FigureColumn column = columns[index];
      final TextStyle? style = heading ? headStyle : cellStyle;
      if (index == 0) {
        return Expanded(
          flex: column.flex,
          child: Text(value, style: style),
        );
      }
      final String? figure =
          column.figure != null && onBill.contains(column.figure)
          ? column.figure
          : null;
      final bool prints = figure == null || _print.prints(figure);
      final Widget content = FittedBox(
        fit: BoxFit.scaleDown,
        child: heading && figure != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    prints ? Icons.print_rounded : Icons.print_disabled_outlined,
                    size: 14,
                    color: prints ? AppTheme.royalBlue : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 3),
                  Text(value, style: style),
                ],
              )
            : Text(
                value,
                style: prints
                    ? style
                    : style?.copyWith(decoration: TextDecoration.lineThrough),
              ),
      );
      final Widget padded = Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space2,
          vertical: AppTheme.space2,
        ),
        child: Center(child: content),
      );
      return Expanded(
        flex: column.flex,
        child: figure == null ? padded : _printSwitch(figure, child: padded),
      );
    }

    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space4,
            vertical: AppTheme.space2,
          ),
          decoration: BoxDecoration(
            color: AppTheme.royalBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Row(
            children: <Widget>[
              for (int i = 0; i < columns.length; i++)
                cell(i, columns[i].title, heading: true),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.space3),
        for (final List<String> row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.space3),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space4,
                vertical: AppTheme.space3,
              ),
              decoration: AppTheme.softPanelDecoration(
                radius: AppTheme.radiusMd,
              ),
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < columns.length; i++)
                    cell(i, row[i], heading: false),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWindowSummaryCard(BuildContext context, BillSnapshot snapshot) {
    return SectionSurfaceCard(
      title: 'Summary of Used Windows',
      subtitle:
          'Window type, quantity, and area totals from the backend billing snapshot.',
      child: _buildFigureTable(
        context,
        snapshot,
        columns: const <_FigureColumn>[
          _FigureColumn('Window', flex: 3),
          _FigureColumn('Qty', figure: InvoiceFigure.windowQuantity),
          _FigureColumn('Area', flex: 3, figure: InvoiceFigure.windowArea),
        ],
        rows: <List<String>>[
          for (final BillWindowSummary row in snapshot.windowSummary)
            <String>[
              _displayText(row.type),
              '${row.quantity}',
              '${_formatNumber(row.areaSqFt)} ${snapshot.areaUnit}',
            ],
        ],
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
