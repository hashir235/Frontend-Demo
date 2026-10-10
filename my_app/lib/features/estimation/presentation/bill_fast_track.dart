import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../flow_nav/models/flow_step.dart';
import '../data/cost_table_api_client.dart';
import '../data/optimization_repository.dart';
import '../data/rate_review_api_client.dart';
import '../models/cost_table.dart';
import '../models/cutting_report.dart';
import '../models/estimate_flow_state.dart';
import '../models/rate_review.dart';
import '../models/window_material.dart';
import '../models/window_review_item.dart';
import '../state/estimate_session_store.dart';
import 'bill_inputs_screen.dart';
import 'estimation_material_table_screen.dart';
import 'length_optimization_screen.dart';
import 'rate_review_screen.dart';

/// Review's Next, on an estimate: straight to Bill Inputs (Hashir, Oct 2026).
///
/// Nothing in between is skipped. The cutting lengths, the rates and the
/// material table are all worked out exactly as stepping through them would
/// -- the same requests, in the same order, with the rates the rate screen
/// would have sent on -- while a small card says which one is running. Then
/// the three screens are put under Bill Inputs already filled, so the bubbles
/// at the bottom (or the back button) open any of them as it stands.
///
/// When a step fails, or has nothing to show, the run stops there and that
/// screen is the one that opens: it says what went wrong and has its own
/// Retry, as it always had.
Future<void> openBillInputsFromReview(
  BuildContext context, {
  required EstimateSessionStore session,
  required List<WindowReviewItem> items,
  required String? projectId,
  OptimizationRepository? optimization,
  RateReviewApiClient? rates,
  CostTableApiClient? costs,
}) async {
  final NavigatorState navigator = Navigator.of(context);
  final NavigatorState dialogNavigator = Navigator.of(
    context,
    rootNavigator: true,
  );
  final ValueNotifier<int> stage = ValueNotifier<int>(0);
  bool cancelled = false;
  bool dialogOpen = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) => PopScope(
      canPop: false,
      child: _PreparingBillDialog(
        stage: stage,
        onCancel: () {
          cancelled = true;
          Navigator.of(dialogContext).pop();
        },
      ),
    ),
  ).whenComplete(() => dialogOpen = false);

  final OptimizationRepository optimizer =
      optimization ?? OptimizationRepository();
  final RateReviewApiClient rateClient = rates ?? RateReviewApiClient();
  final CostTableApiClient costClient = costs ?? CostTableApiClient();

  // The pair the rate screen opens on, as Length Optimization hands it over.
  final WindowMaterial material = session.representativeMaterial;
  final String gaugeLabel = material.gauge;
  final String colorLabel = AluminiumColors.labelFor(material.color);
  const String flowContext = 'estimation';

  CuttingReport? report;
  RateReview? review;
  CostTable? table;
  List<RateOverrideInput> overrides = const <RateOverrideInput>[];
  try {
    report = await optimizer.fetchLengthOptimization(
      items,
      projectId: projectId,
      context: flowContext,
      projectName: session.projectName,
      projectLocation: session.projectLocation,
    );
    if (!cancelled && report.ok && report.sections.isNotEmpty) {
      stage.value = 1;
      // What the rate screen does as it opens: a different stock from last
      // time clears the rates kept for the old one.
      session.setMaterialSelection(
        EstimateMaterialSelection(
          gaugeValue: material.gauge,
          colorValue: material.color,
        ),
      );
      review = await rateClient.fetchRateReview(
        gauge: material.gauge,
        color: material.color,
        projectId: projectId,
        context: flowContext,
      );
      if (!cancelled && review.rows.isNotEmpty) {
        stage.value = 2;
        // What its Next sends on, nothing changed.
        overrides = rateOverridesAsShown(review, session.rateOverrides);
        session.setRateOverrides(overrides);
        table = await costClient.fetchCostTable(
          gauge: material.gauge,
          color: material.color,
          projectId: projectId,
          context: flowContext,
          overrides: overrides,
        );
        stage.value = 3;
      }
    }
  } catch (_) {
    // The screen the run stopped at fetches again and shows why.
  }

  // Not disposed: the card is still fading out, and listening, as this runs.
  if (dialogOpen) dialogNavigator.pop();
  if (cancelled || !navigator.mounted) return;

  final List<(String, Widget)> screens = <(String, Widget)>[
    (
      FlowSteps.lengthOptimization.id,
      LengthOptimizationScreen(
        session: session,
        items: items,
        projectId: projectId,
        projectName: session.projectName,
        projectLocation: session.projectLocation,
        requestContext: flowContext,
        repository: optimization,
        initialReport: report,
      ),
    ),
    if (report != null && report.ok && report.sections.isNotEmpty)
      (
        FlowSteps.rates.id,
        RateReviewScreen(
          session: session,
          gaugeLabel: gaugeLabel,
          gaugeValue: material.gauge,
          colorLabel: colorLabel,
          colorValue: material.color,
          projectId: projectId,
          projectName: session.projectName,
          projectLocation: session.projectLocation,
          requestContext: flowContext,
          apiClient: rates,
          costTableApiClient: costs,
          initialReview: review,
        ),
      ),
    if (review != null && review.rows.isNotEmpty)
      (
        FlowSteps.material.id,
        EstimationMaterialTableScreen(
          session: session,
          gaugeLabel: gaugeLabel,
          gaugeValue: material.gauge,
          colorLabel: colorLabel,
          colorValue: material.color,
          projectId: projectId,
          requestContext: flowContext,
          projectName: session.projectName,
          projectLocation: session.projectLocation,
          overrides: overrides,
          apiClient: costs,
          initialTable: table,
        ),
      ),
    if (table != null)
      (
        FlowSteps.billInputs.id,
        BillInputsScreen(
          session: session,
          aluminiumTotal: table.grandTotal,
          glassAreas: table.glassAreas,
          areaUnit: table.areaUnit,
          gaugeLabel: gaugeLabel,
          gaugeValue: material.gauge,
          colorLabel: colorLabel,
          colorValue: material.color,
          projectId: projectId,
          projectName: session.projectName,
          projectLocation: session.projectLocation,
        ),
      ),
  ];

  // Every screen but the last arrives already covered, so it appears at
  // once; only the one the shop lands on slides in. Going back from any of
  // them slides as usual.
  for (int i = 0; i < screens.length; i++) {
    final (String step, Widget screen) = screens[i];
    final RouteSettings settings = RouteSettings(name: step);
    navigator.push(
      i == screens.length - 1
          ? MaterialPageRoute<void>(settings: settings, builder: (_) => screen)
          : _ArrivedRoute<void>(settings: settings, builder: (_) => screen),
    );
  }
}

