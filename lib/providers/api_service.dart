import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'dart:io';

class ApiService {
  static final String baseUrl = Platform.isAndroid
      ? 'http://10.0.2.2:5000' // Android Emulator
      : 'http://127.0.0.1:5000'; // Desktop/Web (localhost)
  static final Logger logger = Logger();
  static http.Client client = http.Client(); // default client ใช้งานจริง
  static Uri get updatePasswordUrl => Uri.parse('$baseUrl/reset-password');

  // ส่ง OTP
  static Future<bool> sendOtp(String email) async {
    final url = Uri.parse('$baseUrl/send-otp');
    try {
      final response = await client.post(
        // ✅ ใช้ client แทน http
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      logger.d('📡 Response status: ${response.statusCode}');
      logger.d('📡 Response body: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      logger.d('❌ Error during POST: $e');
      return false;
    }
  }

  // ตรวจสอบความถูกต้อง
  static Future<bool> verifyOtp(String email, String otp) async {
    final url = Uri.parse('$baseUrl/verify-otp');
    try {
      final response = await client.post(
        // ✅ ใช้ client
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "otp": otp}),
      );

      logger.d('✅ OTP verify response: ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      logger.d("❌ OTP verify failed: $e");
      return false;
    }
  }

  // เปลี่ยนรหัสผ่านใหม่
  static Future<bool> resetPassword(String email, String newPassword) async {
    final url = updatePasswordUrl;
    try {
      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'new_password': newPassword}),
      );

      logger.d('🛠️ Reset Password: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      logger.d('❌ Error resetting password: $e');
      return false;
    }
  }
}
