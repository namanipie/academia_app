import 'dart:math';

enum AttendanceRiskTier {
  savedByLeaves('RESCUED BY LEAVES', 0xFF10B981),
  safe('SAFE BUFFER', 0xFF9DF8A0),
  warning('WARNING BORDERLINE', 0xFFFF9800),
  critical('CRITICAL DEBARRED', 0xFFFD3974);

  final String label;
  final int colorHex;

  const AttendanceRiskTier(this.label, this.colorHex);
}

class AttendanceSimulationInput {
  final int conducted;
  final int absent;
  final int futureAttended;
  final int futureBunked;
  final int odHours;
  final int mlHours;
  final double targetPercentage;
  final List<DateTime>? skippedDates;
  final String? selectedCourseKey;
  final int Function(DateTime)? resolveDayOrder;
  final List<Map<String, String>> Function(int)? getClassesForDayOrder;

  const AttendanceSimulationInput({
    required this.conducted,
    required this.absent,
    this.futureAttended = 0,
    this.futureBunked = 0,
    this.odHours = 0,
    this.mlHours = 0,
    this.targetPercentage = 75.0,
    this.skippedDates,
    this.selectedCourseKey,
    this.resolveDayOrder,
    this.getClassesForDayOrder,
  });

  int get attended => max(0, conducted - absent);
}

class AttendanceSimulationResult {
  final double basePercentage;
  final double simulatedPercentage;
  final double percentageDelta;
  final double odMlBoost;
  final int totalSimulatedAttended;
  final int totalSimulatedConducted;
  final int safeBunks;
  final int recoveryClassesNeeded;
  final bool isRescuedByOdMl;
  final AttendanceRiskTier riskTier;
  final String verdictText;

  const AttendanceSimulationResult({
    required this.basePercentage,
    required this.simulatedPercentage,
    required this.percentageDelta,
    required this.odMlBoost,
    required this.totalSimulatedAttended,
    required this.totalSimulatedConducted,
    required this.safeBunks,
    required this.recoveryClassesNeeded,
    required this.isRescuedByOdMl,
    required this.riskTier,
    required this.verdictText,
  });
}

class AttendanceSimulatorService {
  const AttendanceSimulatorService();

  int _calculateBunksFromDates(AttendanceSimulationInput input) {
    if (input.skippedDates == null || input.skippedDates!.isEmpty) return 0;
    if (input.resolveDayOrder == null || input.getClassesForDayOrder == null)
      return 0;

    int bunkCount = 0;
    for (final date in input.skippedDates!) {
      final dayOrder = input.resolveDayOrder!(date);
      if (dayOrder == -1) continue; // Holiday or invalid

      final classes = input.getClassesForDayOrder!(dayOrder);

      if (input.selectedCourseKey == null) {
        // Global simulation: bunk all classes that day
        bunkCount += classes.length;
      } else {
        // Specific course simulation: only count classes matching the course
        for (final c in classes) {
          if (c['course'] != null &&
              c['course']!.contains(input.selectedCourseKey!)) {
            bunkCount++;
          }
        }
      }
    }
    return bunkCount;
  }

