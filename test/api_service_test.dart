import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myproject/providers/api_service.dart';

void main() {
  group('ApiService', () {
    const email = 'test@example.com';
    const otp = '1234';
    final Uri sendOtpUrl = Uri.parse('${ApiService.baseUrl}/send-otp');
    final Uri verifyOtpUrl = Uri.parse('${ApiService.baseUrl}/verify-otp');
    final Uri updatePwdUrl = ApiService.updatePasswordUrl;

    test('sendOtp returns true when status is 200', () async {
      ApiService.client = MockClient((request) async {
        expect(request.url, sendOtpUrl);
        return http.Response('{"message":"OTP sent"}', 200);
      });

      final result = await ApiService.sendOtp(email);
      expect(result, true);
    });

    test('verifyOtp returns true when status is 200', () async {
      ApiService.client = MockClient((request) async {
        expect(request.url, verifyOtpUrl);
        return http.Response('{"message":"OTP verified"}', 200);
      });

      final result = await ApiService.verifyOtp(email, otp);
      expect(result, true);
    });

    test('updatePassword returns true when status is 200', () async {
      ApiService.client = MockClient((request) async {
        expect(request.url, updatePwdUrl);
        return http.Response('{"message":"Password updated"}', 200);
      });

      final result = await ApiService.resetPassword(email, 'NewPass123!');
      expect(result, true);
    });

    test('updatePassword returns false when status is not 200', () async {
      ApiService.client = MockClient((request) async {
        return http.Response('Weak password', 400);
      });

      final result = await ApiService.resetPassword(email, 'weak');
      expect(result, false);
    });

    test('updatePassword returns false on exception', () async {
      ApiService.client = MockClient((request) async {
        throw Exception('network error');
      });

      final result = await ApiService.resetPassword(email, 'NewPass123!');
      expect(result, false);
    });
  });
}
