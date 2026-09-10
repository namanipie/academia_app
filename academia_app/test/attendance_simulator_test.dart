import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/services/attendance_simulator_service.dart';

void main() {
  const service = AttendanceSimulatorService();

  group('AttendanceSimulatorService Math & OD/ML Tests', () {
    test('Calculates standard base percentage correctly', () {
      const input = AttendanceSimulationInput(conducted: 50, absent: 10);
      final result = service.simulate(input);

      expect(result.basePercentage, closeTo(80.0, 0.01));
      expect(result.simulatedPercentage, closeTo(80.0, 0.01));
      expect(result.percentageDelta, closeTo(0.0, 0.01));
      expect(result.safeBunks, equals(3));
      expect(result.riskTier, equals(AttendanceRiskTier.safe));
    });

    test('Simulates future bunks decreasing attendance', () {
      const input = AttendanceSimulationInput(
        conducted: 50,
        absent: 10,
        futureBunked: 2,
      );
      final result = service.simulate(input);

      // 40 / 52 = 76.92%
      expect(result.simulatedPercentage, closeTo(76.92, 0.01));
      expect(result.percentageDelta, lessThan(0));
      expect(result.safeBunks, equals(1));
    });

    test('Simulates future attended classes increasing attendance', () {
      const input = AttendanceSimulationInput(
        conducted: 50,
        absent: 10,
        futureAttended: 5,
      );
      final result = service.simulate(input);

      // 45 / 55 = 81.82%
      expect(result.simulatedPercentage, closeTo(81.82, 0.01));
      expect(result.percentageDelta, greaterThan(0));
      expect(result.safeBunks, equals(5));
    });

    test('Calculates recovery classes needed when debarred (<75%)', () {
      const input = AttendanceSimulationInput(
        conducted: 50,
        absent: 15, // 35 / 50 = 70%
      );
      final result = service.simulate(input);

      expect(result.basePercentage, closeTo(70.0, 0.01));
      expect(result.riskTier, equals(AttendanceRiskTier.critical));
      // Formula: ceil((0.75 * 50 - 35) / 0.25) = ceil(2.5 / 0.25) = 10
      expect(result.recoveryClassesNeeded, equals(10));
    });

    test('Accounts for OD (On Duty) hours boosting attendance and rescuing from debarment', () {
      const input = AttendanceSimulationInput(
        conducted: 50,
        absent: 15, // 35 / 50 = 70%
        odHours: 3, // 35 + 3 = 38 / 50 = 76%
      );
      final result = service.simulate(input);

      expect(result.basePercentage, closeTo(70.0, 0.01));
      expect(result.simulatedPercentage, closeTo(76.0, 0.01));
      expect(result.odMlBoost, closeTo(6.0, 0.01));
      expect(result.isRescuedByOdMl, isTrue);
      expect(result.riskTier, equals(AttendanceRiskTier.savedByLeaves));
      expect(result.verdictText, contains('RESCUED'));
    });

    test('Accounts for ML (Medical Leave) hours combined with OD', () {
      const input = AttendanceSimulationInput(
        conducted: 50,
        absent: 20, // 30 / 50 = 60%
        odHours: 5,  // 35
        mlHours: 4,  // 39 / 50 = 78%
      );
      final result = service.simulate(input);

      expect(result.basePercentage, closeTo(60.0, 0.01));
      expect(result.simulatedPercentage, closeTo(78.0, 0.01));
      expect(result.odMlBoost, closeTo(18.0, 0.01));
      expect(result.isRescuedByOdMl, isTrue);
    });

    test('Handles zero conducted classes gracefully without crash', () {
      const input = AttendanceSimulationInput(conducted: 0, absent: 0);
      final result = service.simulate(input);

      expect(result.basePercentage, equals(0.0));
      expect(result.simulatedPercentage, equals(0.0));
      expect(result.safeBunks, equals(0));
    });
  });
}
