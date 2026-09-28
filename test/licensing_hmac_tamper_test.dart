import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fuel_station_app_pro_android/data/database_helper.dart';
import 'package:fuel_station_app_pro_android/services/license_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Security Verification: HMAC Anti-Tampering Protection for License', () {
    late Directory tempDir;
    late String dbFilePath;
    late Database testDb;

    setUp(() async {
      LicenseService.setMockRawDeviceId('DEVICE_HMAC_TEST_001');
      LicenseService.setMockNow(DateTime(2026, 9, 24, 10, 0, 0));

      tempDir = Directory.systemTemp.createTempSync('fuel_hmac_test_');
      dbFilePath = p.join(tempDir.path, 'fuel_station_pro.db');

      testDb = await databaseFactoryFfi.openDatabase(
        dbFilePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) => DatabaseHelper.instance.createDBForTesting(db),
        ),
      );
    });

    tearDown(() async {
      LicenseService.setMockRawDeviceId(null);
      LicenseService.setMockNow(null);
      await testDb.close();
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('Direct SQL modification of first_run_date is detected via HMAC signature mismatch', () async {
      // 1. Initial run creates trial with valid HMAC signature
      final initialInfo = await LicenseService.checkLicenseStatus(customDb: testDb);
      expect(initialInfo.status, equals(LicenseStatus.trial));

      final rowsBefore = await testDb.query('settings', where: 'key = ?', whereArgs: ['license_hmac_signature']);
      expect(rowsBefore, isNotEmpty);
      expect(rowsBefore.first['value'], isNotNull);

      // 2. An attacker opens SQLite directly and modifies license_first_run_date to extend trial
      await testDb.update(
        'settings',
        {'value': DateTime(2026, 9, 20, 10, 0, 0).toIso8601String()},
        where: 'key = ?',
        whereArgs: ['license_first_run_date'],
      );

      // 3. LicenseService rechecks - HMAC mismatch triggers tampered status
      final tamperedInfo = await LicenseService.checkLicenseStatus(customDb: testDb);
      expect(tamperedInfo.status, equals(LicenseStatus.tampered));
      expect(tamperedInfo.isOperational, isFalse);
    });
  });
}
