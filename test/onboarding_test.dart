import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_station_app_pro_android/data/database_helper.dart';
import 'package:fuel_station_app_pro_android/screens/onboarding/onboarding_screen.dart';
import 'package:fuel_station_app_pro_android/services/onboarding_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('OnboardingService Tests', () {
    late Database db;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (d, v) async {
          await d.execute('''
            CREATE TABLE settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        },
      );
      OnboardingService.testDbHelper = DatabaseHelper.withDatabase(db);
    });

    tearDown(() async {
      OnboardingService.testDbHelper = null;
      await db.close();
    });

    test('Initial check returns false on fresh installation and true after completion', () async {
      // Simulate fresh database without settingsKey
      await OnboardingService.loadOnboardingStatus();
      expect(OnboardingService.hasSeenOnboardingNotifier.value, isFalse);

      // Complete onboarding
      await OnboardingService.completeOnboarding();
      expect(OnboardingService.hasSeenOnboardingNotifier.value, isTrue);

      // Verify persisted in DB
      final maps = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: [OnboardingService.settingsKey],
      );
      expect(maps.isNotEmpty, isTrue);
      expect(maps.first['value'], 'true');

      // Next load returns true
      await OnboardingService.loadOnboardingStatus();
      expect(OnboardingService.hasSeenOnboardingNotifier.value, isTrue);
    });

    test('Notifier default and testing mock toggle', () {
      OnboardingService.setMockHasSeen(false);
      expect(OnboardingService.hasSeenOnboardingNotifier.value, isFalse);

      OnboardingService.setMockHasSeen(true);
      expect(OnboardingService.hasSeenOnboardingNotifier.value, isTrue);
    });
  });

  group('OnboardingScreen Widget Tests', () {
    late Database db;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (d, v) async {
          await d.execute('''
            CREATE TABLE settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        },
      );
      OnboardingService.testDbHelper = DatabaseHelper.withDatabase(db);
    });

    tearDown(() async {
      OnboardingService.testDbHelper = null;
      await db.close();
    });

    Widget buildTestableOnboarding({Size size = const Size(390, 844)}) {
      return MaterialApp(
        theme: ThemeData(fontFamily: 'NotoNaskhArabic'),
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: MediaQueryData(size: size),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: const OnboardingScreen(),
      );
    }

    testWidgets('Renders Page 1 with title, description, and "تخطي" button', (tester) async {
      OnboardingService.setMockHasSeen(false);
      await tester.pumpWidget(buildTestableOnboarding());
      await tester.pumpAndSettle();

      expect(find.text('إدارة كاملة لمحطتك'), findsOneWidget);
      expect(
        find.text('نظام متكامل يساعدك على إدارة محطة الوقود ومتابعة المبيعات والمضخات والعمليات اليومية بسهولة.'),
        findsOneWidget,
      );
      expect(find.text('تخطي'), findsOneWidget);
      expect(find.text('التالي'), findsOneWidget);
    });

    testWidgets('Navigates across all 3 pages and shows "دخول النظام" on page 3', (tester) async {
      OnboardingService.setMockHasSeen(false);
      await tester.pumpWidget(buildTestableOnboarding());
      await tester.pumpAndSettle();

      // Page 1
      expect(find.text('إدارة كاملة لمحطتك'), findsOneWidget);

      // Tap "التالي" -> Page 2
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();

      expect(find.text('تابع التشغيل والمبيعات'), findsOneWidget);
      expect(
        find.text('إدارة المضخات والعدادات والورديات والمبيعات والمدفوعات، مع متابعة دقيقة لكل العمليات.'),
        findsOneWidget,
      );
      expect(find.text('التالي'), findsOneWidget);

      // Tap "التالي" -> Page 3
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();

      expect(find.text('تقارير وتحكم أفضل'), findsOneWidget);
      expect(
        find.text('تابع التقارير اليومية والحسابات والعجز والزيادة والمصروفات، واحفظ بيانات محطتك بأمان.'),
        findsOneWidget,
      );
      expect(find.text('دخول النظام'), findsOneWidget);

      // Tap "دخول النظام"
      await tester.tap(find.text('دخول النظام'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify that onboarding is marked complete
      expect(OnboardingService.hasSeenOnboardingNotifier.value, isTrue);
    });

    testWidgets('Tapping "تخطي" on page 1 completes onboarding immediately', (tester) async {
      OnboardingService.setMockHasSeen(false);
      await tester.pumpWidget(buildTestableOnboarding());
      await tester.pumpAndSettle();

      expect(find.text('تخطي'), findsOneWidget);
      await tester.tap(find.text('تخطي'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(OnboardingService.hasSeenOnboardingNotifier.value, isTrue);
    });

    testWidgets('Responsive check on narrow phone (360x640) without overflow', (tester) async {
      OnboardingService.setMockHasSeen(false);
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableOnboarding(size: const Size(360, 640)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('إدارة كاملة لمحطتك'), findsOneWidget);

      // Next to Page 2
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('تابع التشغيل والمبيعات'), findsOneWidget);

      // Next to Page 3
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('تقارير وتحكم أفضل'), findsOneWidget);
    });

    testWidgets('Responsive check on (375x667), (390x844), and (412x915) without overflow', (tester) async {
      for (final size in [const Size(375, 667), const Size(390, 844), const Size(412, 915)]) {
        OnboardingService.setMockHasSeen(false);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(buildTestableOnboarding(size: size));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('إدارة كاملة لمحطتك'), findsOneWidget);
      }
      tester.view.resetPhysicalSize();
    });
  });
}
