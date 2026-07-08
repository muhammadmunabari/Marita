import 'package:flutter/material.dart';
import 'package:marita/design_system/marita_design_system.dart';
import 'package:marita/models/chat_message.dart';

// =============================================================================
// STEP DATA
// =============================================================================

/// Context-specific steps shown inside the loading widget.
/// Each list maps to the phases: retrievingContext → ~step 0,
/// buildingPrompt → ~mid step, generating → last step (stays active forever).
const Map<LoadingRequestType, List<String>> _kAuditSteps = {
  LoadingRequestType.financialStatements: [
    'Reading financial documents…',
    'Extracting balance sheet items…',
    'Cross-referencing income statement…',
    'Calculating financial ratios…',
    'Compiling audit findings…',
  ],
  LoadingRequestType.invoices: [
    'Scanning invoice data…',
    'Verifying vendor information…',
    'Matching line items…',
    'Checking compliance…',
    'Generating invoice summary…',
  ],
  LoadingRequestType.receipts: [
    'Parsing receipt data…',
    'Categorizing expenses…',
    'Validating amounts…',
    'Checking for duplicates…',
  ],
  LoadingRequestType.contracts: [
    'Reading contract terms…',
    'Identifying key clauses…',
    'Assessing compliance risk…',
    'Summarizing obligations…',
  ],
  LoadingRequestType.annualReport: [
    'Loading annual report…',
    'Extracting key metrics…',
    'Analyzing year-over-year trends…',
    'Identifying material items…',
    'Preparing executive summary…',
  ],
  LoadingRequestType.accountingQuestion: [
    'Interpreting your question…',
    'Reviewing accounting standards…',
    'Applying relevant principles…',
    'Formulating response…',
  ],
  LoadingRequestType.general: [
    'Processing your request…',
    'Gathering relevant context…',
    'Preparing response…',
  ],
};

// =============================================================================
// STATE ENUM
// =============================================================================

enum _StepState { inactive, active, done }

// =============================================================================
// WIDGET
// =============================================================================

/// A theme-aware loading widget that displays sequential audit steps advancing
/// in real-time with the actual [AIPipelinePhase] emitted by [ChatNotifier].
///
/// Steps advance when the phase changes — no independent timer is used.
/// The **last step always stays active (spinning)** until the widget is
/// replaced by [AnimatedSwitcher] once the first response token arrives.
class AuditLoadingWidget extends StatefulWidget {
  final LoadingRequestType requestType;

  /// The current AI pipeline phase, driven by [ChatNotifier].
  final AIPipelinePhase phase;

  const AuditLoadingWidget({
    super.key,
    required this.requestType,
    required this.phase,
  });

  @override
  State<AuditLoadingWidget> createState() => _AuditLoadingWidgetState();
}

