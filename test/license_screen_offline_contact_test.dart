import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_station_app_pro_android/screens/license/license_screen.dart';
import 'package:fuel_station_app_pro_android/services/license_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LicenseScreen displays offline contact phone and copies on button tap', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Setup cached notifier so screen doesn't get stuck loading
    LicenseService.licenseNotifier.value = LicenseInfo(
      status: LicenseStatus.expired,
      deviceCode: 'TEST-CODE',
      daysRemaining: 0,
      firstRunDate: DateTime.now().subtract(const Duration(days: 8)),
      errorMessage: 'انتهت الفترة التجريبية (7 أيام). يرجى شراء ترخيص دائم لمتابعة استخدام البرنامج.',
    );

    // Mock clipboard channel
    final List<MethodCall> clipboardCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        clipboardCalls.add(methodCall);
        if (methodCall.method == 'Clipboard.setData') {
          return null;
        }
        return null;
      },
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: LicenseScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify WhatsApp button is present
    expect(find.text('تواصل مع المطوّر للحصول على الترخيص (واتساب)'), findsOneWidget);

    // 2. Verify offline phone label and both phone numbers are present
    expect(find.text('أو تواصل عبر أحد الأرقام التالية:'), findsOneWidget);
    expect(find.text('0115715672'), findsOneWidget);
    expect(find.text('0115715651'), findsOneWidget);

    // 3. Verify copy phone buttons are present (one for each number)
    final copyPhoneBtns = find.widgetWithText(OutlinedButton, 'نسخ');
    expect(copyPhoneBtns, findsNWidgets(2));

    await tester.ensureVisible(copyPhoneBtns.first);
    await tester.pumpAndSettle();

    // 4. Tap first copy phone button (0115715672)
    await tester.tap(copyPhoneBtns.first);
    await tester.pump();

    // Verify clipboard received the primary phone number
    final hasFirstCopied = clipboardCalls.any((call) =>
        call.method == 'Clipboard.setData' &&
        call.arguments is Map &&
        (call.arguments as Map)['text'] == '0115715672');
    expect(hasFirstCopied, isTrue, reason: 'Phone number 0115715672 must be copied to clipboard');

    // Verify snackbar is displayed for first number
    expect(find.text('تم نسخ رقم التواصل (0115715672) إلى الحافظة بنجاح'), findsOneWidget);

    // Wait for first snackbar to dismiss
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // 5. Tap second copy phone button (0115715651)
    await tester.ensureVisible(copyPhoneBtns.last);
    await tester.tap(copyPhoneBtns.last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify clipboard received the second phone number
    final hasSecondCopied = clipboardCalls.any((call) =>
        call.method == 'Clipboard.setData' &&
        call.arguments is Map &&
        (call.arguments as Map)['text'] == '0115715651');
    expect(hasSecondCopied, isTrue, reason: 'Phone number 0115715651 must be copied to clipboard');

    // Verify snackbar is displayed for second number
    expect(find.text('تم نسخ رقم التواصل (0115715651) إلى الحافظة بنجاح'), findsOneWidget);
  });
}
