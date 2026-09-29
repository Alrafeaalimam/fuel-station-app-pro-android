import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class TankLevelCard extends StatelessWidget {
  final TankModel tank;
  final VoidCallback? onMeasureTap;

  const TankLevelCard({
    super.key,
    required this.tank,
    this.onMeasureTap,
  });

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat('#,##0', 'en_US');
    final isBenzin = tank.fuelType == 'بنزين';
    final fuelColor = isBenzin ? AppTheme.benzinColor : AppTheme.dieselColor;
    final hasCapacity = tank.hasCapacity;
    final percentage = tank.fillPercentage;
    final isOverfilled = hasCapacity && tank.currentDipLiters > tank.capacityLiters;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Icon, Tank Name, Status Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: fuelColor.withValues(alpha: isDark ? 0.18 : 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: fuelColor.withValues(alpha: isDark ? 0.35 : 0.2),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.local_gas_station_rounded,
                          color: fuelColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tank.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isDark ? AppTheme.textLight : AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'نوع الوقود: ${tank.fuelType}',
                              style: TextStyle(
                                color: isDark ? AppTheme.textMuted : AppTheme.textDim,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (!hasCapacity)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.5)),
                    ),
                    child: const Text(
                      'لم تُحدَّد السعة بعد',
                      style: TextStyle(
                        color: AppTheme.dieselColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  )
                else if (isOverfilled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.dangerRed.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      '${percentage.toStringAsFixed(1)}% (تجاوز السعة!)',
                      style: const TextStyle(
                        color: AppTheme.dangerRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: fuelColor.withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: fuelColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: fuelColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Progress Bar representing tank level
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 10,
                child: LinearProgressIndicator(
                  value: hasCapacity ? (percentage / 100).clamp(0.0, 1.0) : 0.0,
                  backgroundColor: isDark ? AppTheme.darkCardLighter : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOverfilled ? AppTheme.dangerRed : fuelColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Responsive Metrics Grid (Zero overflow at 360px)
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 360;
                final primaryText = isDark ? AppTheme.textLight : AppTheme.textDark;
                final labelText = isDark ? AppTheme.textMuted : AppTheme.textDim;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isNarrow ? 'المخزون' : 'المخزون الحالي',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: labelText),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${numberFormat.format(tank.currentDipLiters)} L',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: primaryText,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            isNarrow ? 'السعة' : 'السعة الكلية',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: labelText),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            hasCapacity ? '${numberFormat.format(tank.capacityLiters)} L' : 'غير محدد',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: hasCapacity ? primaryText : AppTheme.dieselColor,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            isNarrow ? 'المتبقي' : 'المتبقي للامتلاء',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: labelText),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            hasCapacity
                                ? '${numberFormat.format((tank.capacityLiters - tank.currentDipLiters).clamp(0, double.infinity))} L'
                                : 'غير محدد',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppTheme.primaryCyan : AppTheme.primaryBlue,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
