import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../data/database_helper.dart';

/// خدمة إدارة حالة الشاشة الترحيبية (Onboarding)
/// تخزن حالة المشاهدة في جدول settings في قاعدة البيانات المحلية دون تعديل الهيكل.
class OnboardingService {
  /// المنبه المرجعي لحالة مشاهدة شاشة الترحيب
  static final ValueNotifier<bool> hasSeenOnboardingNotifier =
      ValueNotifier<bool>(true);

  static const String settingsKey = 'has_seen_onboarding';
  static DatabaseHelper? testDbHelper;

  /// فحص وتحميل حالة المشاهدة من قاعدة البيانات
  static Future<void> loadOnboardingStatus({DatabaseHelper? dbHelper}) async {
    try {
      final helper = dbHelper ?? testDbHelper ?? DatabaseHelper.instance;
      final db = await helper.database;
      final maps = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: [settingsKey],
      );
      if (maps.isNotEmpty && maps.first['value'] != null) {
        final val = maps.first['value'].toString().trim().toLowerCase();
        hasSeenOnboardingNotifier.value = (val == 'true' || val == '1');
      } else {
        // لم يتم العثور على السجل -> أول تشغيل للتطبيق -> عرض Onboarding
        hasSeenOnboardingNotifier.value = false;
      }
    } catch (_) {
      // في حال تعذر القراءة في بيئة غير معتادة، افتراض القيمة الافتراضية
      hasSeenOnboardingNotifier.value = false;
    }
  }

  /// تسجيل إتمام مشاهدة Onboarding وتثبيت ذلك في قاعدة البيانات
  static Future<void> completeOnboarding({DatabaseHelper? dbHelper}) async {
    hasSeenOnboardingNotifier.value = true;
    try {
      final helper = dbHelper ?? testDbHelper ?? DatabaseHelper.instance;
      final db = await helper.database;
      await db.insert(
        'settings',
        {'key': settingsKey, 'value': 'true'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  /// إعادة تعيين الحالة (مخصص لبيئة الاختبارات الآلية)
  @visibleForTesting
  static void setMockHasSeen(bool value) {
    hasSeenOnboardingNotifier.value = value;
  }
}
