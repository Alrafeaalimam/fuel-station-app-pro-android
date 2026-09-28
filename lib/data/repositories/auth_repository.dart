import 'package:flutter/foundation.dart';
import '../database_helper.dart';
import '../../models/models.dart';
import '../../utils/security_util.dart';
import '../../utils/permission_guard.dart';

class AuthLockoutException implements Exception {
  final String message;
  final Duration remainingLockout;
  const AuthLockoutException(this.message, this.remainingLockout);

  @override
  String toString() => message;
}

class _LoginAttemptRecord {
  int failedCount;
  DateTime? lockedUntil;

  _LoginAttemptRecord({this.failedCount = 0, this.lockedUntil});
}

class AuthRepository {
  final DatabaseHelper dbHelper;

  static final Map<String, _LoginAttemptRecord> _attempts = {};
  static const int maxFailedAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 5);

  AuthRepository({DatabaseHelper? dbHelper})
      : dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Check if account is currently locked out
  bool isAccountLocked(String username) {
    final key = username.trim().toLowerCase();
    final record = _attempts[key];
    if (record == null || record.lockedUntil == null) return false;
    if (DateTime.now().isAfter(record.lockedUntil!)) {
      _attempts.remove(key);
      return false;
    }
    return true;
  }

  /// Get remaining lockout duration
  Duration getRemainingLockout(String username) {
    final key = username.trim().toLowerCase();
    final record = _attempts[key];
    if (record == null || record.lockedUntil == null) return Duration.zero;
    final now = DateTime.now();
    if (now.isAfter(record.lockedUntil!)) return Duration.zero;
    return record.lockedUntil!.difference(now);
  }

  /// Get remaining allowed attempts before lockout
  int getRemainingAttempts(String username) {
    final key = username.trim().toLowerCase();
    final record = _attempts[key];
    final failed = record?.failedCount ?? 0;
    return (maxFailedAttempts - failed).clamp(0, maxFailedAttempts);
  }

  static String _formatRemainingTime(Duration remaining) {
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    if (minutes > 0 && seconds > 0) {
      return '$minutes دقيقة و $seconds ثانية';
    } else if (minutes > 0) {
      return '$minutes دقيقة';
    } else {
      return '$seconds ثانية';
    }
  }

  @visibleForTesting
  static void resetLockoutForTesting([String? username]) {
    if (username != null) {
      _attempts.remove(username.trim().toLowerCase());
    } else {
      _attempts.clear();
    }
  }

  Future<UserModel?> login(String username, String password) async {
    final cleanUsername = username.trim();
    final key = cleanUsername.toLowerCase();

    // 1. فحص ما إذا كان الحساب مقفولاً مؤقتاً
    if (isAccountLocked(cleanUsername)) {
      final remaining = getRemainingLockout(cleanUsername);
      final remainingText = _formatRemainingTime(remaining);
      throw AuthLockoutException(
        'تم قفل الحساب مؤقتاً لتكرار محاولات الدخول الخاطئة (5 محاولات). يرجى المحاولة بعد $remainingText.',
        remaining,
      );
    }

    final db = await dbHelper.database;
    final hashedPassword = SecurityUtil.hashPassword(password);

    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'username = ? AND password_hash = ?',
      whereArgs: [cleanUsername, hashedPassword],
    );

    if (maps.isNotEmpty) {
      // نجاح الدخول: تصفير عداد المحاولات الفاشلة فوراً
      _attempts.remove(key);
      return UserModel.fromMap(maps.first);
    }

    // فشل الدخول: زيادة عداد المحاولات الفاشلة
    final record = _attempts.putIfAbsent(key, () => _LoginAttemptRecord());
    record.failedCount++;

    if (record.failedCount >= maxFailedAttempts) {
      record.lockedUntil = DateTime.now().add(lockoutDuration);
      final remainingText = _formatRemainingTime(lockoutDuration);
      throw AuthLockoutException(
        'تم قفل الحساب مؤقتاً لتكرار محاولات الدخول الخاطئة (5 محاولات). يرجى المحاولة بعد $remainingText.',
        lockoutDuration,
      );
    }

    return null;
  }

  Future<List<UserModel>> getUsers() async {
    final db = await dbHelper.database;
    final maps = await db.query('users', orderBy: 'id ASC');
    return maps.map((e) => UserModel.fromMap(e)).toList();
  }

  Future<int> addUser(UserModel user) async {
    final db = await dbHelper.database;
    final secureUser = user.copyWith(
      passwordHash: SecurityUtil.hashPassword(user.passwordHash),
    );
    return await db.insert('users', secureUser.toMap());
  }

  /// Change user's own password with current password verification
  Future<void> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final db = await dbHelper.database;
    final userMaps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    );

    if (userMaps.isEmpty) {
      throw Exception('المستخدم غير موجود.');
    }

    final storedHash = userMaps.first['password_hash'] as String;
    if (!SecurityUtil.verifyPassword(currentPassword, storedHash)) {
      throw Exception('كلمة المرور الحالية غير صحيحة.');
    }

    if (newPassword.trim().isEmpty) {
      throw Exception('كلمة المرور الجديدة لا يمكن أن تكون فارغة.');
    }

    if (newPassword.trim().length < 4) {
      throw Exception('كلمة المرور الجديدة يجب ألا تقل عن 4 أحرف.');
    }

    final newHash = SecurityUtil.hashPassword(newPassword);
    await db.update(
      'users',
      {'password_hash': newHash},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Manager reset password for any user directly without knowing old password
  Future<void> resetUserPasswordByManager({
    required int targetUserId,
    required String newPassword,
    required UserModel? managerUser,
  }) async {
    PermissionGuard.check(managerUser, AppPermission.manageUsers);
    final db = await dbHelper.database;
    final userMaps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [targetUserId],
    );

    if (userMaps.isEmpty) {
      throw Exception('المستخدم المراد تعديل حسابه غير موجود.');
    }

    if (newPassword.trim().isEmpty) {
      throw Exception('كلمة المرور الجديدة لا يمكن أن تكون فارغة.');
    }

    if (newPassword.trim().length < 4) {
      throw Exception('كلمة المرور الجديدة يجب ألا تقل عن 4 أحرف.');
    }

    final newHash = SecurityUtil.hashPassword(newPassword);
    await db.update(
      'users',
      {'password_hash': newHash},
      where: 'id = ?',
      whereArgs: [targetUserId],
    );
  }
}
