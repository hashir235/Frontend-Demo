import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/theme/app_theme.dart';
import '../data/billing_repository.dart';
import '../models/bill_request.dart';
import '../models/bill_snapshot.dart';

class ActualBillScreen extends StatefulWidget {
  final BillRequest request;
  final BillingRepository? repository;

  const ActualBillScreen({
    super.key,
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
      final BillSnapshot snapshot = await _repository.estimateBill(widget.request);
      if (!mounted) {
        return;
      }
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

  String _apiBaseUrl() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://127.0.0.1:8080';
  }

  Future<void> _generateInvoicePdf({
    String successMessage = 'Invoice PDF generated.',
  }) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      final http.Response response = await http.post(
        Uri.parse('${_apiBaseUrl()}/api/pdf/invoice'),
        headers: const <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(const <String, Object?>{}),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Unable to generate invoice PDF.')),
        );
        return;
      }

      String resolvedMessage = successMessage;
      try {
        final Object? decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final String? fileName = decoded['fileName'] as String?;
          if (fileName != null && fileName.isNotEmpty) {
            resolvedMessage = 'PDF ready: $fileName';
          }
        }
      } on FormatException {
        // Keep fallback.
      }

      messenger.showSnackBar(SnackBar(content: Text(resolvedMessage)));
    } on Exception {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to reach local PDF service.')),
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
                  await _generateInvoicePdf(
                    successMessage: 'Invoice PDF generated in local downloads.',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share PDF'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _generateInvoicePdf(
                    successMessage:
                        'Invoice PDF generated. Native share can be wired next.',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget? _buildBottomActions() {
    if (_isLoading || _errorMessage != null || _snapshot == null) {
      return null;
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AppTheme.sky.withValues(alpha: 0.7)),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppTheme.deepTeal.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                onPressed: _generateInvoicePdf,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download PDF'),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filledTonal(
              tooltip: 'Share',
              onPressed: _showShareOptions,
              icon: const Icon(Icons.share_outlined),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Final Bill'),
      ),
      bottomNavigationBar: _buildBottomActions(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              AppTheme.ice,
              AppTheme.sky.withValues(alpha: 0.42),
              AppTheme.mist,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Calculating actual bill...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadBill,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final BillSnapshot? snapshot = _snapshot;
    if (snapshot == null) {
      return const Center(child: Text('No bill data found.'));
    }

    return _buildShell(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        children: <Widget>[
          _buildHeaderCard(context, snapshot),
          const SizedBox(height: 16),
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
              MapEntry<String, String>('Phone', _displayText(snapshot.customer.phone)),
              MapEntry<String, String>(
                'Address',
                _displayText(snapshot.customer.address),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          _buildDetailCard(
            context,
            title: 'Project Summary',
            entries: <MapEntry<String, String>>[
              MapEntry<String, String>(
                'Project Name',
                _displayText(snapshot.project.name),
              ),
              MapEntry<String, String>(
                'Project Location',
                _displayText(snapshot.project.location),
              ),
              MapEntry<String, String>(
                'Total Windows',
                '${snapshot.totals.totalWindows}',
              ),
              MapEntry<String, String>(
                'Total Area',
                '${_formatNumber(snapshot.totals.totalArea)} sq.ft',
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                'Aluminium Original',
                _formatNumber(snapshot.totals.aluminiumOriginal),
              ),
              MapEntry<String, String>(
                'Aluminium Discount',
                _formatNumber(snapshot.totals.aluminiumDiscount),
              ),
              MapEntry<String, String>(
                'Aluminium After Discount',
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
          const SizedBox(height: 12),
          _buildWindowSummaryCard(context, snapshot),
        ],
      ),
    );
  }

  Widget _buildShell({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.sky.withValues(alpha: 0.8)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppTheme.deepTeal.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildHeaderCard(BuildContext context, BillSnapshot snapshot) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: <Color>[
            AppTheme.violet.withValues(alpha: 0.12),
            AppTheme.sky.withValues(alpha: 0.14),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: <Widget>[
          _InfoPill(label: 'Grand Total', value: _formatNumber(snapshot.totals.grandTotal)),
          _InfoPill(
            label: 'Remaining Due',
            value: _formatNumber(snapshot.totals.remainingDue),
          ),
          _InfoPill(
            label: 'Windows',
            value: '${snapshot.totals.totalWindows}',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(
    BuildContext context, {
    required String title,
    required List<MapEntry<String, String>> entries,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.mist.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.sky.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.deepTeal,
            ),
          ),
          const SizedBox(height: 12),
          ...entries.map(
            (MapEntry<String, String> entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      entry.key,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.deepTeal.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.value,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.deepTeal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWindowSummaryCard(BuildContext context, BillSnapshot snapshot) {
    if (snapshot.windowSummary.isEmpty) {
      return _buildDetailCard(
        context,
        title: 'Window Summary',
        entries: const <MapEntry<String, String>>[
          MapEntry<String, String>('Details', '--'),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.mist.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.sky.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Window Summary',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.deepTeal,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                AppTheme.deepTeal.withValues(alpha: 0.08),
              ),
              columns: const <DataColumn>[
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Qty')),
                DataColumn(label: Text('Area (sq.ft)')),
              ],
              rows: snapshot.windowSummary
                  .map(
                    (BillWindowSummary row) => DataRow(
                      cells: <DataCell>[
                        DataCell(Text(row.type, style: _tableValueTextStyle(context))),
                        DataCell(
                          Text('${row.quantity}', style: _tableValueTextStyle(context)),
                        ),
                        DataCell(
                          Text(
                            _formatNumber(row.areaSqFt),
                            style: _tableValueTextStyle(context),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle? _tableValueTextStyle(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: AppTheme.deepTeal,
      fontWeight: FontWeight.w700,
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final String value;

  const _InfoPill({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sky.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.deepTeal.withValues(alpha: 0.66),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.deepTeal,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
