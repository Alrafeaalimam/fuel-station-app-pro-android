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

  final viewports = <String, Size>{
    '360x800 (Compact Mobile)': const Size(360, 800),
    '375x812 (Standard iPhone)': const Size(375, 812),
    '390x844 (Modern Smartphone)': const Size(390, 844),
    '412x915 (Large Android)': const Size(412, 915),
    '600x960 (Phablet / Small Tablet)': const Size(600, 960),
    '768x1024 (Tablet)': const Size(768, 1024),
  };

  for (final entry in viewports.entries) {
    testWidgets('Zero RenderFlex overflow at ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
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

      await tester.pumpWidget(
        MultiRepositoryProvider(
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
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Assert no exceptions thrown (zero RenderFlex overflow)
      expect(tester.takeException(), isNull, reason: 'RenderFlex overflow detected at ${entry.key}');

      // If mobile (< 768), bottom navigation bar should be present
      if (entry.value.width < 768) {
        expect(find.byType(BottomNavigationBar), findsOneWidget);
        expect(find.text('الرئيسية'), findsWidgets);
        expect(find.text('المبيعات'), findsOneWidget);
        expect(find.text('الخزانات'), findsOneWidget);
      } else {
        // Desktop / Tablet layout
        expect(find.byType(BottomNavigationBar), findsNothing);
      }

      // Unmount widgets cleanly and expire any internal sqflite timers
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 11));
    });
  }
}
