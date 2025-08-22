import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static final String baseUrl = 'http://127.0.0.1:5000'; // Desktop/Web (localhost)
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

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📡 Response body: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Error during POST: $e');
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

      debugPrint('✅ OTP verify response: ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("❌ OTP verify failed: $e");
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

      debugPrint('🛠️ Reset Password: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Error resetting password: $e');
      return false;
    }
  }
}
