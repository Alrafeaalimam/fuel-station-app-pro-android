import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';
import '../bloc/auth/auth_state.dart';
import '../bloc/reports/reports_bloc.dart';
import '../bloc/reports/reports_event.dart';
import '../bloc/shift/shift_bloc.dart';
import '../bloc/shift/shift_event.dart';
import '../bloc/tanks/tank_bloc.dart';
import '../bloc/tanks/tank_event.dart';
import '../bloc/cash_box/cash_box_bloc.dart';
import '../bloc/cash_box/cash_box_event.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'dashboard/dashboard_screen.dart';
import 'shifts/shift_close_screen.dart';
import 'prices/fuel_prices_screen.dart';
import 'deliveries/deliveries_screen.dart';
import 'customers/customers_screen.dart';
import 'cash_box/cash_box_screen.dart';
import 'expenses/expenses_screen.dart';
import 'reports/reports_screen.dart';
import 'shifts/shift_report_screen.dart';
import 'users/users_management_screen.dart';
import 'backup/backup_screen.dart';
import 'tanks/tank_settings_screen.dart';
import '../widgets/change_password_dialog.dart';
import '../config/station_config.dart';
import '../utils/permission_guard.dart';
import '../services/license_service.dart';
import 'license/license_screen.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;
  final ScrollController _sidebarScrollController = ScrollController();

  @override
  void dispose() {
    _sidebarScrollController.dispose();
    super.dispose();
  }

  void _onSelectScreen(int index) {
    final authState = context.read<AuthBloc>().state;
    final currentUser = authState is AuthAuthenticated ? authState.user : null;
    if (index == 7 && !(currentUser?.can(AppPermission.viewStrategicReports) ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('غير مصرح لك بالاطلاع على شاشة التقارير المالية الاستراتيجية (صلاحية خاصة بالمدير).'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }
    if (index == 9 && !(currentUser?.can(AppPermission.manageUsers) ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('غير مصرح لك بالاطلاع على شاشة إدارة المستخدمين (صلاحية خاصة بالمدير).'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }
    if (index == 10 && !(currentUser?.can(AppPermission.manageBackup) ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('غير مصرح لك بالاطلاع على شاشة النسخ الاحتياطي (صلاحية خاصة بالمدير).'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }
    if (index == 11 && !(currentUser?.can(AppPermission.manageTanks) ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('غير مصرح لك بالاطلاع على شاشة إعدادات الخزانات (صلاحية خاصة بالمدير).'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }
    setState(() {
      _selectedIndex = index;
    });

    // Auto refresh data for screens when navigated to
    if (index == 7) {
      context.read<ReportsBloc>().add(const LoadFinancialSummaryReport());
    } else if (index == 1) {
      context.read<ShiftBloc>().add(LoadShiftClosingData());
    } else if (index == 0) {
      context.read<TankBloc>().add(LoadTanksAndPumps());
      context.read<CashBoxBloc>().add(LoadCashBox());
    }
  }

  int _getBottomNavIndex(int screenIndex) {
    switch (screenIndex) {
      case 0:
        return 0; // الرئيسية
      case 1:
        return 1; // المبيعات / الوردية
      case 11:
        return 2; // الخزانات
      case 8:
      case 7:
        return 3; // التقارير
      default:
        return 4; // المزيد
    }
  }

  void _onBottomNavTapped(int navIndex) {
    switch (navIndex) {
      case 0:
        _onSelectScreen(0);
        break;
      case 1:
        _onSelectScreen(1);
        break;
      case 2:
        _onSelectScreen(11);
        break;
      case 3:
        _onSelectScreen(8);
        break;
      case 4:
        _scaffoldKey.currentState?.openDrawer();
        break;
    }
  }

  void _showEditStationNameDialog(BuildContext context) {
    final controller = TextEditingController(text: StationConfig.stationName);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Text('تعديل اسم المحطة'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'سيظهر هذا الاسم في ترويسة التطبيق والتقارير المطبوعة وشاشة الدخول.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'اسم المحطة',
                hintText: 'أدخل اسم المحطة الجديد',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await StationConfig.setStationName(newName);
                if (context.mounted) {
                  Navigator.of(dialogCtx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم تعديل اسم المحطة إلى: "$newName"'),
                      backgroundColor: AppTheme.successGreen,
                    ),
                  );
                }
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final currentUser = authState is AuthAuthenticated ? authState.user : null;

    final List<Widget> screens = [
      DashboardScreen(onNavigate: _onSelectScreen),
      const ShiftCloseScreen(),
      const FuelPricesScreen(),
      const DeliveriesScreen(),
      const CustomersScreen(),
      const CashBoxScreen(),
      const ExpensesScreen(),
      (currentUser?.can(AppPermission.viewStrategicReports) ?? false)
          ? const ReportsScreen()
          : const Center(
              child: Text(
                'غير مصرح لك بالاطلاع على التقارير المالية الاستراتيجية والأرباح.\nهذه الصلاحية خاصة بمدير المحطة فقط.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppTheme.dangerRed, fontWeight: FontWeight.bold),
              ),
            ),
      const ShiftReportScreen(),
      (currentUser?.can(AppPermission.manageUsers) ?? false)
          ? const UsersManagementScreen()
          : const Center(
              child: Text(
                'غير مصرح لك بالاطلاع على شاشة إدارة المستخدمين.\nهذه الصلاحية خاصة بمدير المحطة فقط.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppTheme.dangerRed, fontWeight: FontWeight.bold),
              ),
            ),
      (currentUser?.can(AppPermission.manageBackup) ?? false)
          ? const BackupScreen()
          : const Center(
              child: Text(
                'غير مصرح لك بالاطلاع على شاشة النسخ الاحتياطي.\nهذه الصلاحية خاصة بمدير المحطة فقط.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppTheme.dangerRed, fontWeight: FontWeight.bold),
              ),
            ),
      (currentUser?.can(AppPermission.manageTanks) ?? false)
          ? const TankSettingsScreen()
          : const Center(
              child: Text(
                'غير مصرح لك بالاطلاع على شاشة إعدادات الخزانات.\nهذه الصلاحية خاصة بمدير المحطة فقط.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppTheme.dangerRed, fontWeight: FontWeight.bold),
              ),
            ),
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      key: _scaffoldKey,
      drawer: isMobile
          ? Drawer(
              backgroundColor: AppTheme.sidebarBg,
              child: SafeArea(
                child: _buildSidebarContent(context, currentUser, isCollapsed: false, isDrawer: true),
              ),
            )
          : null,
      bottomNavigationBar: isMobile
          ? Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.darkBorder, width: 1)),
              ),
              child: BottomNavigationBar(
                currentIndex: _getBottomNavIndex(_selectedIndex),
                onTap: _onBottomNavTapped,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.dashboard_rounded),
                    label: 'الرئيسية',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.lock_clock_rounded),
                    label: 'المبيعات',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.storage_rounded),
                    label: 'الخزانات',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.assessment_rounded),
                    label: 'التقارير',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.menu_rounded),
                    label: 'المزيد',
                  ),
                ],
              ),
            )
          : null,
      body: Row(
        children: [
          // Sidebar Navigation (Desktop / Tablet)
          if (!isMobile) _buildSidebar(context, currentUser),
          // Main Content View
          Expanded(
            child: Column(
              children: [
                // Top App Header
                _buildTopHeader(context, currentUser, isMobile: isMobile),
                // Trial Warning Banner (Sleek Pill)
                _buildTrialBanner(context),
                // Screen Content
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: IndexedStack(
                      key: ValueKey<int>(_selectedIndex),
                      index: _selectedIndex,
                      children: screens,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context, UserModel? user, {required bool isMobile}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 58,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBg : Colors.white,
        border: Border(
          bottom: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                if (isMobile)
                  IconButton(
                    icon: Icon(Icons.menu_rounded, color: isDark ? AppTheme.textLight : AppTheme.primaryNavy),
                    tooltip: 'القائمة الرئيسية',
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                Flexible(
                  child: ValueListenableBuilder<String>(
                    valueListenable: StationConfig.stationNameNotifier,
                    builder: (context, stationName, _) {
                      return InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: user?.isManager == true
                            ? () => _showEditStationNameDialog(context)
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: isDark ? 0.18 : 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.primaryBlue.withValues(alpha: isDark ? 0.35 : 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_gas_station_rounded, size: 16, color: AppTheme.primaryCyan),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  stationName,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppTheme.textLight : AppTheme.primaryBlue,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                              if (user?.isManager == true) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.edit_outlined, size: 13, color: AppTheme.primaryCyan),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // User info badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.transparent),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: user?.isManager == true
                          ? AppTheme.primaryBlue
                          : AppTheme.dieselColor,
                      child: Text(
                        user?.name.isNotEmpty == true ? user!.name.substring(0, 1) : 'م',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (!isMobile) ...[
                      const SizedBox(width: 6),
                      Text(
                        user?.name ?? 'المستخدم',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isDark ? AppTheme.textLight : AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: user?.isManager == true
                              ? Colors.indigo.withValues(alpha: 0.15)
                              : Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          user?.roleArabic ?? '',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: user?.isManager == true ? AppTheme.primaryCyan : Colors.deepOrange,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: Icon(Icons.vpn_key_rounded, size: 18, color: isDark ? AppTheme.textMuted : AppTheme.primaryNavy),
                tooltip: 'تغيير كلمة المرور',
                onPressed: () {
                  if (user != null) {
                    showDialog(
                      context: context,
                      builder: (ctx) => ChangePasswordDialog(currentUser: user),
                    );
                  }
                },
              ),
              IconButton(
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: const Icon(Icons.logout_rounded, size: 18, color: AppTheme.dangerRed),
                tooltip: 'تسجيل الخروج',
                onPressed: () {
                  context.read<AuthBloc>().add(AuthLogoutRequested());
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrialBanner(BuildContext context) {
    return ValueListenableBuilder<LicenseInfo>(
      valueListenable: LicenseService.licenseNotifier,
      builder: (context, info, _) {
        if (!info.isTrial) return const SizedBox.shrink();

        final days = info.daysRemaining;
        final isUrgent = days <= 2;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        String dayText;
        if (days == 1) {
          dayText = 'متبقي يوم واحد فقط!';
        } else if (days == 2) {
          dayText = 'متبقي يومان فقط!';
        } else {
          dayText = 'متبقي $days أيام';
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUrgent
                  ? AppTheme.dangerRed.withValues(alpha: 0.5)
                  : AppTheme.primaryBlue.withValues(alpha: 0.4),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUrgent ? AppTheme.dangerRed : AppTheme.primaryCyan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'الفترة التجريبية: $dayText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? AppTheme.textLight : AppTheme.primaryNavy,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                child: ElevatedButton.icon(
                  onPressed: () => _openActivationScreen(context),
                  icon: const Icon(Icons.key_rounded, size: 14),
                  label: const Text(
                    'تفعيل الترخيص',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(110, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openActivationScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LicenseScreen(isDismissible: true),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, UserModel? user) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 850;
    final isCollapsed = _isSidebarCollapsed || isNarrow;
    final sidebarWidth = isCollapsed ? 68.0 : 240.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: sidebarWidth,
      child: _buildSidebarContent(context, user, isCollapsed: isCollapsed, isDrawer: false),
    );
  }

  Widget _buildSidebarContent(
    BuildContext context,
    UserModel? user, {
    required bool isCollapsed,
    bool isDrawer = false,
  }) {
    return Material(
      color: AppTheme.sidebarBg,
      child: Column(
        children: [
          // Station Brand Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 4 : 16, vertical: 12),
            child: isCollapsed
                ? Center(
                    child: IconButton(
                      icon: const Icon(Icons.local_gas_station_rounded, color: Colors.cyanAccent, size: 26),
                      tooltip: 'توسيع القائمة',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      onPressed: () {
                        setState(() {
                          _isSidebarCollapsed = false;
                        });
                      },
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.local_gas_station_rounded, color: Colors.cyanAccent, size: 28),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'نظام المحطة',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'إدارة وتشغيل الوقود Pro',
                              style: TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      if (isDrawer)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                          tooltip: 'إغلاق القائمة',
                          onPressed: () => Navigator.of(context).pop(),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 20),
                          tooltip: 'تصغير القائمة',
                          onPressed: () {
                            setState(() {
                              _isSidebarCollapsed = true;
                            });
                          },
                        ),
                    ],
                  ),
          ),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),

          // Scrollable Area containing all navigation items, password action, and footer
          Expanded(
            child: Scrollbar(
              controller: _sidebarScrollController,
              thumbVisibility: true,
              child: ListView(
                controller: _sidebarScrollController,
                padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 6 : 10, vertical: 8),
                children: [
                  _buildNavItem(0, 'لوحة التحكم', Icons.dashboard_rounded, isCollapsed, isDrawer),
                  _buildNavItem(1, 'قفل الوردية', Icons.lock_clock_rounded, isCollapsed, isDrawer),
                  _buildNavItem(2, 'تسعير الوقود', Icons.price_change_rounded, isCollapsed, isDrawer),
                  _buildNavItem(3, 'سجل التوريد', Icons.local_shipping_rounded, isCollapsed, isDrawer),
                  _buildNavItem(4, 'العملاء والآجل', Icons.people_alt_rounded, isCollapsed, isDrawer),
                  _buildNavItem(5, 'الخزنة اليومية', Icons.account_balance_wallet_rounded, isCollapsed, isDrawer),
                  _buildNavItem(6, 'المصروفات', Icons.receipt_long_rounded, isCollapsed, isDrawer),
                  if (user?.can(AppPermission.viewStrategicReports) ?? false)
                    _buildNavItem(7, 'التقارير المالية', Icons.bar_chart_rounded, isCollapsed, isDrawer),
                  _buildNavItem(8, 'تقرير اليومية (طباعة)', Icons.print_rounded, isCollapsed, isDrawer),
                  if (user?.can(AppPermission.manageUsers) ?? false)
                    _buildNavItem(9, 'إدارة المستخدمين', Icons.manage_accounts_rounded, isCollapsed, isDrawer),
                  if (user?.can(AppPermission.manageBackup) ?? false)
                    _buildNavItem(10, 'النسخ الاحتياطي', Icons.backup_rounded, isCollapsed, isDrawer),
                  if (user?.can(AppPermission.manageTanks) ?? false)
                    _buildNavItem(11, 'إعدادات الخزانات', Icons.storage_rounded, isCollapsed, isDrawer),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 8),
                  // Change password shortcut
                  if (isCollapsed)
                    Tooltip(
                      message: 'تغيير كلمة المرور',
                      preferBelow: false,
                      child: IconButton(
                        icon: const Icon(Icons.lock_reset_rounded, color: Colors.white70, size: 22),
                        onPressed: () {
                          if (user != null) {
                            showDialog(
                              context: context,
                              builder: (ctx) => ChangePasswordDialog(currentUser: user),
                            );
                          }
                        },
                      ),
                    )
                  else
                    ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      leading: const Icon(Icons.lock_reset_rounded, color: Colors.white70, size: 20),
                      title: const Text(
                        'تغيير كلمة المرور',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      onTap: () {
                        if (isDrawer) Navigator.of(context).pop();
                        if (user != null) {
                          showDialog(
                            context: context,
                            builder: (ctx) => ChangePasswordDialog(currentUser: user),
                          );
                        }
                      },
                    ),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white12, height: 1),
                  if (!isCollapsed)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                      child: Text(
                        'Fuel Station Pro - Android v1.0',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon, bool isCollapsed, [bool isDrawer = false]) {
    final isSelected = _selectedIndex == index;

    void handleTap() {
      if (isDrawer) {
        Navigator.of(context).pop();
      }
      _onSelectScreen(index);
    }

    if (isCollapsed) {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        child: Tooltip(
          message: label,
          preferBelow: false,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: handleTap,
            child: Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade400,
                size: 22,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selected: isSelected,
        selectedTileColor: AppTheme.primaryBlue,
        leading: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.grey.shade400,
          size: 20,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade300,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
        onTap: handleTap,
      ),
    );
  }
}
