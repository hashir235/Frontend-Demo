import 'package:flutter/material.dart';
import 'package:my_app/core/downloads/pdf_download_workflow.dart';

import '../../../core/theme/app_theme.dart';
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
  BillSnapshot? _snapshot;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? BillingRepository();
    _loadBill();
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


  Future<void> _downloadInvoicePdf() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      final String fileName = await PdfDownloadWorkflow.generateAndDownload(
        endpoint: '/api/pdf/invoice',
        payload: <String, Object?>{'projectId': widget.request.projectId},
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
                onTap: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Native share abhi wire nahi hui. Filhal Download PDF use karein.',
                      ),
                    ),
                  );
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
          child: FilledButton.icon(
            onPressed: _downloadInvoicePdf,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Download PDF'),
          ),
        ),
        const SizedBox(width: AppTheme.space4),
        FilledButton.tonalIcon(
          onPressed: _goHome,
          icon: const Icon(Icons.home_rounded),
          label: const Text('Home'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Final Bill')),
      bottomNavigationBar: _buildBottomActions(),
      body: AppScreenShell(child: _buildBody(context)),
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
          title: 'Billing summary prepared for issue',
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
        const SizedBox(height: AppTheme.space6),
        Row(
          children: <Widget>[
            Expanded(
              child: MetricCard(
                label: 'Grand Total',
                value: _formatNumber(snapshot.totals.grandTotal),
                icon: Icons.account_balance_wallet_rounded,
              ),
            ),
            const SizedBox(width: AppTheme.space4),
            Expanded(
              child: MetricCard(
                label: 'Remaining Due',
                value: _formatNumber(snapshot.totals.remainingDue),
                icon: Icons.payments_rounded,
                accent: AppTheme.tealAccent,
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
                value: '${_formatNumber(snapshot.totals.totalArea)} sq.ft',
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
              child: MetricCard(
                label: 'Before Discount',
                value: _formatNumber(snapshot.totals.aluminiumOriginal),
                icon: Icons.sell_outlined,
                accent: AppTheme.amberAccent,
              ),
            ),
            const SizedBox(width: AppTheme.space4),
            Expanded(
              child: MetricCard(
                label: 'After Discount',
                value: _formatNumber(snapshot.totals.aluminiumAfterDiscount),
                icon: Icons.local_offer_outlined,
                accent: AppTheme.royalBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space4),
        MetricCard(
          label: 'Net Amount / sq.ft',
          value: _formatNumber(_netAmountPerSqFt(snapshot)),
          icon: Icons.functions_rounded,
          accent: AppTheme.tealAccent,
        ),
        const SizedBox(height: AppTheme.space6),
        _buildDetailCard(
          context,
          title: 'Input Details',
          entries: <MapEntry<String, String>>[
            MapEntry<String, String>('Gage', _displayText(snapshot.gauge)),
            MapEntry<String, String>(
              'Aluminium Color',
              _displayText(snapshot.aluminiumColor),
            ),
            MapEntry<String, String>(
              'Glass Color',
              _displayText(snapshot.glassColor),
            ),
            MapEntry<String, String>(
              'Customer Name',
              _displayText(snapshot.customer.name),
            ),
            MapEntry<String, String>(
              'Phone',
              _displayText(snapshot.customer.phone),
            ),
            MapEntry<String, String>(
              'Address',
              _displayText(snapshot.customer.address),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space5),
        _buildDetailCard(
          context,
          title: 'Company / Workshop',
          entries: <MapEntry<String, String>>[
            MapEntry<String, String>(
              'Contractor Name',
              _displayText(snapshot.company.contractorName),
            ),
            MapEntry<String, String>(
              'Workshop Name',
              _displayText(snapshot.company.workshopName),
            ),
            MapEntry<String, String>(
              'Workshop Phone',
              _displayText(snapshot.company.workshopPhone),
            ),
            MapEntry<String, String>(
              'Workshop Address',
              _displayText(snapshot.company.workshopAddress),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space5),
        _buildDetailCard(
          context,
          title: 'Rates Used',
          entries: <MapEntry<String, String>>[
            MapEntry<String, String>(
              'Glass Rate / sq.ft',
              _formatNumber(snapshot.rates.glassPerSqFt),
            ),
            MapEntry<String, String>(
              'Labor Rate / sq.ft',
              _formatNumber(snapshot.rates.laborPerSqFt),
            ),
            MapEntry<String, String>(
              'Hardware Rate / window',
              _formatNumber(snapshot.rates.hardwarePerWindow),
            ),
            MapEntry<String, String>(
              'Aluminium Discount %',
              _formatNumber(snapshot.rates.aluminiumDiscountPercent),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space5),
        _buildDetailCard(
          context,
          title: 'Project Summary',
          entries: <MapEntry<String, String>>[
            MapEntry<String, String>(
              'Summary of Used Windows',
              '${snapshot.windowSummary.length}',
            ),
            MapEntry<String, String>(
              'Total Quantity',
              '${snapshot.totals.totalWindows}',
            ),
            MapEntry<String, String>(
              'Total Area',
              '${_formatNumber(snapshot.totals.totalArea)} sq.ft',
            ),
            MapEntry<String, String>(
              'Before Discount Amount',
              _formatNumber(snapshot.totals.aluminiumOriginal),
            ),
            MapEntry<String, String>(
              'Discount Amount',
              _formatNumber(snapshot.totals.aluminiumDiscount),
            ),
            MapEntry<String, String>(
              'After Discount Amount',
              _formatNumber(snapshot.totals.aluminiumAfterDiscount),
            ),
            MapEntry<String, String>(
              'Net Amount / sq.ft',
              _formatNumber(_netAmountPerSqFt(snapshot)),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space5),
        _buildDetailCard(
          context,
          title: 'Cost Breakdown',
          entries: <MapEntry<String, String>>[
            MapEntry<String, String>(
              'Glass Cost',
              _formatNumber(snapshot.totals.glassCost),
            ),
            MapEntry<String, String>(
              'Labor Cost',
              _formatNumber(snapshot.totals.laborCost),
            ),
            MapEntry<String, String>(
              'Hardware Cost',
              _formatNumber(snapshot.totals.hardwareCost),
            ),
            MapEntry<String, String>(
              'Before Discount Amount',
              _formatNumber(snapshot.totals.aluminiumOriginal),
            ),
            MapEntry<String, String>(
              'Discount Amount',
              _formatNumber(snapshot.totals.aluminiumDiscount),
            ),
            MapEntry<String, String>(
              'After Discount Amount',
              _formatNumber(snapshot.totals.aluminiumAfterDiscount),
            ),
            MapEntry<String, String>(
              'Extra Charges',
              _formatNumber(snapshot.totals.extraCharges),
            ),
            MapEntry<String, String>(
              'Advance Paid',
              _formatNumber(snapshot.totals.advancePaid),
            ),
            MapEntry<String, String>(
              'Grand Total',
              _formatNumber(snapshot.totals.grandTotal),
            ),
            MapEntry<String, String>(
              'Remaining Due',
              _formatNumber(snapshot.totals.remainingDue),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space5),
        _buildWindowSummaryCard(context, snapshot),
      ],
    );
  }

  Widget _buildDetailCard(
    BuildContext context, {
    required String title,
    required List<MapEntry<String, String>> entries,
  }) {
    return SectionSurfaceCard(
      title: title,
      child: Column(
        children: entries
            .map((MapEntry<String, String> entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.space3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        entry.key,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.space4),
                    Expanded(
                      child: Text(
                        entry.value,
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }

  Widget _buildWindowSummaryCard(BuildContext context, BillSnapshot snapshot) {
    return SectionSurfaceCard(
      title: 'Summary of Used Windows',
      subtitle:
          'Window type, quantity, and area totals from the backend billing snapshot.',
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space4,
              vertical: AppTheme.space3,
            ),
            decoration: BoxDecoration(
              color: AppTheme.royalBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: Text(
                    'Window',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Qty',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Area',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space3),
          ...snapshot.windowSummary.map((BillWindowSummary row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space3),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space4,
                  vertical: AppTheme.space4,
                ),
                decoration: AppTheme.softPanelDecoration(
                  radius: AppTheme.radiusMd,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      flex: 3,
                      child: Text(
                        _displayText(row.type),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${row.quantity}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${_formatNumber(row.areaSqFt)} sq.ft',
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
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






