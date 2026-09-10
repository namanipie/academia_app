import 'package:academia_app/utils/day_order_backup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('DayOrderManager', () {
    test('returns null when no backup exists', () async {
      final result = await DayOrderManager.getDayOrderForDate(DateTime(2030));
      expect(result, isNull);
    });

    test('clearBackup is a no-op when no data exists', () async {
      await DayOrderManager.clearBackup();
      final status = await DayOrderManager.getBackupStatus();
      expect(status['hasBackup'], isFalse);
      expect(status['lastKnownDayOrder'], isNull);
      expect(status['forecastDays'], 0);
    });

    test('getBackupStatus reflects empty state correctly', () async {
      final status = await DayOrderManager.getBackupStatus();
      expect(status['hasBackup'], isFalse);
      expect(status['lastKnownDayOrder'], isNull);
      expect(status['lastKnownDate'], isNull);
      expect(status['forecastDays'], equals(0));
    });
  });
}
