import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // ใช้เฉพาะ Windows → ชี้ localhost
  static final String baseUrl = 'http://127.0.0.1:5000';
  static http.Client client = http.Client();

  // ---------- OTP (static) ----------
  static Uri get updatePasswordUrl => Uri.parse('$baseUrl/reset-password');

  // ส่ง OTP
  static Future<bool> sendOtp(String email) async {
    final url = Uri.parse('$baseUrl/send-otp');
    try {
      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      debugPrint('📡 send-otp: ${response.statusCode} ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ send-otp error: $e');
      return false;
    }
  }

  // ตรวจสอบความถูกต้อง
  static Future<bool> verifyOtp(String email, String otp) async {
    final url = Uri.parse('$baseUrl/verify-otp');
    try {
      final response = await client.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "otp": otp}),
      );
      debugPrint('📡 verify-otp: ${response.statusCode} ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("❌ verify-otp error: $e");
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
      debugPrint('📡 reset-password: ${response.statusCode} ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ reset-password error: $e');
      return false;
    }
  }

  // ---------- Detection (instance) ----------
  Future<void> detectHeartbeat() async {
    // ส่งภาพ/คำสั่งตรวจจับแบบ manual ถ้าเพิ่ม endpoint ภายหลัง
    // await ApiService.client.post(...);
  }

  // ---------- Camera (instance) ----------
  Future<bool> startCamera(String locationId) async {
    final url = Uri.parse('$baseUrl/start-camera');
    try {
      final res = await ApiService.client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'location_id': locationId}),
      );
      debugPrint('🎥 start-camera: ${res.statusCode} ${res.body}');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('❌ start-camera error: $e');
      return false;
    }
  }

  Future<bool> stopCamera() async {
    final url = Uri.parse('$baseUrl/stop-camera');
    try {
      final res = await ApiService.client.post(url);
      debugPrint('🛑 stop-camera: ${res.statusCode} ${res.body}');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('❌ stop-camera error: $e');
      return false;
    }
  }

  /// URL ภาพล้วนจาก backend
  String getFrameUrl({int? tick}) {
    final ts = tick ?? DateTime.now().millisecondsSinceEpoch;
    return '$baseUrl/frame_raw?ts=$ts';
  }

  /// alias เผื่อในโค้ดเดิมเคยเรียก frameUrl(...)
  String frameUrl({int? tick}) => getFrameUrl(tick: tick);
}
