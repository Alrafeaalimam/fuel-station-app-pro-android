import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fuel_station_app_pro_android/data/database_helper.dart';
import 'package:fuel_station_app_pro_android/data/repositories/shift_repository.dart';
import 'package:fuel_station_app_pro_android/data/repositories/tank_repository.dart';
import 'package:fuel_station_app_pro_android/data/repositories/fuel_price_repository.dart';
import 'package:fuel_station_app_pro_android/data/repositories/customer_repository.dart';
import 'package:fuel_station_app_pro_android/data/repositories/report_repository.dart';
import 'package:fuel_station_app_pro_android/data/repositories/delivery_repository.dart';
import 'package:fuel_station_app_pro_android/data/repositories/backup_repository.dart';
import 'package:fuel_station_app_pro_android/data/repositories/cash_box_repository.dart';
import 'package:fuel_station_app_pro_android/data/repositories/expense_repository.dart';
import 'package:fuel_station_app_pro_android/data/repositories/auth_repository.dart';
import 'package:fuel_station_app_pro_android/bloc/shift/shift_bloc.dart';
import 'package:fuel_station_app_pro_android/bloc/reports/reports_bloc.dart';
import 'package:fuel_station_app_pro_android/bloc/auth/auth_bloc.dart';
import 'package:fuel_station_app_pro_android/bloc/auth/auth_state.dart';
import 'package:fuel_station_app_pro_android/bloc/tanks/tank_bloc.dart';
import 'package:fuel_station_app_pro_android/bloc/prices/fuel_price_bloc.dart';
import 'package:fuel_station_app_pro_android/bloc/cash_box/cash_box_bloc.dart';
import 'package:fuel_station_app_pro_android/bloc/customers/customer_bloc.dart';
import 'package:fuel_station_app_pro_android/bloc/deliveries/delivery_bloc.dart';
import 'package:fuel_station_app_pro_android/bloc/expenses/expense_bloc.dart';
import 'package:fuel_station_app_pro_android/models/models.dart';
import 'package:fuel_station_app_pro_android/screens/main_navigation_shell.dart';
import 'package:fuel_station_app_pro_android/services/license_service.dart';
import 'package:fuel_station_app_pro_android/config/station_config.dart';
import 'package:fuel_station_app_pro_android/theme/app_theme.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late DatabaseHelper dbHelper;
  late ShiftRepository shiftRepo;
  late TankRepository tankRepo;
  late FuelPriceRepository priceRepo;
  late CustomerRepository customerRepo;
  late ReportRepository reportRepo;
  late DeliveryRepository deliveryRepo;
  late BackupRepository backupRepo;
  late CashBoxRepository cashBoxRepo;
  late ExpenseRepository expRepo;
  late AuthRepository authRepo;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    dbHelper = DatabaseHelper.withDatabase(db);
    await dbHelper.createDBForTesting(db);

    backupRepo = BackupRepository(dbHelper: dbHelper);
    shiftRepo = ShiftRepository(dbHelper: dbHelper, backupRepo: backupRepo);
    tankRepo = TankRepository(dbHelper: dbHelper);
    priceRepo = FuelPriceRepository(dbHelper: dbHelper);
    customerRepo = CustomerRepository(dbHelper: dbHelper);
    reportRepo = ReportRepository(dbHelper: dbHelper);
    deliveryRepo = DeliveryRepository(dbHelper: dbHelper);
    cashBoxRepo = CashBoxRepository(dbHelper: dbHelper);
    expRepo = ExpenseRepository(dbHelper: dbHelper);
    authRepo = AuthRepository(dbHelper: dbHelper);
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTestWidget({required Size size, FakeViewPadding? padding}) {
    const manager = UserModel(
      id: 1,
      name: 'المهندس أحمد',
      username: 'admin',
      passwordHash: 'hash',
      role: 'manager',
    );

    final authBloc = AuthBloc(authRepository: authRepo);
    authBloc.emit(const AuthAuthenticated(manager));

    final tankB = TankBloc(tankRepository: tankRepo);
    final priceB = FuelPriceBloc(fuelPriceRepository: priceRepo);
    final shiftB = ShiftBloc(
      shiftRepository: shiftRepo,
      tankRepository: tankRepo,
      fuelPriceRepository: priceRepo,
      customerRepository: customerRepo,
    );
    final custB = CustomerBloc(customerRepository: customerRepo);
    final delivB = DeliveryBloc(deliveryRepository: deliveryRepo, tankRepository: tankRepo);
    final cashB = CashBoxBloc(cashBoxRepository: cashBoxRepo);
    final expB = ExpenseBloc(expenseRepository: expRepo);
    final repB = ReportsBloc(reportRepository: reportRepo);

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepo),
        RepositoryProvider.value(value: tankRepo),
        RepositoryProvider.value(value: priceRepo),
        RepositoryProvider.value(value: shiftRepo),
        RepositoryProvider.value(value: customerRepo),
        RepositoryProvider.value(value: deliveryRepo),
        RepositoryProvider.value(value: cashBoxRepo),
        RepositoryProvider.value(value: expRepo),
        RepositoryProvider.value(value: reportRepo),
        RepositoryProvider.value(value: backupRepo),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: authBloc),
          BlocProvider.value(value: tankB),
          BlocProvider.value(value: priceB),
          BlocProvider.value(value: shiftB),
          BlocProvider.value(value: custB),
          BlocProvider.value(value: delivB),
          BlocProvider.value(value: cashB),
          BlocProvider.value(value: expB),
          BlocProvider.value(value: repB),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: MainNavigationShell(),
          ),
        ),
      ),
    );
  }

  testWidgets('Mobile header stays below Android status bar (SafeArea inset verification)', (tester) async {
    const statusInset = 48.0;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: statusInset, bottom: 20);

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
    });

    await tester.pumpWidget(createTestWidget(size: const Size(390, 844)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Hamburger button is rendered at or below the status bar inset
    final hamburgerFinder = find.byTooltip('القائمة الرئيسية');
    expect(hamburgerFinder, findsOneWidget);
    final hamburgerTop = tester.getTopLeft(hamburgerFinder).dy;
    expect(hamburgerTop, greaterThanOrEqualTo(statusInset),
        reason: 'Hamburger button should stay below Android status bar inset');

    // Verify Station identity is also below status inset
    final subtitleFinder = find.text('نظام إدارة المحطة');
    expect(subtitleFinder, findsOneWidget);
    final subtitleTop = tester.getTopLeft(subtitleFinder).dy;
    expect(subtitleTop, greaterThanOrEqualTo(statusInset),
        reason: 'Station identity should stay below Android status bar inset');

    // Verify User action is also below status inset
    final userActionFinder = find.byTooltip('بيانات الحساب');
    expect(userActionFinder, findsOneWidget);
    final userActionTop = tester.getTopLeft(userActionFinder).dy;
    expect(userActionTop, greaterThanOrEqualTo(statusInset),
        reason: 'User profile action should stay below Android status bar inset');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('Hamburger button opens existing Drawer', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget(size: const Size(360, 800)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap the hamburger icon
    final hamburgerFinder = find.byTooltip('القائمة الرئيسية');
    expect(hamburgerFinder, findsOneWidget);
    await tester.tap(hamburgerFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // Verify that the existing drawer opened and contains its items
    expect(find.text('لوحة التحكم'), findsWidgets);
    expect(find.text('قفل الوردية'), findsWidgets);
    expect(find.text('تسعير الوقود'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('Station name is dynamically displayed and tap opens edit dialog for manager', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget(size: const Size(360, 800)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Station name and subtitle should be present
    expect(find.text(StationConfig.stationName), findsWidgets);
    expect(find.text('نظام إدارة المحطة'), findsOneWidget);

    // Tap station name to open edit dialog
    await tester.tap(find.text('نظام إدارة المحطة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('تعديل اسم المحطة'), findsOneWidget);
    expect(find.text('إلغاء'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('User action button displays user info and options', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget(size: const Size(360, 800)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap user account button
    final userActionFinder = find.byTooltip('بيانات الحساب');
    expect(userActionFinder, findsOneWidget);
    await tester.tap(userActionFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Popup menu displays user name, change password, and logout
    expect(find.text('المهندس أحمد'), findsWidgets);
    expect(find.text('مدير المحطة'), findsOneWidget);
    expect(find.text('تغيير كلمة المرور'), findsOneWidget);
    expect(find.text('تسجيل الخروج'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('Trial banner appears compactly below header and disappears when licensed', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 1. Simulate trial license with 5 days remaining
    LicenseService.licenseNotifier.value = const LicenseInfo(
      status: LicenseStatus.trial,
      deviceCode: 'TEST-DEVICE-1234',
      daysRemaining: 5,
    );

    await tester.pumpWidget(createTestWidget(size: const Size(360, 800)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify trial banner is visible with expected texts
    final trialTextFinder = find.textContaining('الفترة التجريبية: متبقي 5 أيام');
    expect(trialTextFinder, findsOneWidget);
    final activateBtnFinder = find.text('تفعيل الترخيص');
    expect(activateBtnFinder, findsOneWidget);

    // Verify compact height (should be <= 48px per requirement)
    final bannerContainerFinder = find.ancestor(
      of: trialTextFinder,
      matching: find.byType(Container),
    ).first;
    final bannerSize = tester.getSize(bannerContainerFinder);
    expect(bannerSize.height, lessThanOrEqualTo(48.0));

    // 2. Simulate active license -> banner should disappear cleanly
    LicenseService.licenseNotifier.value = const LicenseInfo(
      status: LicenseStatus.active,
      deviceCode: 'TEST-DEVICE-1234',
      daysRemaining: 365,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('الفترة التجريبية'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
  });
}
