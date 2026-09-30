import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_state.dart';
import '../../data/repositories/backup_repository.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/permission_guard.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _isLoading = true;
  String? _dbPath;
  int _dbSize = 0;
  DateTime? _lastManualBackupDate;
  bool _showWeeklyReminder = false;
  List<File> _autoBackups = [];

  bool _isDismissedThisSession = false;

  @override
  void initState() {
    super.initState();
    _loadBackupInfo();
  }

  Future<void> _loadBackupInfo() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<BackupRepository>();
      final path = await repo.getDatabasePath();
      final size = await repo.getDatabaseSize();
      final lastDate = await repo.getLastManualBackupDate();
      final reminderNeeded = await repo.isManualBackupReminderNeeded();
      final autoFiles = await repo.getAutoBackups();

      if (mounted) {
        setState(() {
          _dbPath = path;
          _dbSize = size;
          _lastManualBackupDate = lastDate;
          _showWeeklyReminder = reminderNeeded && !_isDismissedThisSession;
          _autoBackups = autoFiles;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _handleShareBackup(UserModel user) async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd_HH-mm').format(now);
    final defaultFileName = 'fuel_station_backup_$dateStr.db';

    setState(() => _isLoading = true);
    try {
      final repo = context.read<BackupRepository>();
      final bytes = await repo.getDatabaseBytes(user: user);

      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path, defaultFileName));
      await tempFile.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(tempFile.path, mimeType: 'application/x-sqlite3', name: defaultFileName)],
        subject: 'نسخة احتياطية - محطة الوقود $dateStr',
        text: 'نسخة احتياطية كاملة لقاعدة بيانات نظام محطة الوقود بتاريخ $dateStr',
      );

      await repo.setLastManualBackupDate(DateTime.now());
      if (mounted) {
        await _loadBackupInfo();
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('فشل مشاركة النسخة الاحتياطية: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleManualBackup(UserModel user) async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd_HH-mm').format(now);
    final defaultFileName = 'fuel_station_backup_$dateStr.db';

    try {
      final repo = context.read<BackupRepository>();
      final bytes = await repo.getDatabaseBytes(user: user);

      final targetPath = await FilePicker.saveFile(
        dialogTitle: 'اختر موقع حفظ النسخة الاحتياطية',
        fileName: defaultFileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      if (targetPath == null) return;
      await repo.setLastManualBackupDate(DateTime.now());

      if (mounted) {
        await _loadBackupInfo();
        _showSuccessDialog(
          title: 'تم إنشاء النسخة الاحتياطية بنجاح',
          message: 'تم حفظ نسخة كاملة من قاعدة البيانات في المسار التالي:\n\n$targetPath',
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('فشل إنشاء النسخة الاحتياطية: $e');
      }
    }
  }

  Future<void> _handleRestoreBackup(UserModel user, {String? directFilePath}) async {
    String? filePathToRestore = directFilePath;

    if (filePathToRestore == null) {
      final picked = await FilePicker.pickFiles(
        dialogTitle: 'اختر ملف النسخة الاحتياطية (.db)',
        type: FileType.any,
      );

      if (picked == null || picked.isEmpty || picked.first.path == null) return;
      filePathToRestore = picked.first.path;
    }

    if (filePathToRestore == null || !mounted) return;
    final confirmedPath = filePathToRestore;

    // Show Critical Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: AppTheme.dangerRed, size: 28),
            SizedBox(width: 8),
            Text('تحذير استعادة البيانات', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'سيتم استبدال كل البيانات الحالية بالكامل بالنسخة المختارة. هذا الإجراء لا يمكن التراجع عنه.\n\nهل أنت متأكد تماماً من المتابعة؟',
              style: TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                'الملف المختار: ${p.basename(confirmedPath)}',
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.restore_rounded, size: 18),
            label: const Text('تأكيد الاستبدال والاستعادة'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final repo = context.read<BackupRepository>();
      await repo.restoreBackup(confirmedPath, user: user);

      if (mounted) {
        await _loadBackupInfo();
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppTheme.successGreen, size: 26),
                SizedBox(width: 8),
                Text('اكتملت الاستعادة بنجاح'),
              ],
            ),
            content: const Text(
              'تمت استعادة قاعدة البيانات وتحديث النظام بالكامل.\nيُوصى بإعادة تشغيل التطبيق أو تسجيل الخروج وإعادة الدخول لضمان تحديث كافة الجداول النشطة في الذاكرة.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorDialog('فشل استعادة النسخة الاحتياطية: $e');
      }
    }
  }

  void _showSuccessDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.successGreen, size: 24),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 13, height: 1.4)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppTheme.dangerRed, size: 24),
            SizedBox(width: 8),
            Text('خطأ', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, style: const TextStyle(color: AppTheme.dangerRed, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final currentUser = authState is AuthAuthenticated ? authState.user : null;

    if (currentUser == null || !currentUser.can(AppPermission.manageBackup)) {
      return const Center(
        child: Text(
          'غير مصرح لك بالاطلاع على شاشة النسخ الاحتياطي.\nهذه الصلاحية خاصة بمدير المحطة فقط.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: AppTheme.dangerRed, fontWeight: FontWeight.bold),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'النسخ الاحتياطي واستعادة البيانات',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFFFFF), // High-contrast crisp white (#FFFFFF)
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'حماية بيانات المحطة عبر النسخ اليدوي الخارجي والنسخ التلقائي اليومي',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF94A3B8), // Cool gray (#94A3B8)
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _loadBackupInfo,
                  tooltip: 'تحديث البيانات',
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: [
                        // Weekly Reminder Banner
                        if (_showWeeklyReminder) ...[
                          _buildWeeklyReminderBanner(currentUser),
                          const SizedBox(height: 16),
                        ],

                        // Main Actions & DB Status
                        _buildStatusAndActionsCard(currentUser),
                        const SizedBox(height: 20),

                        // Automatic Backups Section
                        _buildAutoBackupsSection(currentUser),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyReminderBanner(UserModel user) {
    final descriptionText = _lastManualBackupDate == null
        ? 'لم يتم عمل أي نسخة احتياطية يدوية حتى الآن. يُرجى حفظ نسخة على فلاشة USB أو سحابة.'
        : 'آخر نسخة يدوية مسجلة كانت بتاريخ: ${DateFormat('yyyy-MM-dd HH:mm').format(_lastManualBackupDate!)} (منذ أكثر من 7 أيام).';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // Amber-50
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCD34D), width: 1.5), // Amber-300
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 650;

          final iconWidget = Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7), // Amber-100
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFF92400E), // Amber-800
              size: 28,
            ),
          );

          final textContent = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'تذكير أسبوعي هام: يُوصى بعمل نسخة احتياطية يدوية جديدة',
                textAlign: TextAlign.right,
                softWrap: true,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF78350F), // Amber-900 (WCAG AAA)
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                descriptionText,
                textAlign: TextAlign.right,
                softWrap: true,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF92400E), // Amber-800 (WCAG AAA)
                  height: 1.4,
                ),
              ),
            ],
          );

          final actionButtons = Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB45309), // Amber-700
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _handleManualBackup(user),
                icon: const Icon(Icons.backup_rounded, size: 16),
                label: const Text(
                  'نسخ الآن',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF78350F),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onPressed: () => setState(() {
                  _showWeeklyReminder = false;
                  _isDismissedThisSession = true;
                }),
                child: const Text(
                  'تجاهل مؤقتاً',
                  style: TextStyle(
                    color: Color(0xFF78350F),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          );

          if (isNarrow) {
            // Mobile standard layout: [Icon on Right] [Title & Description in Center (flex: 1)]
            // Actions / Buttons placed cleanly at bottom
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    iconWidget,
                    const SizedBox(width: 14),
                    Expanded(
                      child: textContent,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                actionButtons,
              ],
            );
          }

          // Desktop/Tablet standard horizontal layout:
          // [Icon on Right] [Title & Description in Center] [Actions/Buttons at Left]
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              iconWidget,
              const SizedBox(width: 16),
              Expanded(
                child: textContent,
              ),
              const SizedBox(width: 16),
              actionButtons,
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusAndActionsCard(UserModel user) {
    final dateFormat = DateFormat('yyyy-MM-dd hh:mm a');

    return Card(
      elevation: 0,
      color: AppTheme.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.darkBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.storage_rounded, color: AppTheme.primaryCyan, size: 22),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'حالة قاعدة البيانات الحالية',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: AppTheme.darkBorder),
            LayoutBuilder(
              builder: (context, cardConstraints) {
                final isCardNarrow = cardConstraints.maxWidth < 500;
                if (isCardNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('مسار قاعدة البيانات النشطة:', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      const SizedBox(height: 4),
                      SelectableText(
                        _dbPath ?? 'جاري التحميل...',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.darkCardLighter,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.darkBorderLight),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('حجم البيانات: ', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                            const SizedBox(width: 4),
                            Text(
                              _formatFileSize(_dbSize),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.accentCyan),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('مسار قاعدة البيانات النشطة:', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                          const SizedBox(height: 4),
                          SelectableText(
                            _dbPath ?? 'جاري التحميل...',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.darkCardLighter,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.darkBorderLight),
                      ),
                      child: Column(
                        children: [
                          const Text('حجم البيانات', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                          const SizedBox(height: 2),
                          Text(
                            _formatFileSize(_dbSize),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.accentCyan),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                Icon(
                  _lastManualBackupDate != null ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  size: 18,
                  color: _lastManualBackupDate != null ? AppTheme.successGreen : Colors.orange,
                ),
                const Text(
                  'آخر نسخة احتياطية يدوية: ',
                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
                Text(
                  _lastManualBackupDate != null
                      ? dateFormat.format(_lastManualBackupDate!)
                      : 'لا توجد نسخة يدوية سابقة مسجلة',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Action Buttons
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 650;
                final shareBtn = ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _handleShareBackup(user),
                  icon: const Icon(Icons.share_rounded, size: 20),
                  label: const Text(
                    'مشاركة النسخة الاحتياطية (Share Sheet)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                );

                final saveBtn = ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _handleManualBackup(user),
                  icon: const Icon(Icons.save_alt_rounded, size: 20),
                  label: const Text(
                    'إنشاء وحفظ في مجلد (حفظ باسم)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                );

                final restoreBtn = OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.dangerRed,
                    side: const BorderSide(color: AppTheme.dangerRed),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _handleRestoreBackup(user),
                  icon: const Icon(Icons.settings_backup_restore_rounded, size: 20),
                  label: const Text(
                    'استعادة نسخة احتياطية من ملف (.db)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      shareBtn,
                      const SizedBox(height: 10),
                      saveBtn,
                      const SizedBox(height: 10),
                      restoreBtn,
                    ],
                  );
                }

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: shareBtn),
                        const SizedBox(width: 12),
                        Expanded(child: saveBtn),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: restoreBtn),
                      ],
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

  Widget _buildAutoBackupsSection(UserModel user) {
    return Card(
      elevation: 0,
      color: AppTheme.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.darkBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, headerConstraints) {
                final isAutoHeaderNarrow = headerConstraints.maxWidth < 450;
                final badge = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'العدد: ${_autoBackups.length} / 14 كحد أقصى',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryCyan),
                  ),
                );

                if (isAutoHeaderNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.auto_mode_rounded, color: AppTheme.primaryCyan, size: 22),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'النسخ الاحتياطي التلقائي (عند قفل الورديات)',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      badge,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_mode_rounded, color: AppTheme.primaryCyan, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'النسخ الاحتياطي التلقائي (عند قفل الورديات)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    badge,
                  ],
                );
              },
            ),
            const SizedBox(height: 12),

            // Critical Hardware Disclaimer Note (Requirement 4)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'تنبيه أمني وإرشادي:\nهذه النسخ التلقائية تُنشأ في مجلد محلي على نفس القرص الصلب الخاص بهذا الجهاز عند إغلاق كل وردية (مع الاحتفاظ بآخر 14 نسخة فقط دورياً). لا تغني هذه النسخ إطلاقاً عن عمل "نسخة احتياطية يدوية" بانتظام وحفظها على وسيط تخزين منفصل (فلاشة USB أو سحابة إلكترونية)، تحسباً لعطل الجهاز أو تلف القرص الصلب.',
                      style: TextStyle(fontSize: 12, height: 1.5, color: Colors.red.shade900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_autoBackups.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'لم يتم إنشاء نسخ تلقائية بعد.\nستظهر أول نسخة تلقائية تلقائياً فور قفل أول وردية بنجاح.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _autoBackups.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: AppTheme.darkBorder),
                itemBuilder: (context, index) {
                  final file = _autoBackups[index];
                  final filename = p.basename(file.path);
                  final stat = file.statSync();

                  return LayoutBuilder(
                    builder: (context, itemConstraints) {
                      final isItemNarrow = itemConstraints.maxWidth < 480;
                      final restoreBtn = ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
                          foregroundColor: AppTheme.primaryCyan,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.restore_rounded, size: 16),
                        label: const Text('استعادة هذه النسخة', style: TextStyle(fontSize: 12)),
                        onPressed: () => _handleRestoreBackup(user, directFilePath: file.path),
                      );

                      if (isItemNarrow) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(
                                    backgroundColor: AppTheme.primaryBlue,
                                    radius: 16,
                                    child: Icon(Icons.backup_table_rounded, color: Colors.white, size: 16),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(filename, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                                        const SizedBox(height: 2),
                                        Text(
                                          'التاريخ: ${DateFormat('yyyy-MM-dd HH:mm').format(stat.modified)} | الحجم: ${_formatFileSize(stat.size)}',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: restoreBtn,
                              ),
                            ],
                          ),
                        );
                      }

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        leading: const CircleAvatar(
                          backgroundColor: AppTheme.primaryBlue,
                          radius: 18,
                          child: Icon(Icons.backup_table_rounded, color: Colors.white, size: 18),
                        ),
                        title: Text(filename, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                        subtitle: Text(
                          'التاريخ: ${DateFormat('yyyy-MM-dd HH:mm').format(stat.modified)} | الحجم: ${_formatFileSize(stat.size)}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                        trailing: restoreBtn,
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
