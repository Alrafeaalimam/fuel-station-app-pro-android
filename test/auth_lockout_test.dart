import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fuel_station_app_pro_android/data/database_helper.dart';
import 'package:fuel_station_app_pro_android/data/repositories/auth_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Security Verification: Failed Login Rate Limiting & Account Lockout', () {
    late DatabaseHelper dbHelper;
    late AuthRepository authRepo;
    late Database testDb;

    setUp(() async {
      AuthRepository.resetLockoutForTesting();
      testDb = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) => DatabaseHelper.instance.createDBForTesting(db),
        ),
      );
      dbHelper = DatabaseHelper.withDatabase(testDb);
      authRepo = AuthRepository(dbHelper: dbHelper);
    });

    tearDown(() async {
      AuthRepository.resetLockoutForTesting();
      await testDb.close();
    });

    test('Normal login with correct password succeeds immediately and resets counter', () async {
      final user = await authRepo.login('admin', 'admin123');
      expect(user, isNotNull);
      expect(user!.username, equals('admin'));
      expect(authRepo.isAccountLocked('admin'), isFalse);
      expect(authRepo.getRemainingAttempts('admin'), equals(5));
    });

    test('Temporary 5-minute lockout triggers on 5 failed attempts with remaining time message', () async {
      const username = 'admin';

      // Attempts 1 to 4: failed login returns null and decrements remaining attempts
      for (int i = 1; i <= 4; i++) {
        final result = await authRepo.login(username, 'wrong_pass_$i');
        expect(result, isNull);
        expect(authRepo.isAccountLocked(username), isFalse);
        expect(authRepo.getRemainingAttempts(username), equals(5 - i));
      }

      // 5th attempt: triggers AuthLockoutException with clear Arabic message
      try {
        await authRepo.login(username, 'wrong_pass_5');
        fail('Expected AuthLockoutException on 5th failed attempt');
      } on AuthLockoutException catch (e) {
        expect(e.message, contains('تم قفل الحساب مؤقتاً لتكرار محاولات الدخول الخاطئة (5 محاولات)'));
        expect(e.remainingLockout.inMinutes, inInclusiveRange(4, 5));
      }

      expect(authRepo.isAccountLocked(username), isTrue);

      // Attempt 6 (even with correct password): blocked while locked out
      expect(
        () => authRepo.login(username, 'admin123'),
        throwsA(isA<AuthLockoutException>()),
      );

      // Reset lockout and verify login succeeds
      AuthRepository.resetLockoutForTesting(username);
      expect(authRepo.isAccountLocked(username), isFalse);
      final user = await authRepo.login(username, 'admin123');
      expect(user, isNotNull);
    });

    test('Successful login resets failed attempts counter', () async {
      const username = 'accountant';

      // 3 failed attempts
      for (int i = 0; i < 3; i++) {
        await authRepo.login(username, 'bad_pass');
      }
      expect(authRepo.getRemainingAttempts(username), equals(2));

      // Correct login succeeds and clears failed counter
      final user = await authRepo.login(username, 'acc123');
      expect(user, isNotNull);
      expect(authRepo.getRemainingAttempts(username), equals(5));
    });
  });
}
