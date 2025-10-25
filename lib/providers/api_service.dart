import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/license_plate_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/notification_item.dart';

class ApiService {
  // ใช้เฉพาะ Windows → ชี้ localhost
  static final String? baseUrl = dotenv.env['API_BASE_URL'];
  static http.Client client = http.Client();

  // ---------- OTP (static) ----------
  static Uri get updatePasswordUrl => Uri.parse('$baseUrl/reset-password');

  // ส่ง OTP
  static Future<bool> sendOtp(String email) async {
    final url = Uri.parse('$baseUrl/email/send-otp');
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
    final url = Uri.parse('$baseUrl/email/verify-otp');
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

  // signup OTP
  static Future<Map<String, dynamic>> sendSignupOtp(String email) async {
    final url = Uri.parse('$baseUrl/email/send-signup-otp');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      debugPrint('📡 send-signup-otp: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        final body = jsonDecode(response.body);
        return {
          'success': false,
          'message': body['detail'] ?? 'Failed to send OTP',
        };
      }
    } catch (e) {
      debugPrint('❌ send-signup-otp error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // verify OTP
  static Future<Map<String, dynamic>> verifySignupOtp(
    String email,
    String otp,
  ) async {
    final url = Uri.parse('$baseUrl/email/verify-signup-otp');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': otp}),
      );

      debugPrint(
        '📡 verify-signup-otp: ${response.statusCode} ${response.body}',
      );

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        final body = jsonDecode(response.body);
        return {
          'success': false,
          'message': body['detail'] ?? 'OTP verification failed',
        };
      }
    } catch (e) {
      debugPrint('❌ verify-signup-otp error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<NotificationItem>> fetchNotifications(String locationId) async {
    try {
      final url = Uri.parse(
        '$baseUrl/notifications?location_id=$locationId&status=all',
      );

      final res = await http.get(url);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List<dynamic> items = data['items'] ?? [];
        return items.map((e) => NotificationItem.fromJson(e)).toList();
      } else {
        throw Exception('Failed to load notifications: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      rethrow;
    }
  }

  Future<void> markRead(String notificationId) async {
    try {
      final url = Uri.parse('$baseUrl/notifications/$notificationId/read');
      final response = await http.patch(url);

      if (response.statusCode == 200) {
        debugPrint("Notification $notificationId marked as read.");
      } else {
        throw Exception('Failed to mark as read: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      rethrow;
    }
  }

  Future<void> markAllRead(String locationId, String type) async {
    final url = Uri.parse('$baseUrl/notifications/mark-all-read');
    final response = await http.patch(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'location_id': locationId, 'type': type}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to mark all as read: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>?> fetchOverviewData(String locationId) async {
    final url = Uri.parse('$baseUrl/overview/$locationId');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception('Failed to load overview data');
      }
    } catch (error) {
      debugPrint('Error fetching overview data: $error');
      return null;
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

  final SupabaseClient _supa = Supabase.instance.client;

  // ---------------------- READ ----------------------
  /// ดึงทะเบียนทั้งหมด (ถ้าใส่ [locationLicense] จะกรองตาม location)
  Future<List<LicensePlate>> getAllLicensePlates({
    String? locationLicense,
  }) async {
    try {
      final query = Supabase.instance.client.from('license_plate').select();

      final List<dynamic> rows = locationLicense == null
          ? await query.order('license_text', ascending: true)
          : await query
                .eq('location_license', locationLicense)
                .order('license_text', ascending: true);

      return rows
          .map((e) => LicensePlate.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      debugPrint('❌ getAllLicensePlates error: $e\n$st');
      return [];
    }
  }

  /// (เดิม) ดึงตาม location (คงไว้เพื่อไม่ต้องแก้ที่อื่น)
  Future<List<LicensePlate>> getLicensePlatesByLocation(
    String locationLicense,
  ) async {
    return getAllLicensePlates(locationLicense: locationLicense);
  }

  // ---------------------- CREATE/UPSERT ----------------------
  /// เพิ่มหลายรายการครั้งเดียว (batch). ถ้า [upsert]=true จะอัปเดตเมื่อ PK ซ้ำ
  Future<List<LicensePlate>> addLicensePlates(
    List<LicensePlate> plates, {
    bool upsert = false,
  }) async {
    if (plates.isEmpty) return <LicensePlate>[];
    try {
      final payload = plates.map((p) => p.toInsertMap()).toList();

      final List<dynamic> rows = await _supa
          .from('license_plate')
          .upsert(payload)
          .select();

      debugPrint('✅ addLicensePlates: inserted/updated ${rows.length} rows');
      return rows
          .map((e) => LicensePlate.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      debugPrint('❌ addLicensePlates error: $e\n$st');
      rethrow;
    }
  }

  /// เพิ่มทีละรายการ (helper)
  Future<LicensePlate?> addLicensePlate(
    LicensePlate plate, {
    bool upsert = false,
  }) async {
    final list = await addLicensePlates([plate], upsert: upsert);
    return list.isNotEmpty ? list.first : null;
  }

  // ---------------------- DELETE ----------------------
  /// ลบหลายรายการตามรายการ license_id
  Future<bool> deleteLicensePlates(List<String> licenseIds) async {
    if (licenseIds.isEmpty) return true;
    try {
      await Supabase.instance.client
          .from('license_plate')
          .delete()
          .inFilter('license_id', licenseIds);
      debugPrint('✅ Deleted ${licenseIds.length} license plates');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting license plates: $e');
      return false;
    }
  }
}
