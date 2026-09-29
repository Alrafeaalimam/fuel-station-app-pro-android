import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/cash_box/cash_box_bloc.dart';
import '../../bloc/cash_box/cash_box_event.dart';
import '../../bloc/cash_box/cash_box_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/permission_guard.dart';
import '../../widgets/stat_card.dart';

class CashBoxScreen extends StatefulWidget {
  const CashBoxScreen({super.key});

  @override
  State<CashBoxScreen> createState() => _CashBoxScreenState();
}

class _CashBoxScreenState extends State<CashBoxScreen> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String _txnType = 'in'; // 'in' or 'out'

  @override
  void initState() {
    super.initState();
    context.read<CashBoxBloc>().add(LoadCashBox());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _showManualTxnDialog(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final currentUser = authState is AuthAuthenticated ? authState.user : null;
    if (!(currentUser?.can(AppPermission.adjustCashBoxManually) ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('غير مصرح لك بتعديل رصيد الخزنة يدوياً. هذه الصلاحية حصرية لمدير المحطة فقط.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    _amountController.clear();
    _notesController.clear();
    _txnType = 'in';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('تسجيل إيداع / سحب يدوي من الخزنة'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _txnType,
                      decoration: const InputDecoration(labelText: 'نوع العملية'),
                      items: const [
                        DropdownMenuItem(value: 'in', child: Text('إيداع نقدية إضافي (وارد)')),
                        DropdownMenuItem(value: 'out', child: Text('سحب نقدية يدوي (منصرف)')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() {
                            _txnType = v;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'المبلغ (ج.س)',
                        suffixText: 'ج.س',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'البيان / سبب العملية',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final amt = double.tryParse(_amountController.text);
                    if (amt != null && amt > 0) {
                      this.context.read<CashBoxBloc>().add(
                            UpdateCashBoxManualRequested(
                              cashInDelta: _txnType == 'in' ? amt : 0.0,
                              cashOutDelta: _txnType == 'out' ? amt : 0.0,
                              notes: _notesController.text.trim().isNotEmpty
                                  ? _notesController.text.trim()
                                  : null,
                              user: currentUser,
                            ),
                          );
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('تنفيذ العملية'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0', 'en_US');
    final authState = context.watch<AuthBloc>().state;
    final currentUser = authState is AuthAuthenticated ? authState.user : null;
    final canAdjustManually = currentUser?.can(AppPermission.adjustCashBoxManually) ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isMobile ? 'الخزنة النقدية والترحيل' : 'إدارة الخزنة النقدية اليومية والترحيل التلقائي',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (canAdjustManually)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: isMobile
                  ? IconButton(
                      icon: const Icon(Icons.swap_horiz_rounded),
                      tooltip: 'إيداع / سحب يدوي',
                      onPressed: () => _showManualTxnDialog(context),
                    )
                  : ElevatedButton.icon(
                      onPressed: () => _showManualTxnDialog(context),
                      icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
                      label: const Text('إيداع / سحب يدوي'),
                    ),
            ),
        ],
      ),
      body: BlocConsumer<CashBoxBloc, CashBoxState>(
        listener: (context, state) {
          if (state is CashBoxActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.successGreen,
              ),
            );
          } else if (state is CashBoxError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.dangerRed,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is CashBoxLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is CashBoxLoaded) {
            final today = state.todayBox;

            return SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info banner about automatic opening balance
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.successGreen.withValues(alpha: 0.15) : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? AppTheme.successGreen.withValues(alpha: 0.3) : Colors.green.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppTheme.successGreen),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'تاريخ اليوم: ${today.date}. الرصيد الافتتاحي (${currencyFormat.format(today.openingBalance)} ج.س) تم ترحيله تلقائياً من إغلاق اليوم السابق.',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppTheme.textLight : AppTheme.primaryNavy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Responsive Stat Cards
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth = constraints.maxWidth < 600
                          ? (constraints.maxWidth - 12) / 2
                          : (constraints.maxWidth - 36) / 4;

                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: itemWidth,
                            child: StatCard(
                              title: 'الرصيد الافتتاحي (بداية اليوم)',
                              value: '${currencyFormat.format(today.openingBalance)} ج.س',
                              icon: Icons.account_balance_wallet_outlined,
                              color: Colors.indigo,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: StatCard(
                              title: 'إجمالي الوارد (مبيعات + تحصيل)',
                              value: '${currencyFormat.format(today.cashIn)} ج.س',
                              icon: Icons.arrow_downward,
                              color: AppTheme.successGreen,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: StatCard(
                              title: 'إجمالي المنصرف (مصروفات وسحب)',
                              value: '${currencyFormat.format(today.cashOut)} ج.س',
                              icon: Icons.arrow_upward,
                              color: AppTheme.dangerRed,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: StatCard(
                              title: 'الرصيد الختامي الحالي في الخزنة',
                              value: '${currencyFormat.format(today.closingBalance)} ج.س',
                              icon: Icons.account_balance,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // History Table
                  const Text(
                    'سجل حركة الخزنة اليومية السابقة',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('التاريخ')),
                              DataColumn(label: Text('الرصيد الافتتاحي')),
                              DataColumn(label: Text('الوارد')),
                              DataColumn(label: Text('المنصرف')),
                              DataColumn(label: Text('الرصيد الختامي')),
                              DataColumn(label: Text('البيان / ملاحظات')),
                            ],
                            rows: state.history.map((box) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(box.date, style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(Text('${currencyFormat.format(box.openingBalance)} ج.س')),
                                  DataCell(Text(
                                    '+${currencyFormat.format(box.cashIn)} ج.س',
                                    style: const TextStyle(color: AppTheme.successGreen, fontWeight: FontWeight.bold),
                                  )),
                                  DataCell(Text(
                                    '-${currencyFormat.format(box.cashOut)} ج.س',
                                    style: const TextStyle(color: AppTheme.dangerRed, fontWeight: FontWeight.bold),
                                  )),
                                  DataCell(Text(
                                    '${currencyFormat.format(box.closingBalance)} ج.س',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                                  )),
                                  DataCell(Text(box.notes ?? '-')),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
