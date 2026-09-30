import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fuel_station_app_pro_android/bloc/auth/auth_bloc.dart';
import 'package:fuel_station_app_pro_android/bloc/auth/auth_state.dart';
import 'package:fuel_station_app_pro_android/data/database_helper.dart';
import 'package:fuel_station_app_pro_android/data/repositories/auth_repository.dart';
import 'package:fuel_station_app_pro_android/data/repositories/backup_repository.dart';
import 'package:fuel_station_app_pro_android/models/models.dart';
import 'package:fuel_station_app_pro_android/screens/auth/login_screen.dart';
import 'package:fuel_station_app_pro_android/screens/backup/backup_screen.dart';
import 'package:fuel_station_app_pro_android/theme/app_theme.dart';

import 'package:fuel_station_app_pro_android/services/license_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    LicenseService.setMockRawDeviceId('UI_TEST_HARDWARE_123');
  });

  tearDownAll(() {
    LicenseService.setMockRawDeviceId(null);
  });

  group('UI Visibility & Contrast Verification Tests', () {
    late Database testDb;
    late DatabaseHelper dbHelper;
    late AuthRepository authRepo;
    late BackupRepository backupRepo;

    late Directory tempDir;
    late String dbFilePath;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('ui_test_');
      dbFilePath = '${tempDir.path}/fuel_station_pro.db';
      testDb = await databaseFactoryFfi.openDatabase(
        dbFilePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) => DatabaseHelper.instance.createDBForTesting(db),
        ),
      );
      dbHelper = DatabaseHelper.withDatabase(testDb, dbPath: dbFilePath);
      authRepo = AuthRepository(dbHelper: dbHelper);
      backupRepo = BackupRepository(dbHelper: dbHelper);
    });

    tearDown(() async {
      await testDb.close();
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });


    testWidgets('Login Screen: Demo credentials buttons have high-contrast dark navy text (#0F172A), bold font, border, and white background', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authBloc = AuthBloc(authRepository: authRepo);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: BlocProvider.value(
              value: authBloc,
              child: const LoginScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find quick accounts section
      expect(find.text('حسابات تجريبية سريعة:'), findsOneWidget);
      expect(find.text('مدير النظام'), findsOneWidget);
      expect(find.text('محاسب الوردية'), findsOneWidget);

      // Verify text styling of demo buttons
      final adminTextFinder = find.text('مدير النظام');
      final adminTextWidget = tester.widget<Text>(adminTextFinder);
      expect(adminTextWidget.style?.color, equals(const Color(0xFF0F172A)));
      expect(adminTextWidget.style?.fontWeight, equals(FontWeight.w600));

      final accountantTextFinder = find.text('محاسب الوردية');
      final accountantTextWidget = tester.widget<Text>(accountantTextFinder);
      expect(accountantTextWidget.style?.color, equals(const Color(0xFF0F172A)));
      expect(accountantTextWidget.style?.fontWeight, equals(FontWeight.w600));

      // Verify button style properties (background, border, foreground)
      final adminBtnFinder = find.widgetWithText(OutlinedButton, 'مدير النظام');
      final adminBtn = tester.widget<OutlinedButton>(adminBtnFinder);
      expect(adminBtn.style?.foregroundColor?.resolve({}), equals(const Color(0xFF0F172A)));
      expect(adminBtn.style?.backgroundColor?.resolve({}), equals(const Color(0xFFFFFFFF)));
      expect(adminBtn.style?.side?.resolve({})?.color, equals(const Color(0xFFCBD5E1)));

      final accountantBtnFinder = find.widgetWithText(OutlinedButton, 'محاسب الوردية');
      final accountantBtn = tester.widget<OutlinedButton>(accountantBtnFinder);
      expect(accountantBtn.style?.foregroundColor?.resolve({}), equals(const Color(0xFF0F172A)));
      expect(accountantBtn.style?.backgroundColor?.resolve({}), equals(const Color(0xFFFFFFFF)));
      expect(accountantBtn.style?.side?.resolve({})?.color, equals(const Color(0xFFCBD5E1)));

      // Verify clicking fills input fields
      await tester.tap(accountantBtnFinder);
      await tester.pump();
      expect(find.text('accountant'), findsOneWidget);
    });

    testWidgets('Backup Screen: Header text is crisp white (#FFFFFF) with cool gray (#94A3B8) subtitle and banner does not collapse horizontally', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const manager = UserModel(
        id: 1,
        name: 'المدير العام',
        username: 'admin',
        passwordHash: 'hash',
        role: 'manager',
      );

      final authBloc = AuthBloc(authRepository: authRepo);
      authBloc.emit(const AuthAuthenticated(manager));

      await tester.runAsync(() async {
        await tester.pumpWidget(
          MultiRepositoryProvider(
            providers: [
              RepositoryProvider.value(value: backupRepo),
              RepositoryProvider.value(value: authRepo),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: BlocProvider.value(
                  value: authBloc,
                  child: const BackupScreen(),
                ),
              ),
            ),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();

      // Check Header Title Contrast
      final headerFinder = find.text('النسخ الاحتياطي واستعادة البيانات');
      expect(headerFinder, findsOneWidget);
      final headerTextWidget = tester.widget<Text>(headerFinder);
      expect(headerTextWidget.style?.color, equals(const Color(0xFFFFFFFF)));

      // Check Header Subtitle Contrast
      final subtitleFinder = find.text('حماية بيانات المحطة عبر النسخ اليدوي الخارجي والنسخ التلقائي اليومي');
      expect(subtitleFinder, findsOneWidget);
      final subtitleTextWidget = tester.widget<Text>(subtitleFinder);
      expect(subtitleTextWidget.style?.color, equals(const Color(0xFF94A3B8)));

      // Check card headings are crisp white
      final statusCardTitle = find.text('حالة قاعدة البيانات الحالية');
      expect(statusCardTitle, findsOneWidget);
      final statusTitleWidget = tester.widget<Text>(statusCardTitle);
      expect(statusTitleWidget.style?.color, equals(Colors.white));

      // Assert zero RenderFlex overflow
      expect(tester.takeException(), isNull);
    });
  });
}
