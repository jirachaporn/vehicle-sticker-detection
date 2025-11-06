import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
// import '../models/license_plate_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/notification_item.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as image_lib;

class ApiService {
  static final String? baseUrl = dotenv.env['API_BASE_URL'];
  static http.Client client = http.Client();
  final SupabaseClient supa = Supabase.instance.client;

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
    final url = Uri.parse('$baseUrl/reset-password');
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

  Future<void> markAllRead(String locationId) async {
    final url = Uri.parse('$baseUrl/notifications/mark-all-read');
    debugPrint('locationId: $locationId');

    final response = await http.patch(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'location_id': locationId, 'type': "ALL"}),
    );
    debugPrint('Response body: ${response.body}');
    if (response.statusCode != 200) {
      throw Exception('Failed to mark all as read: ${response.statusCode}');
    }
  }

  Future<bool> deleteNotification(String notificationId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/notifications/delete/$notificationId'),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> sendNotificationStatus(
    String modelId,
    String status,
  ) async {
    final url = Uri.parse('$baseUrl/model/$modelId/noti?status=$status');

    try {
      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      return response.statusCode == 200
          ? {'success': true, 'message': 'Notification sent successfully'}
          : {'success': false, 'message': 'Failed to send notification'};
    } catch (e) {
      debugPrint('❌ send-notification-status error: $e');
      return {'success': false, 'message': e.toString()};
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

  // แปลง  CameraImage -> JPEG
  static Uint8List convertYUV420ToJpeg(CameraImage image) {
    final yPlane = image.planes[0].bytes;
    final img = image_lib.Image(width: image.width, height: image.height);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = yPlane[y * image.width + x];
        img.setPixelRgba(x, y, pixel, pixel, pixel, 255);
      }
    }

    return Uint8List.fromList(image_lib.encodeJpg(img));
  }

  // ตรวจจับรถ
  static Future<Map<String, dynamic>?> detectVehicleFrom(
    Uint8List jpegBytes,
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://127.0.0.1:5000/camera/car-detect'),
      );
      request.files.add(
        http.MultipartFile.fromBytes('file', jpegBytes, filename: 'frame.jpg'),
      );

      var response = await request.send();
      debugPrint('🔍 car-detect status: ${response.statusCode}');

      if (response.statusCode == 200) {
        var body = await response.stream.bytesToString();
        debugPrint('📦 car-detect body: $body'); 

        if (body.isEmpty) {
          debugPrint('⚠️ body ว่างเปล่า');
          return null;
        }

        try {
          return jsonDecode(body);
        } catch (e) {
          debugPrint('❌ JSON decode error: $e');
          return null;
        }
      } else {
        debugPrint('❌ car-detect failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error calling detectVehicle API: $e');
      return null;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> detect_OCR(
    Uint8List jpegBytes, {
    required String locationId,
    required String modelId,
    required String direction,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://127.0.0.1:5000/detect'),
      );
      request.fields['location_id'] = locationId;
      request.fields['model_id'] = modelId;
      request.fields['direction'] = direction;
      request.files.add(
        http.MultipartFile.fromBytes('file', jpegBytes, filename: 'frame.jpg'),
      );

      var response = await request.send();
      if (response.statusCode == 200) {
        debugPrint('detect');
        var body = await response.stream.bytesToString();
        return jsonDecode(body);
      }
    } catch (e) {
      debugPrint('Error calling detectVehicle API: $e');
      return null;
    }
    return null;
  }
}