  AttendanceSimulationResult simulate(AttendanceSimulationInput input) {
    final int baseAttended = input.attended;
    final int baseConducted = input.conducted;

    final double basePercentage = baseConducted == 0
        ? 0.0
        : (baseAttended / baseConducted * 100.0).clamp(0.0, 100.0);

    // Calculate future bunks dynamically if dates are provided, else fallback to manual futureBunked
    final int calculatedFutureBunks = input.skippedDates != null
        ? _calculateBunksFromDates(input)
        : input.futureBunked;

    // Simulated attended includes base attended + future attended + OD + ML
    final int simulatedAttended = max(
      0,
      baseAttended + input.futureAttended + input.odHours + input.mlHours,
    );

    // Simulated conducted includes base conducted + future attended + future bunks
    final int simulatedConducted = max(
      0,
      baseConducted + input.futureAttended + calculatedFutureBunks,
    );

    // Ensure attended does not exceed conducted
    final int finalAttended = min(simulatedAttended, simulatedConducted);

    final double simulatedPercentage = simulatedConducted == 0
        ? 0.0
        : (finalAttended / simulatedConducted * 100.0).clamp(0.0, 100.0);

    final double delta = simulatedPercentage - basePercentage;

    // OD / ML boost calculation
    final double odMlBoost = simulatedConducted == 0
        ? 0.0
        : ((input.odHours + input.mlHours) / simulatedConducted * 100.0).clamp(
            0.0,
            100.0,
          );

    final double targetFraction = (input.targetPercentage / 100.0).clamp(
      0.01,
      0.99,
    );

    // Safe bunks calculation from current simulated state:
    // (A) / (C + B) >= T  =>  B <= A/T - C
    int safeBunks = 0;
    if (finalAttended > 0) {
      final double maxConductedAllowed = finalAttended / targetFraction;
      final double margin = maxConductedAllowed - simulatedConducted;
      safeBunks = max(0, margin.floor());
    }

    // Recovery classes needed if below target:
    // (A + X) / (C + X) >= T  =>  X >= (T*C - A) / (1 - T)
    int recoveryClassesNeeded = 0;
    if (simulatedPercentage < input.targetPercentage &&
        simulatedConducted > 0) {
      final double numerator =
          targetFraction * simulatedConducted - finalAttended;
      final double denominator = 1.0 - targetFraction;
      if (denominator > 0) {
        recoveryClassesNeeded = max(1, (numerator / denominator).ceil());
      }
    }

    // Check if OD/ML specifically saved user from debarment
    // Without OD/ML:
    final int attendedWithoutLeaves = min(
      baseAttended + input.futureAttended,
      simulatedConducted,
    );
    final double pctWithoutLeaves = simulatedConducted == 0
        ? 0.0
        : (attendedWithoutLeaves / simulatedConducted * 100.0);

    final bool isRescuedByOdMl =
        (input.odHours > 0 || input.mlHours > 0) &&
        pctWithoutLeaves < input.targetPercentage &&
        simulatedPercentage >= input.targetPercentage;

    // Risk Tier & Verdict
    AttendanceRiskTier tier;
    String verdict;

    if (isRescuedByOdMl) {
      tier = AttendanceRiskTier.savedByLeaves;
      verdict =
          '🛡️ RESCUED: Approved OD/ML lifted attendance to ${simulatedPercentage.toStringAsFixed(1)}% (above ${input.targetPercentage.toStringAsFixed(0)}% target)!';
    } else if (simulatedPercentage < input.targetPercentage) {
      tier = AttendanceRiskTier.critical;
      verdict =
          '⚠️ DEBARRED: Must attend next $recoveryClassesNeeded consecutive classes without missing to reach ${input.targetPercentage.toStringAsFixed(0)}%.';
    } else if (simulatedPercentage < input.targetPercentage + 5.0) {
      tier = AttendanceRiskTier.warning;
      if (safeBunks == 0) {
        verdict =
            '⚡ BORDERLINE: 0 margin remaining. Missing just 1 more class will drop you below ${input.targetPercentage.toStringAsFixed(0)}%.';
      } else {
        verdict =
            '⚡ TIGHT MARGIN: You can safely miss only $safeBunks class${safeBunks == 1 ? '' : 'es'} before hitting debarment threshold.';
      }
    } else {
      tier = AttendanceRiskTier.safe;
      verdict =
          '🟢 SECURE ZONE: You have an ample buffer and can safely miss up to $safeBunks class${safeBunks == 1 ? '' : 'es'}.';
    }

    return AttendanceSimulationResult(
      basePercentage: basePercentage,
      simulatedPercentage: simulatedPercentage,
      percentageDelta: delta,
      odMlBoost: odMlBoost,
      totalSimulatedAttended: finalAttended,
      totalSimulatedConducted: simulatedConducted,
      safeBunks: safeBunks,
      recoveryClassesNeeded: recoveryClassesNeeded,
      isRescuedByOdMl: isRescuedByOdMl,
      riskTier: tier,
      verdictText: verdict,
    );
  }
}