/// A page that is already there when the one above it slides in.
class _ArrivedRoute<T> extends MaterialPageRoute<T> {
  _ArrivedRoute({required super.builder, required super.settings});

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);
}

/// Which of the three steps is being worked out, while the shop waits.
class _PreparingBillDialog extends StatelessWidget {
  final ValueListenable<int> stage;
  final VoidCallback onCancel;

  const _PreparingBillDialog({required this.stage, required this.onCancel});

  static const List<String> _steps = <String>[
    'Cutting lengths',
    'Rates',
    'Material summary',
  ];

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return AlertDialog(
      key: const Key('preparing_bill_dialog'),
      title: const Text('Preparing your bill'),
      content: ValueListenableBuilder<int>(
        valueListenable: stage,
        builder: (BuildContext context, int current, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int i = 0; i < _steps.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.space3,
                  ),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: i < current
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: AppTheme.success,
                                size: 22,
                              )
                            : i == current
                            ? const Padding(
                                padding: EdgeInsets.all(2),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                ),
                              )
                            : Icon(
                                Icons.radio_button_unchecked_rounded,
                                color: AppTheme.textSecondary,
                                size: 22,
                              ),
                      ),
                      const SizedBox(width: AppTheme.space4),
                      Text(
                        _steps[i],
                        style: text.bodyLarge?.copyWith(
                          fontWeight: i == current
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: i > current
                              ? AppTheme.textSecondary
                              : AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
      actions: <Widget>[
        TextButton(
          key: const Key('preparing_bill_cancel'),
          onPressed: onCancel,
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
