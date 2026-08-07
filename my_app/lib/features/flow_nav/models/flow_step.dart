import 'package:flutter/material.dart';

/// One stop on a journey through the app.
///
/// [id] is stable and doubles as the route name, so the progress bar can pop
/// straight back to a step without knowing how that screen was built.
@immutable
class FlowStep {
  final String id;

  /// What the bubble is called. Kept short -- these sit under a 44px circle,
  /// so anything longer than about ten characters stops being readable.
  final String label;

  final IconData icon;

  /// Spelled out for the ones whose label is an abbreviation, so a first-time
  /// user can long-press and find out what "P&H" means.
  final String? meaning;

  const FlowStep({
    required this.id,
    required this.label,
    required this.icon,
    this.meaning,
  });

  /// What to read out to someone using a screen reader: the abbreviation on
  /// its own tells them nothing.
  String get spoken => meaning ?? label;

  @override
  bool operator ==(Object other) => other is FlowStep && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Which journey the user is on.
enum FlowKind {
  /// Quoting a customer: ends at the invoice.
  estimation,

  /// Cutting the job: ends at the glass sheet layout.
  fabrication,

  /// A glass-only project, started straight from the fabrication menu.
  glass,

  /// Home to a settings page. Three steps deep at most.
  settings,
}

/// An ordered journey. The last step of a working flow is Home again, because
/// that is genuinely where the user goes when the job is done.
@immutable
class AppFlow {
  final FlowKind kind;
  final List<FlowStep> steps;

  const AppFlow({required this.kind, required this.steps});

  int indexOf(String stepId) =>
      steps.indexWhere((FlowStep step) => step.id == stepId);
}

/// Every step the app knows about, in one place so ids cannot drift apart
/// between the flow definitions and the screens that report them.
class FlowSteps {
  const FlowSteps._();

  static const FlowStep home = FlowStep(
    id: 'home',
    label: 'Home',
    icon: Icons.home_rounded,
  );

  /// The same screen as [home], but at the end of a journey. It gets its own id
  /// so a finished flow does not fold back onto its own first bubble.
  static const FlowStep finish = FlowStep(
    id: 'home_end',
    label: 'Home',
    icon: Icons.home_rounded,
  );

  static const FlowStep projects = FlowStep(
    id: 'projects',
    label: 'P&H',
    icon: Icons.folder_open_rounded,
    meaning: 'Projects and history',
  );

  static const FlowStep library = FlowStep(
    id: 'library',
    label: 'Library',
    icon: Icons.grid_view_rounded,
    meaning: 'Window library',
  );

  static const FlowStep sizeInput = FlowStep(
    id: 'size_input',
    label: 'Size Input',
    icon: Icons.straighten_rounded,
  );

  static const FlowStep review = FlowStep(
    id: 'review',
    label: 'Review',
    icon: Icons.fact_check_rounded,
    meaning: 'Review saved windows',
  );

  static const FlowStep lengthOptimization = FlowStep(
    id: 'length_optimization',
    label: 'Lengths',
    icon: Icons.content_cut_rounded,
    meaning: 'Length optimization',
  );

  static const FlowStep gaugeColour = FlowStep(
    id: 'gauge_colour',
    label: 'G&C',
    icon: Icons.palette_rounded,
    meaning: 'Gauge and colour',
  );

  static const FlowStep rates = FlowStep(
    id: 'rates',
    label: 'Rates',
    icon: Icons.price_change_rounded,
  );

  static const FlowStep material = FlowStep(
    id: 'material',
    label: 'Material',
    icon: Icons.inventory_2_rounded,
    meaning: 'Material summary',
  );

  static const FlowStep billInputs = FlowStep(
    id: 'bill_inputs',
    label: 'Bill Inputs',
    icon: Icons.edit_note_rounded,
  );

  static const FlowStep invoice = FlowStep(
    id: 'invoice',
    label: 'Invoice',
    icon: Icons.receipt_long_rounded,
  );

  static const FlowStep glassSize = FlowStep(
    id: 'glass_size',
    label: 'Glass Size',
    icon: Icons.window_rounded,
  );

