// import 'package:flutter/material.dart';
// import 'screens/sign_in_page.dart';
// import 'package:provider/provider.dart';
// import 'package:intl/date_symbol_data_local.dart';
// import 'providers/app_state.dart';
// import 'screens/main_screen.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await dotenv.load();
//   await initializeDateFormatting('en');

//   await Supabase.initialize(
//     url: dotenv.env['SUPABASE_URL']!,
//     anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
//   );

//   await loginDevUser();

//   runApp(
//     ChangeNotifierProvider(create: (_) => AppState(), child: const MyApp()),
//   );
// }

// Future<void> loginDevUser() async {
//   final supabase = Supabase.instance.client;
//   final session = supabase.auth.currentSession;

//   if (session == null) {
//     final res = await supabase.auth.signInWithPassword(
//       email: 'vdowduang@gmail.com',
//       password: '123456789A.',
//     );

//     if (res.user != null) {
//       debugPrint('✅ Dev login: ${res.user!.email}');
//     } else {
//       debugPrint('❌ Login failed: ${res.session?.accessToken}');
//     }
//   }
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       // debugShowCheckedModeBanner: false,
//       // title: 'Sign In Page',
//       // home: const SignInPage(),

//       title: 'Main Screen',
//       home: const MainScreen(
//         username: 'vdowduang',
//         email: 'vdowduang@gmail.com',
//         colorHex: '#AB47BC',
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'providers/app_state.dart';
import 'screens/main_screen.dart';
// import 'screens/sign_in_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await initializeDateFormatting('en'); // จัดรูปแบบวันที่แบบ dd/mm/yyyy

  // เชื่อมกับ supbase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  await loginDevUser(); 

  runApp(
    ChangeNotifierProvider(create: (_) => AppState(), child: const MyApp()),
  );
}

Future<void> loginDevUser() async {
  final supabase = Supabase.instance.client; // เชื่อมฐานข้อมูล
  final session = supabase.auth.currentSession; // ตตรวจสอบ session ว่าเคย login มั้ย

  if (session == null) { // ไม่มี session เข้าด้วย Dev password
    final res = await supabase.auth.signInWithPassword(
      email: 'vdowduang@gmail.com',
      password: '123456789A.', 
    );

    if (res.user != null) { // เข้าสู้ระบบสำเร็จ
      debugPrint('✅ Dev login: ${res.user!.email}');
      await supabase.auth.refreshSession();
    } else { // เข้าสู้ระบบไม่สำเร็จ
      debugPrint('❌ Login failed: ${res.session?.accessToken}');
    }
  } else {
    debugPrint('✅ Already logged in: ${session.user.email}'); // ถ้ามี session
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser; // ดึงข้อมูลผู้ใช้ที่ล็อคอินอยู่

    // ถ้ายังไม่ได้ login 
    if (user == null) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: Text('🔒 กรุณาเข้าสู่ระบบก่อน'))),
      );
    }
 
    final meta = user.userMetadata ?? {};
    debugPrint('👤 user metadata: $meta');
    final username = meta['username'] ?? 'Unknown';
    final colorHex = meta['colorHex'] ?? '#4285F4';

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Main Screen',
      home: MainScreen(
        username: username,
        email: user.email ?? '',
        colorHex: colorHex,
      ),
    );
  }
}
