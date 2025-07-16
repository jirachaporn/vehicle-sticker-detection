// import 'dart:convert';
// import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'dart:math';

class EmailOtp {
  static final Logger _logger = Logger();

  // ฟังก์ชันสร้าง OTP
  static String generateOtp() {
    final random = Random();
    String otp = '';
    for (int i = 0; i < 4; i++) {
      otp += random.nextInt(10).toString();
    }
    return otp;
  }

  // ฟังก์ชันส่ง OTP ไปยังอีเมล
  static Future<bool> sendEmail(String email, String otp) async {
    // ตัวอย่าง URL การส่งอีเมลด้วย EmailJS
  //   final url = Uri.parse("https://api.emailjs.com/api/v1.0/email/send");
  //   const serviceId = 'service_k06i1pv';
  //   const templateId = 'template_9af88lk';
  //   const userId = 'luMzWOqynC-VSl9-a';

  //   final response = await http.post(
  //     url,
  //     headers: {
  //       'Content-Type': 'application/json',
  //     },
  //     body: jsonEncode({
  //       'service_id': serviceId,
  //       'template_id': templateId,
  //       'user_id': userId,
  //       'template_params': {
  //         'email': email, 
  //         'passcode': otp, 
  //       },
  //     }),
  //   );

  //   if (response.statusCode == 200) {
      _logger.i('✅ Email sent to $email with OTP: $otp');
      return true;
  //   } else {
  //     _logger.e('❌ Failed to send email to $email: ${response.body}');
  //     return false;
  //   }
  }
}