  static const FlowStep glassLayout = FlowStep(
    id: 'glass_layout',
    label: 'Sheet Layout',
    icon: Icons.dashboard_customize_rounded,
    meaning: 'Glass sheet layout',
  );

  // --- settings ---

  static const FlowStep settings = FlowStep(
    id: 'settings',
    label: 'Settings',
    icon: Icons.settings_rounded,
  );

  static const FlowStep windowSettings = FlowStep(
    id: 'settings_windows',
    label: 'Windows',
    icon: Icons.window_rounded,
    meaning: 'Window settings',
  );

  static const FlowStep rateSettings = FlowStep(
    id: 'settings_rates',
    label: 'Rates',
    icon: Icons.price_change_rounded,
    meaning: 'Rate list',
  );

  static const FlowStep estimationSettings = FlowStep(
    id: 'settings_estimation',
    label: 'Estimation',
    icon: Icons.calculate_rounded,
    meaning: 'Estimation settings',
  );

  static const FlowStep fabricationSettings = FlowStep(
    id: 'settings_fabrication',
    label: 'Fabrication',
    icon: Icons.construction_rounded,
    meaning: 'Fabrication settings',
  );

  static const FlowStep companySettings = FlowStep(
    id: 'settings_company',
    label: 'Company',
    icon: Icons.storefront_rounded,
    meaning: 'Company and workshop',
  );

  static const FlowStep paymentSettings = FlowStep(
    id: 'settings_payments',
    label: 'Payments',
    icon: Icons.credit_card_rounded,
  );
}

/// Standing on Home with no job started. One bubble, so the chain is present
/// from the first screen rather than appearing out of nowhere later.
const AppFlow homeFlow = AppFlow(
  kind: FlowKind.estimation,
  steps: <FlowStep>[FlowSteps.home],
);

/// Quoting a customer, start to finish.
const AppFlow estimationFlow = AppFlow(
  kind: FlowKind.estimation,
  steps: <FlowStep>[
    FlowSteps.home,
    FlowSteps.projects,
    FlowSteps.library,
    FlowSteps.sizeInput,
    FlowSteps.review,
    FlowSteps.lengthOptimization,
    FlowSteps.gaugeColour,
    FlowSteps.rates,
    FlowSteps.material,
    FlowSteps.billInputs,
    FlowSteps.invoice,
    FlowSteps.finish,
  ],
);

/// Cutting the job. Same start as estimation, but it ends at the glass output
/// rather than at a bill -- fabrication never prices anything for a customer.
const AppFlow fabricationFlow = AppFlow(
  kind: FlowKind.fabrication,
  steps: <FlowStep>[
    FlowSteps.home,
    FlowSteps.projects,
    FlowSteps.library,
    FlowSteps.sizeInput,
    FlowSteps.review,
    FlowSteps.lengthOptimization,
    FlowSteps.gaugeColour,
    FlowSteps.rates,
    FlowSteps.material,
    FlowSteps.glassSize,
    FlowSteps.glassLayout,
    FlowSteps.finish,
  ],
);

/// A glass-only project: no aluminium, so none of the cutting or rate steps.
const AppFlow glassFlow = AppFlow(
  kind: FlowKind.glass,
  steps: <FlowStep>[
    FlowSteps.home,
    FlowSteps.projects,
    FlowSteps.glassSize,
    FlowSteps.glassLayout,
    FlowSteps.finish,
  ],
);

/// Standing on the settings screen itself, before picking a page.
const AppFlow settingsRootFlow = AppFlow(
  kind: FlowKind.settings,
  steps: <FlowStep>[FlowSteps.home, FlowSteps.settings],
);

/// Home to one settings page. Settings is a fan of leaves rather than a
/// sequence, so the flow is built per leaf instead of being a fixed list.
AppFlow settingsFlowFor(FlowStep leaf) => AppFlow(
  kind: FlowKind.settings,
  steps: <FlowStep>[FlowSteps.home, FlowSteps.settings, leaf],
);
