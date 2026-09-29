import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/tanks/tank_bloc.dart';
import '../../bloc/tanks/tank_state.dart';
import '../../bloc/tanks/tank_event.dart';
import '../../bloc/prices/fuel_price_bloc.dart';
import '../../bloc/prices/fuel_price_state.dart';
import '../../bloc/prices/fuel_price_event.dart';
import '../../bloc/cash_box/cash_box_bloc.dart';
import '../../bloc/cash_box/cash_box_state.dart';
import '../../bloc/cash_box/cash_box_event.dart';
import '../../bloc/customers/customer_bloc.dart';
import '../../bloc/customers/customer_state.dart';
import '../../bloc/customers/customer_event.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/tank_level_card.dart';
import '../../widgets/quick_action_card.dart';
import '../../config/station_config.dart';
import '../../utils/permission_guard.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const DashboardScreen({super.key, required this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  void _refreshAll() {
    context.read<TankBloc>().add(LoadTanksAndPumps());
    context.read<FuelPriceBloc>().add(LoadFuelPrices());
    context.read<CashBoxBloc>().add(LoadCashBox());
    context.read<CustomerBloc>().add(LoadCustomers());
  }

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat('#,##0', 'en_US');
    final authState = context.watch<AuthBloc>().state;
    final currentUser = authState is AuthAuthenticated ? authState.user : null;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _refreshAll(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 14.0 : 24.0,
            vertical: isMobile ? 12.0 : 20.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Station Greeting & Quick Shift Trigger
              _buildGreetingHeader(currentUser, isMobile, isDark),
              SizedBox(height: isMobile ? 14 : 20),

              // 2. Fuel Price Cards (Live Prices)
              _buildFuelPriceCards(numberFormat, isMobile, isDark),
              SizedBox(height: isMobile ? 16 : 22),

              // 3. Quick Operations 2x2 Grid (Thumb-Friendly Actions)
              _buildQuickOperationsGrid(isMobile),
              SizedBox(height: isMobile ? 20 : 26),

              // 4. Tanks Monitoring Section
              _buildTanksSection(currentUser, isMobile, isDark),
              SizedBox(height: isMobile ? 20 : 26),

              // 5. Cash Box & Financial Overview
              _buildCashBoxOverview(numberFormat, isMobile, isDark),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingHeader(dynamic currentUser, bool isMobile, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 18,
        vertical: isMobile ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'مرحباً بك، ${currentUser?.name ?? "المستخدم"}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isMobile ? 17 : 21,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.textLight : AppTheme.primaryNavy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 6, color: AppTheme.successGreen),
                          SizedBox(width: 4),
                          Text(
                            'نشط',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.successGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                ValueListenableBuilder<String>(
                  valueListenable: StationConfig.stationNameNotifier,
                  builder: (context, stationName, _) => Text(
                    stationName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: isDark ? AppTheme.darkCardLighter : Colors.blue.shade50,
              foregroundColor: AppTheme.primaryCyan,
              minimumSize: const Size(44, 44),
            ),
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'تحديث البيانات',
          ),
        ],
      ),
    );
  }

  Widget _buildFuelPriceCards(NumberFormat numberFormat, bool isMobile, bool isDark) {
    return BlocBuilder<FuelPriceBloc, FuelPriceState>(
      builder: (context, priceState) {
        double benzinPrice = 0;
        double dieselPrice = 0;

        if (priceState is FuelPriceLoaded) {
          benzinPrice = priceState.activePrices['بنزين']?.pricePerLiter ?? 0;
          dieselPrice = priceState.activePrices['جازولين']?.pricePerLiter ?? 0;
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 10) / 2;

            return Row(
              children: [
                // Benzine Card
                SizedBox(
                  width: cardWidth,
                  child: _buildSinglePriceCard(
                    title: 'بنزين (سوبر)',
                    price: benzinPrice,
                    numberFormat: numberFormat,
                    color: AppTheme.benzinColor,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                // Diesel Card
                SizedBox(
                  width: cardWidth,
                  child: _buildSinglePriceCard(
                    title: 'جازولين (ديزل)',
                    price: dieselPrice,
                    numberFormat: numberFormat,
                    color: AppTheme.dieselColor,
                    isDark: isDark,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSinglePriceCard({
    required String title,
    required double price,
    required NumberFormat numberFormat,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              Icon(Icons.local_gas_station_rounded, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  numberFormat.format(price),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    color: isDark ? AppTheme.textLight : AppTheme.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'ج.س/L',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.textMuted : AppTheme.textDim,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickOperationsGrid(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bolt_rounded, size: 18, color: AppTheme.primaryCyan),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'العمليات السريعة',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.textLight
                      : AppTheme.primaryNavy,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: itemWidth,
                  child: QuickActionCard(
                    title: 'تسجيل مبيعات',
                    subtitle: 'تفريغ وتوثيق فوري',
                    icon: Icons.point_of_sale_rounded,
                    color: AppTheme.primaryCyan,
                    onTap: () => widget.onNavigate(1),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: QuickActionCard(
                    title: 'قفل الوردية',
                    subtitle: 'تسوية وجرد الخزينة',
                    icon: Icons.lock_clock_rounded,
                    color: AppTheme.successGreen,
                    onTap: () => widget.onNavigate(1),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: QuickActionCard(
                    title: 'استلام شحنة',
                    subtitle: 'تفريغ صهريج وقود',
                    icon: Icons.local_shipping_rounded,
                    color: AppTheme.dieselColor,
                    onTap: () => widget.onNavigate(3),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: QuickActionCard(
                    title: 'جرد الخزانات',
                    subtitle: 'معايرة المسطرة',
                    icon: Icons.layers_rounded,
                    color: Colors.purpleAccent,
                    onTap: () => widget.onNavigate(11),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildTanksSection(dynamic currentUser, bool isMobile, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.storage_rounded, size: 18, color: AppTheme.primaryCyan),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'مناسيب الخزانات الأرضية',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.textLight : AppTheme.primaryNavy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (currentUser?.can(AppPermission.manageTanks) ?? false)
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () => widget.onNavigate(11),
                child: const Text('إدارة السعات', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        BlocBuilder<TankBloc, TankState>(
          builder: (context, tankState) {
            if (tankState is TankLoading) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (tankState is TankLoaded) {
              if (tankState.tanks.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text('لم يتم تهيئة خزانات الوقود بعد.'),
                  ),
                );
              }
              return Column(
                children: tankState.tanks
                    .map((tank) => Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: TankLevelCard(tank: tank),
                        ))
                    .toList(),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildCashBoxOverview(NumberFormat numberFormat, bool isMobile, bool isDark) {
    return BlocBuilder<CashBoxBloc, CashBoxState>(
      builder: (context, cashState) {
        final todayBox = cashState is CashBoxLoaded ? cashState.todayBox : null;
        final opening = todayBox?.openingBalance ?? 0.0;
        final cashIn = todayBox?.cashIn ?? 0.0;
        final cashOut = todayBox?.cashOut ?? 0.0;
        final closing = todayBox?.closingBalance ?? 0.0;

        return BlocBuilder<CustomerBloc, CustomerState>(
          builder: (context, custState) {
            double totalDebts = 0.0;
            if (custState is CustomerLoaded) {
              for (final c in custState.customers) {
                totalDebts += c.currentBalance;
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded, size: 18, color: AppTheme.primaryCyan),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'الخزينة والسيولة النقدية',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.textLight : AppTheme.primaryNavy,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = constraints.maxWidth < 600
                        ? (constraints.maxWidth - 10) / 2
                        : (constraints.maxWidth - 30) / 4;

                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          child: StatCard(
                            title: 'رصيد الخزنة',
                            value: '${numberFormat.format(closing)} ج.س',
                            icon: Icons.account_balance_wallet_rounded,
                            color: AppTheme.primaryBlue,
                            subtitle: 'افتتاحي: ${numberFormat.format(opening)}',
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: StatCard(
                            title: 'إجمالي الوارد',
                            value: '${numberFormat.format(cashIn)} ج.س',
                            icon: Icons.arrow_downward_rounded,
                            color: AppTheme.successGreen,
                            subtitle: 'نقدي + تحصيلات',
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: StatCard(
                            title: 'إجمالي المنصرف',
                            value: '${numberFormat.format(cashOut)} ج.س',
                            icon: Icons.arrow_upward_rounded,
                            color: AppTheme.dangerRed,
                            subtitle: 'مصروفات تشغيلية',
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: StatCard(
                            title: 'مديونيات الآجل',
                            value: '${numberFormat.format(totalDebts)} ج.س',
                            icon: Icons.people_outline_rounded,
                            color: AppTheme.warningOrange,
                            subtitle: 'مستحقات العملاء',
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