class _AuditLoadingWidgetState extends State<AuditLoadingWidget>
    with TickerProviderStateMixin {
  // ── Animations ────────────────────────────────────────────────────────────
  late final AnimationController _fadeInCtrl;
  late final Animation<double> _fadeInAnim;

  late final AnimationController _spinnerCtrl;
  late final Animation<double> _spinnerAnim;

  // Per-step scale animations for check marks
  final List<AnimationController> _checkCtrl = [];
  final List<Animation<double>> _checkAnim = [];

  // ── State ─────────────────────────────────────────────────────────────────
  /// Index of the step that is currently ACTIVE (spinning).
  /// Steps before this index are DONE; steps after are INACTIVE.
  int _activeIndex = 0;
  List<String> _steps = [];

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _steps =
        _kAuditSteps[widget.requestType] ??
        _kAuditSteps[LoadingRequestType.general]!;

    // Widget fade-in
    _fadeInCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeInAnim = CurvedAnimation(parent: _fadeInCtrl, curve: Curves.easeOut);
    _fadeInCtrl.forward();

    // Spinner rotation — continuous, shared across all active-state indicators
    _spinnerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
    _spinnerAnim = Tween<double>(begin: 0, end: 1).animate(_spinnerCtrl);

    // Build per-step check-mark controllers
    for (int i = 0; i < _steps.length; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 250),
      );
      _checkCtrl.add(ctrl);
      _checkAnim.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: ctrl, curve: Curves.elasticOut),
        ),
      );
    }

    // Apply initial phase immediately
    _applyPhase(widget.phase, animate: false);
  }

  @override
  void didUpdateWidget(AuditLoadingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase) {
      _applyPhase(widget.phase, animate: true);
    }
  }

  /// Calculates the target active step index for a given [phase] and advances
  /// any steps that have been completed since the last call.
  ///
  /// ### Phase → Step mapping
  /// | Phase               | Target active index                    |
  /// |---------------------|----------------------------------------|
  /// | idle / retrieving   | 0                                      |
  /// | buildingPrompt      | floor(total * 0.5), min 1, max last-1  |
  /// | generating          | last index (never completes)           |
  void _applyPhase(AIPipelinePhase phase, {required bool animate}) {
    final total = _steps.length;

    final target = switch (phase) {
      AIPipelinePhase.idle             => 0,
      AIPipelinePhase.retrievingContext => 0,
      AIPipelinePhase.buildingPrompt   => (total * 0.5).floor().clamp(1, total - 1),
      AIPipelinePhase.generating       => total - 1,
    };

    if (target <= _activeIndex) return; // Never go backwards

    // Complete all steps between current active and new target
    for (int i = _activeIndex; i < target; i++) {
      if (animate) {
        _checkCtrl[i].forward();
      } else {
        _checkCtrl[i].value = 1.0;
      }
    }

    setState(() {
      _activeIndex = target;
    });
  }

  @override
  void dispose() {
    _fadeInCtrl.dispose();
    _spinnerCtrl.dispose();
    for (final c in _checkCtrl) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<MaritaColorPalette>()!;
    final typography = context.maritaTypography;

    return FadeTransition(
      opacity: _fadeInAnim,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header — always visible ─────────────────────────────────────
          Text(
            'Agent is thinking…',
            style: typography.bodyLargeBold.copyWith(
              color: palette.contentPrimary,
            ),
          ),
          const SizedBox(height: MaritaSpacing.md),

          // ── Step rows ──────────────────────────────────────────────────
          ...List.generate(_steps.length, (i) {
            final stepState = _stepState(i);
            return _StepRow(
              label: _steps[i],
              stepState: stepState,
              spinnerAnim: _spinnerAnim,
              checkAnim: _checkAnim[i],
              palette: palette,
              typography: typography,
            );
          }),
        ],
      ),
    );
  }

  _StepState _stepState(int index) {
    // The last step is NEVER marked done — it stays active (spinning) until
    // the widget is replaced by AnimatedSwitcher when text.isNotEmpty.
    if (index < _activeIndex) return _StepState.done;
    if (index == _activeIndex) return _StepState.active;
    return _StepState.inactive;
  }
}

// =============================================================================
// STEP ROW
// =============================================================================

class _StepRow extends StatelessWidget {
  final String label;
  final _StepState stepState;
  final Animation<double> spinnerAnim;
  final Animation<double> checkAnim;
  final MaritaColorPalette palette;
  final MaritaTypographyAccessor typography;

  const _StepRow({
    required this.label,
    required this.stepState,
    required this.spinnerAnim,
    required this.checkAnim,
    required this.palette,
    required this.typography,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MaritaSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Leading icon/spinner ───────────────────────────────────────
          SizedBox(
            width: 18,
            height: 18,
            child: _buildLeadingIndicator(),
          ),
          const SizedBox(width: MaritaSpacing.sm),

          // ── Label ─────────────────────────────────────────────────────
          Expanded(
            child: Text(
              label,
              style: typography.bodyDefault.copyWith(
                color: _labelColor(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadingIndicator() {
    return switch (stepState) {
      _StepState.active => RotationTransition(
        turns: spinnerAnim,
        child: Icon(
          Icons.sync_rounded,
          size: 16,
          color: palette.interactivePrimary,
        ),
      ),
      _StepState.done => ScaleTransition(
        scale: checkAnim,
        child: Icon(
          Icons.check_circle_rounded,
          size: 16,
          color: palette.success,
        ),
      ),
      _StepState.inactive => Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: palette.borderPrimary,
        ),
      ),
    };
  }

  Color _labelColor() {
    return switch (stepState) {
      _StepState.active   => palette.contentPrimary,
      _StepState.done     => palette.contentSecondary,
      _StepState.inactive => palette.contentTertiary,
    };
  }
}
