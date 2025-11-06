// // lib/providers/auth_provider.dart
// import 'package:flutter/foundation.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:crypto/crypto.dart';
// import 'dart:convert';

// class AuthProvider with ChangeNotifier {
//   final supa = Supabase.instance.client;

//   String? _userId;
//   String? _userEmail;
//   String? _userName;
//   String? _colorHex;
//   String? _userRole;

//   String? get userId => _userId;
//   String? get userEmail => _userEmail;
//   String? get userName => _userName;
//   String? get colorHex => _colorHex;
//   String? get userRole => _userRole;
//   bool get isAdmin => _userRole == 'admin';
//   bool get isLoggedIn => _userId != null;

//   // ✅ สำหรับ PermissionProvider ใช้
//   String get currentEmail => (_userEmail ?? '').toLowerCase();

//   Future<bool> login(String email, String password) async {
//     try {
//       final emailLc = email.trim().toLowerCase();
//       final passwordHash = sha256.convert(utf8.encode(password)).toString();

//       debugPrint('🔍 Attempting login: $emailLc');

//       // 1. ตรวจสอบ auth_users
//       final authUser = await supa
//           .from('auth_users')
//           .select('*')
//           .eq('auth_email', emailLc)
//           .maybeSingle();

//       if (authUser == null) {
//         debugPrint('❌ User not found in auth_users');
//         return false;
//       }

//       debugPrint('✅ Found user: ${authUser['auth_username']}');

//       // 2. เช็ค password
//       final storedHash = authUser['password_hash'] as String;
//       debugPrint('🔐 Password check: ${passwordHash == storedHash}');

//       if (passwordHash != storedHash) {
//         debugPrint('❌ Wrong password');
//         debugPrint('   Expected: $storedHash');
//         debugPrint('   Got: $passwordHash');
//         return false;
//       }

//       // 3. อัพเดท last_sign_in
//       await supa
//           .from('auth_users')
//           .update({
//             'last_sign_in': DateTime.now()
//                 .toUtc()
//                 .add(const Duration(hours: 7))
//                 .toIso8601String(),
//           })
//           .eq('auth_id', authUser['auth_id']);

//       // 4. ดึงโปรไฟล์จาก users (optional)
//       final userProfile = await supa
//           .from('users')
//           .select('user_name, user_email, color_profile, user_role')
//           .eq('user_id', authUser['auth_id'])
//           .maybeSingle();

//       debugPrint('📋 User profile: $userProfile');

//       // 5. เก็บข้อมูลใน memory
//       _userId = authUser['auth_id'] as String;
//       _userEmail = (userProfile?['user_email'] as String?)?.trim() ?? emailLc;
//       _userName =
//           (userProfile?['user_name'] as String?)?.trim() ??
//           (authUser['auth_username'] as String?)?.trim() ??
//           'User';
//       _colorHex =
//           (userProfile?['color_profile'] as String?)?.trim() ?? '#3254D0';
//       _userRole = (userProfile?['user_role'] as String?)?.trim() ?? 'user';

//       notifyListeners();
//       debugPrint(
//         '✅ Login success: $_userName ($_userEmail) | Role: $_userRole',
//       );
//       return true;
//     } catch (e, st) {
//       debugPrint('❌ Login error: $e');
//       debugPrint('Stack trace: $st');
//       return false;
//     }
//   }

//   Future<void> logout() async {
//     _userId = null;
//     _userEmail = null;
//     _userName = null;
//     _colorHex = null;
//     _userRole = null;
//     notifyListeners();
//     debugPrint('✅ Logged out');
//   }

//   // สำหรับ dev auto-login
//   Future<bool> devLogin(String email, String password) async {
//     debugPrint('🔧 Dev auto-login...');
//     return await login(email, password);
//   }
// }
