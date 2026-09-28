import 'dart:convert';
import 'package:crypto/crypto.dart';

class SecurityUtil {
  /// Hashes a plain text password using SHA-256
  static String hashPassword(String password) {
    final bytes = utf8.encode(password.trim());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verifies if a plain text password matches a stored hash
  static bool verifyPassword(String password, String storedHash) {
    return hashPassword(password) == storedHash.trim();
  }

  /// Computes HMAC-SHA256 for a given payload and key
  static String computeHmac(String payload, String secretKey) {
    final keyBytes = utf8.encode(secretKey);
    final payloadBytes = utf8.encode(payload);
    final hmac = Hmac(sha256, keyBytes);
    return hmac.convert(payloadBytes).toString();
  }

  /// Verifies an HMAC-SHA256 signature
  static bool verifyHmac(String payload, String secretKey, String signature) {
    return computeHmac(payload, secretKey) == signature.trim();
  }

  /// Derives a consistent, strong 256-bit encryption key from a hardware fingerprint
  static String deriveDatabaseKey(String deviceFingerprint) {
    final payload = 'DB_CIPHER_V1:$deviceFingerprint:STR-SEC-2026-X9K7-W4B8-9841F3E8';
    return computeHmac(payload, 'FUEL_PRO_SQLCIPHER_MASTER_KEY_2026');
  }
}
