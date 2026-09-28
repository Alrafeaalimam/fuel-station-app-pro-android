import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fuel_station_app_pro_android/data/database_helper.dart';
import 'package:fuel_station_app_pro_android/data/repositories/backup_repository.dart';
import 'package:fuel_station_app_pro_android/models/models.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Live Execution Proof: Insert Customer -> Backup -> Delete Customer -> Restore -> Verify Customer Restored', () async {
    print('\n================================================================');
    print('بدء اختبار الإثبات التنفيذي: إنشاء عميل -> نسخ احتياطي -> حذف -> استعادة');
    print('================================================================');

    final tempDir = Directory.systemTemp.createTempSync('live_backup_proof_');
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
    final backupRepo = BackupRepository(dbHelper: dbHelper);
    final db = await dbHelper.database;

    const adminUser = UserModel(
      id: 1,
      name: 'مدير المحطة',
      username: 'admin',
      passwordHash: 'admin123',
      role: 'manager',
    );

    // الخطوة 1: إنشاء عميل تجريبي جديد
    final insertedId = await db.insert('customers', {
      'name': 'شركة الوفاق للنقل والتجارة',
      'type': 'company',
      'phone': '0912345678',
      'credit_limit': 800000.0,
      'current_balance': 150000.0,
    });
    expect(insertedId, isPositive);
    print('-> [الخطوة 1]: تم إنشاء العميل التجريبي بنجاح برقم ID: #$insertedId');

    final checkBefore = await db.query('customers', where: 'id = ?', whereArgs: [insertedId]);
    expect(checkBefore.length, 1);
    print('-> تم تأكيد حفظ العميل في قاعدة البيانات: "${checkBefore.first['name']}" برصيد: ${checkBefore.first['current_balance']} ج.س');

    // الخطوة 2: أخذ نسخة احتياطية يدوية
    final backupPath = p.join(tempDir.path, 'fuel_station_backup_live.db');
    print('\n-> [الخطوة 2]: جاري أخذ نسخة احتياطية يدوية إلى: $backupPath');
    await backupRepo.createManualBackup(backupPath, user: adminUser);
    expect(File(backupPath).existsSync(), isTrue);
    final backupSize = File(backupPath).lengthSync();
    print('-> تم حفظ ملف النسخة الاحتياطية بنجاح بحجم: $backupSize بايت');

    // الخطوة 3: حذف العميل التجريبي من التطبيق
    print('\n-> [الخطوة 3]: جاري حذف العميل التجريبي من قاعدة البيانات...');
    await db.delete('customers', where: 'id = ?', whereArgs: [insertedId]);
    final checkDeleted = await db.query('customers', where: 'id = ?', whereArgs: [insertedId]);
    expect(checkDeleted.isEmpty, isTrue);
    print('-> تم تأكيد حذف العميل: الاستعلام برقم ID #$insertedId أعاد: ${checkDeleted.length} سجل (محذوف فعلياً)');

    // الخطوة 4: استعادة النسخة الاحتياطية
    print('\n-> [الخطوة 4]: جاري استعادة النسخة الاحتياطية من الملف: $backupPath');
    await backupRepo.restoreBackup(backupPath, user: adminUser);
    print('-> تم تنفيذ الاستعادة بنجاح');

    // الخطوة 5: التحقق الصريح من عودة العميل المحذوف بكامل بياناته
    print('\n-> [الخطوة 5]: جاري التحقق الصريح من رجوع العميل المحذوف وبياناته بالتفصيل...');
    final restoredDb = await dbHelper.database;
    final checkRestored = await restoredDb.query('customers', where: 'id = ?', whereArgs: [insertedId]);

    expect(checkRestored.length, 1, reason: 'يجب أن يعود العميل المحذوف بعد الاستعادة');
    final restoredCust = checkRestored.first;
    expect(restoredCust['id'], insertedId);
    expect(restoredCust['name'], 'شركة الوفاق للنقل والتجارة');
    expect(restoredCust['phone'], '0912345678');
    expect(restoredCust['credit_limit'], 800000.0);
    expect(restoredCust['current_balance'], 150000.0);

    print('-> ✅ إثبات قاطع: العميل المحذوف عاد بنجاح 100% بكامل بياناته:');
    print('   - ID: #${restoredCust['id']}');
    print('   - الاسم: ${restoredCust['name']}');
    print('   - الهاتف: ${restoredCust['phone']}');
    print('   - الحد الائتماني: ${restoredCust['credit_limit']} ج.س');
    print('   - الرصيد المستحق: ${restoredCust['current_balance']} ج.س');

    await dbHelper.close();
    tempDir.deleteSync(recursive: true);

    print('\n================================================================');
    print('✅ تم إثبات سيناريو الحفظ، النسخ الاحتياطي، الحذف، والاستعادة بنجاح تام');
    print('================================================================\n');
  });
}
