import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../bloc/reports/reports_bloc.dart';
import '../../bloc/reports/reports_event.dart';
import '../../bloc/reports/reports_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ReportsBloc>().add(const LoadFinancialSummaryReport());
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0', 'en_US');
    final numberFormat = NumberFormat('#,##0.0', 'en_US');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'التقارير المالية وحركة الوقود والربحية',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: IconButton(
              onPressed: () {
                context.read<ReportsBloc>().add(const LoadFinancialSummaryReport());
              },
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث التقرير',
            ),
          ),
        ],
      ),
      body: BlocBuilder<ReportsBloc, ReportsState>(
        builder: (context, state) {
          if (state is ReportsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ReportsSummaryLoaded) {
            final sum = state.summary;

            return SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 14.0 : 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Overview Section
                  Row(
                    children: [
                      const Icon(Icons.analytics_rounded, color: AppTheme.primaryCyan, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'المؤشرات المالية الشاملة للمحطة',
                        style: TextStyle(
                          fontSize: isMobile ? 15 : 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.textLight : AppTheme.primaryNavy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Responsive Financial Stats Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth = constraints.maxWidth < 600
                          ? (constraints.maxWidth - 10) / 2
                          : (constraints.maxWidth - 36) / 4;

                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: itemWidth,
                            child: StatCard(
                              title: 'إجمالي المبيعات الكلية',
                              value: '${currencyFormat.format(sum.totalSalesAmount)} ج.س',
                              icon: Icons.monetization_on_rounded,
                              color: AppTheme.primaryNavy,
                              subtitle: 'جميع طرق الدفع',
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: StatCard(
                              title: 'مبيعات نقدي (كاش)',
                              value: '${currencyFormat.format(sum.totalSalesCash)} ج.س',
                              icon: Icons.money_rounded,
                              color: AppTheme.successGreen,
                              subtitle: 'توريد مباشر للخزنة',
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: StatCard(
                              title: 'تحويل بنكي (بنكك)',
                              value: '${currencyFormat.format(sum.totalSalesBank)} ج.س',
                              icon: Icons.account_balance_rounded,
                              color: AppTheme.primaryBlue,
                              subtitle: 'حساب البنك',
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: StatCard(
                              title: 'مبيعات آجل (عملاء)',
                              value: '${currencyFormat.format(sum.totalSalesCredit)} ج.س',
                              icon: Icons.credit_card_rounded,
                              color: AppTheme.warningOrange,
                              subtitle: 'مستحقات على الذمم',
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Fuel Volumes & Operations
                  Row(
                    children: [
                      const Icon(Icons.local_gas_station_rounded, color: AppTheme.primaryCyan, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'حجم المبيعات باللترات ومصروفات التشغيل',
                        style: TextStyle(
                          fontSize: isMobile ? 15 : 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.textLight : AppTheme.primaryNavy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Responsive Fuel Volume Stats Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth = constraints.maxWidth < 600
                          ? (constraints.maxWidth - 10) / 2
                          : (constraints.maxWidth - 36) / 4;

                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: itemWidth,
                            child: StatCard(
                              title: 'مبيعات البنزين',
                              value: '${numberFormat.format(sum.totalBenzinLiters)} L',
                              icon: Icons.local_gas_station,
                              color: AppTheme.benzinColor,
                              subtitle: 'عبر 4 فوهات بنزين',
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: StatCard(
                              title: 'مبيعات الجازولين',
                              value: '${numberFormat.format(sum.totalDieselLiters)} L',
                              icon: Icons.local_gas_station,
                              color: AppTheme.dieselColor,
                              subtitle: 'عبر 4 فوهات جازولين',
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: StatCard(
                              title: 'المصروفات التشغيلية',
                              value: '${currencyFormat.format(sum.totalExpenses)} ج.س',
                              icon: Icons.receipt_long,
                              color: AppTheme.dangerRed,
                              subtitle: 'كهرباء، صيانة، رواتب',
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: StatCard(
                              title: 'صافي التدفق النقدي',
                              value: '${currencyFormat.format(sum.netCashFlow)} ج.س',
                              icon: Icons.savings_rounded,
                              color: AppTheme.accentCyan,
                              subtitle: 'نقد + تحصيلات - مصاريف',
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Consolidated Summary Card
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.primaryCyan, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'بيان الحساب الختامي التراكمي',
                                style: TextStyle(
                                  fontSize: isMobile ? 14 : 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppTheme.textLight : AppTheme.textDark,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          _buildReportRow(
                            'إجمالي الإيرادات المحققة من الوقود',
                            '${currencyFormat.format(sum.totalSalesAmount)} ج.س',
                            isBold: true,
                            isDark: isDark,
                          ),
                          _buildReportRow(
                            'المتحصلات النقدية المحصلة فعلياً بالخزنة',
                            '${currencyFormat.format(sum.totalSalesCash)} ج.س',
                            isDark: isDark,
                          ),
                          _buildReportRow(
                            'التحويلات البنكية المباشرة (تطبيق بنكك)',
                            '${currencyFormat.format(sum.totalSalesBank)} ج.س',
                            isDark: isDark,
                          ),
                          _buildReportRow(
                            'تحصيلات سداد ديون سابقة من عملاء الآجل',
                            '+${currencyFormat.format(sum.totalCreditCollected)} ج.س',
                            color: AppTheme.successGreen,
                            isDark: isDark,
                          ),
                          _buildReportRow(
                            'إجمالي المصروفات المنصرفة من الخزنة',
                            '-${currencyFormat.format(sum.totalExpenses)} ج.س',
                            color: AppTheme.dangerRed,
                            isDark: isDark,
                          ),
                          const Divider(height: 24),
                          _buildReportRow(
                            'صافي رصيد السيولة النقدية المستلمة',
                            '${currencyFormat.format(sum.netCashFlow)} ج.س',
                            isBold: true,
                            color: isDark ? AppTheme.primaryCyan : AppTheme.primaryBlue,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          if (state is ReportsError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppTheme.dangerRed, size: 56),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppTheme.dangerRed,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        context.read<ReportsBloc>().add(const LoadFinancialSummaryReport());
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildReportRow(
    String title,
    String value, {
    bool isBold = false,
    Color? color,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isDark ? (isBold ? AppTheme.textLight : AppTheme.textMuted) : Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 14.5 : 13,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
              color: color ?? (isDark ? AppTheme.textLight : Colors.black87),
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
