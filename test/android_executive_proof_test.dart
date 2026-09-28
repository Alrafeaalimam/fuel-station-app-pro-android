import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fuel_station_app_pro_android/data/database_helper.dart';
import 'package:fuel_station_app_pro_android/data/repositories/auth_repository.dart';
import 'package:fuel_station_app_pro_android/data/repositories/shift_repository.dart';
import 'package:fuel_station_app_pro_android/data/repositories/backup_repository.dart';
import 'package:fuel_station_app_pro_android/data/repositories/tank_repository.dart';
import 'package:fuel_station_app_pro_android/services/license_service.dart';
import 'package:fuel_station_app_pro_android/models/models.dart';
import 'package:fuel_station_app_pro_android/utils/permission_guard.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() {
    LicenseService.setMockRawDeviceId(null);
    LicenseService.setMockNow(null);
  });

  test('Android Executive Proof: Complete End-to-End Operational Lifecycle Verification', () async {
    print('\n================================================================');
    print('🚀 بدء الإثبات التنفيذي الشامل لنسخة الأندرويد المستقلة (Android Edition)');
    print('================================================================');

    final tempDir = Directory.systemTemp.createTempSync('android_exec_proof_');
    final dbFilePath = p.join(tempDir.path, 'fuel_station_pro.db');

    final initialDb = await databaseFactoryFfi.openDatabase(
      dbFilePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => DatabaseHelper.instance.createDBForTesting(db),
      ),
    );
    await initialDb.close();

    final dbHelper = DatabaseHelper.withFile(dbFilePath);
    final authRepo = AuthRepository(dbHelper: dbHelper);
    final shiftRepo = ShiftRepository(dbHelper: dbHelper);
    final tankRepo = TankRepository(dbHelper: dbHelper);
    final backupRepo = BackupRepository(dbHelper: dbHelper);

    // =========================================================================
    // 1. إثبات تسجيل الدخول (Authentication)
    // =========================================================================
    print('\n[1/5] التحقق من تسجيل الدخول بحساب المدير (Authentication):');
    final loginResult = await authRepo.login('admin', 'admin123');
    expect(loginResult, isNotNull);
    expect(loginResult!.username, equals('admin'));
    expect(loginResult.role, equals('manager'));
    expect(loginResult.isManager, isTrue);
    print('-> ✅ نجح تسجيل الدخول:');
    print('   - الاسم: ${loginResult.name}');
    print('   - اسم المستخدم: ${loginResult.username}');
    print('   - الدور الوظيفي: ${loginResult.roleArabic}');
    print('   - صلاحية قفل الوردية: ${loginResult.can(AppPermission.closeShift)}');
    print('   - صلاحية إدارة النسخ الاحتياطي: ${loginResult.can(AppPermission.manageBackup)}');

    // =========================================================================
    // 2. إثبات الفترة التجريبية (7-Day Trial System)
    // =========================================================================
    print('\n[2/5] التحقق من الفترة التجريبية (7-Day Trial System):');
    // محاكاة معرّف أندرويد
    const simulatedAndroidRawId = 'ANDROID_ID:Samsung:GalaxyS24:3a7f8b9c4d1e2f30:samsung/s24/s24:14/UP1A.231005.007';
    LicenseService.setMockRawDeviceId(simulatedAndroidRawId);

    final baseTime = DateTime.parse('2026-09-28 10:00:00');
    LicenseService.setMockNow(baseTime);

    final initialLicense = await LicenseService.checkLicenseStatus(dbHelper: dbHelper);
    expect(initialLicense.status, equals(LicenseStatus.trial));
    expect(initialLicense.daysRemaining, equals(7));
    expect(initialLicense.isOperational, isTrue);
    print('-> ✅ بداية التشغيل: حالة الترخيص: ${initialLicense.status} (الأيام المتبقية: ${initialLicense.daysRemaining})');
    print('-> معرّف الجهاز المستخرج من أندرويد (Device Code): [${initialLicense.deviceCode}]');

    // تقدم الزمن 8 أيام لاختبار انتهاء الفترة التجريبية
    final expiredTime = baseTime.add(const Duration(days: 8));
    LicenseService.setMockNow(expiredTime);
    final expiredLicense = await LicenseService.checkLicenseStatus(dbHelper: dbHelper);
    expect(expiredLicense.status, equals(LicenseStatus.expired));
    expect(expiredLicense.isOperational, isFalse);
    print('-> ✅ بعد مرور 8 أيام: حالة الترخيص: ${expiredLicense.status} (تم قفل النظام تلقائياً)');

    // =========================================================================
    // 3. تفعيل الترخيص بكود من أداة لوحة التحكم license-manager-app / admin_dashboard
    // =========================================================================
    print('\n[3/5] توليد كود الترخيص وتفعيل النظام (License Activation):');
    final deviceCode = initialLicense.deviceCode; // XXXX-XXXX
    final expectedActivationKey = LicenseService.generateActivationKey(deviceCode);
    print('-> كود الجهاز المطلوب تفعيله: $deviceCode');
    print('-> كود التفعيل المستخرج عبر خوارزمية SHA-256 (admin_dashboard): $expectedActivationKey');

    final activatedSuccessfully = await LicenseService.activateLicense(
      inputKey: expectedActivationKey,
      dbHelper: dbHelper,
    );
    expect(activatedSuccessfully, isTrue);

    final postActivationLicense = await LicenseService.checkLicenseStatus(dbHelper: dbHelper);
    expect(postActivationLicense.status, equals(LicenseStatus.active));
    expect(postActivationLicense.isOperational, isTrue);
    expect(postActivationLicense.activationKey, equals(expectedActivationKey));
    print('-> ✅ تم قبول كود التفعيل وتنشيط النظام بنجاح!');
    print('   - الحالة الجديدة: ${postActivationLicense.status}');
    print('   - كود التفعيل المخزن: ${postActivationLicense.activationKey}');
    print('   - تاريخ التفعيل: ${postActivationLicense.activatedAt}');
    print('   - جاهزية النظام للعمليات: ${postActivationLicense.isOperational}');

    // =========================================================================
    // 4. إثبات قفل وردية كاملة (Shift Closing Workflow)
    // =========================================================================
    print('\n[4/5] تنفيذ عملية قفل وردية كاملة بجميع الحسابات (Shift Close):');
    // إعداد أسعار الوقود أولاً
    final db = await dbHelper.database;
    await db.update('fuel_prices', {'price_per_liter': 1200.0}, where: 'fuel_type = ?', whereArgs: ['بنزين']);
    await db.update('fuel_prices', {'price_per_liter': 1000.0}, where: 'fuel_type = ?', whereArgs: ['جازولين']);

    // جلب بيانات الخزانات والفوهات
    final tanks = await tankRepo.getTanks();
    final pumps = await tankRepo.getPumps();
    expect(tanks.length, equals(2));
    expect(pumps.length, equals(8));

    final benzinTank = tanks.firstWhere((t) => t.fuelType == 'بنزين');
    final dieselTank = tanks.firstWhere((t) => t.fuelType == 'جازولين');

    // إعداد قراءات العدادات للفوهات الثمانية (زيادة 100 لتر لكل فوهة = 800 لتر إجمالي)
    final readings = <ShiftReadingModel>[];
    for (final p in pumps) {
      final prev = await shiftRepo.getLastMeterForPump(p.id!);
      final curr = prev + 100.0;
      final isBenzin = p.tankId == benzinTank.id;
      final prevDip = isBenzin ? benzinTank.currentDipLiters : dieselTank.currentDipLiters;
      final currDip = prevDip - 400.0;
      final price = isBenzin ? 1200.0 : 1000.0;
      readings.add(ShiftReadingModel(
        shiftId: 1,
        pumpId: p.id!,
        previousMeter: prev,
        currentMeter: curr,
        litersSold: 100.0,
        previousDip: prevDip,
        currentDip: currDip,
        deliveredLitersDuringShift: 0.0,
        surplusDeficit: 0.0,
        pricePerLiter: price,
        totalAmount: 100.0 * price,
      ));
    }

    final nowIso = DateTime.now().toIso8601String();
    final shiftToClose = ShiftModel(
      closedByUserId: 1,
      closeDatetime: nowIso,
      status: 'closed',
      notes: 'إثبات قفل وردية اختبارية ناجحة',
    );

    const summaryToClose = SalesSummaryModel(
      shiftId: 1,
      cashAmount: 500000.0,
      bankTransferAmount: 280000.0,
      creditAmount: 100000.0,
      totalAmount: 880000.0,
    );

    final closedShiftId = await shiftRepo.closeShift(
      shift: shiftToClose,
      readings: readings,
      summary: summaryToClose,
      tankNewDips: {
        benzinTank.id!: benzinTank.currentDipLiters - 400.0,
        dieselTank.id!: dieselTank.currentDipLiters - 400.0,
      },
      creditTransactions: [],
    );

    expect(closedShiftId, isPositive);
    print('-> ✅ تم قفل الوردية بنجاح وتسجيلها برقم ID: #$closedShiftId');
    print('   - إجمالي الفوهات المسجلة: ${readings.length}');
    print('   - إجمالي قيمة المبيعات المسجلة: ${summaryToClose.totalAmount} ج.س');
    print('   - المتحصلات (نقدي: ${summaryToClose.cashAmount} / بنكي: ${summaryToClose.bankTransferAmount} / آجل: ${summaryToClose.creditAmount})');

    // التحقق من تقرير الوردية التفصيلي
    final reportData = await shiftRepo.getShiftReportFullData(closedShiftId);
    expect(reportData, isNotNull);
    expect(reportData!.benzinPumps.length + reportData.dieselPumps.length, equals(8));
    print('   - تم التحقق من تقرير اليومية الكامل: 8 فوهات مسجلة، خزانين محدثين');

    // =========================================================================
    // 5. إثبات النسخ الاحتياطي والاستعادة (Backup & Restore)
    // =========================================================================
    print('\n[5/5] التحقق من النسخ الاحتياطي والاستعادة ومطابقة البيانات:');
    const adminUser = UserModel(
      id: 1,
      name: 'مدير المحطة',
      username: 'admin',
      passwordHash: 'admin123',
      role: 'manager',
    );

    // إضافة عميل جديد قبل النسخ الاحتياطي
    final insertedCustId = await db.insert('customers', {
      'name': 'شركة الخرطوم للخدمات البترولية',
      'type': 'company',
      'phone': '0912345678',
      'credit_limit': 1500000.0,
      'current_balance': 350000.0,
    });
    expect(insertedCustId, isPositive);
    print('-> خطوة أ: تم إنشاء العميل التجريبي برقم ID: #$insertedCustId');

    // أخذ نسخة احتياطية
    final backupPath = p.join(tempDir.path, 'android_exec_backup.db');
    await backupRepo.createManualBackup(backupPath, user: adminUser);
    final backupFile = File(backupPath);
    expect(await backupFile.exists(), isTrue);
    final backupSize = await backupFile.length();
    expect(backupSize, isPositive);
    print('-> خطوة ب: تم حفظ النسخة الاحتياطية بنجاح بحجم: $backupSize بايت');

    // حذف العميل لمحاكاة فقدان بيانات
    final deletedRows = await db.delete('customers', where: 'id = ?', whereArgs: [insertedCustId]);
    expect(deletedRows, equals(1));
    final checkEmpty = await db.query('customers', where: 'id = ?', whereArgs: [insertedCustId]);
    expect(checkEmpty, isEmpty);
    print('-> خطوة ج: تم حذف العميل من قاعدة البيانات (تأكيد الحذف: 0 سجل)');

    // استعادة النسخة الاحتياطية
    await backupRepo.restoreBackup(backupPath, user: adminUser);
    print('-> خطوة د: تمت استعادة النسخة الاحتياطية بنجاح');

    // التحقق من استعادة العميل بكامل بياناته
    final restoredDb = await dbHelper.database;
    final restoredRows = await restoredDb.query('customers', where: 'id = ?', whereArgs: [insertedCustId]);
    expect(restoredRows.length, equals(1));
    final restoredCustomer = restoredRows.first;
    expect(restoredCustomer['name'], equals('شركة الخرطوم للخدمات البترولية'));
    expect((restoredCustomer['current_balance'] as num).toDouble(), equals(350000.0));
    print('-> خطوة هـ: ✅ تأكيد استعادة العميل بنجاح 100%:');
    print('   - الاسم: ${restoredCustomer['name']}');
    print('   - الرصيد: ${restoredCustomer['current_balance']} ج.س');
    print('   - السقف الائتماني: ${restoredCustomer['credit_limit']} ج.س');

    print('\n================================================================');
    print('🎉 اكتمل الإثبات التنفيذي الشامل بنجاح تام 100%!');
    print('================================================================\n');
  });
}
