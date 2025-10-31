// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'providers/app_state.dart';
import 'providers/api_service.dart';
import 'providers/permission_provider.dart';
import 'providers/camera_manager.dart';
import 'screens/main_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load();
  await initializeDateFormatting('en');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  await _loginDevUser();

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService()),
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => PermissionProvider()),
        ChangeNotifierProvider(create: (_) => CameraManager()),
      ],
      child: const MyApp(),
    ),
  );
}

// ---------- dev auto-login ----------
Future<void> _loginDevUser() async {
  final supa = Supabase.instance.client;
  try {
    final res = await supa.auth.signInWithPassword(
      email: 'vdowduang@gmail.com',
      password: '123456789A.',
    );
    if (res.user != null) {
      debugPrint('Dev login: ${res.user!.email}');
    } else {
      debugPrint('Dev login failed');
    }
  } catch (e) {
    debugPrint('Dev login error: $e');
  }
}

// ---------- App root ----------
class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // ✅ เรียกโหลด role หลังมี BuildContext แล้ว
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && mounted) {
        await context.read<AppState>().loadMyRole();
      }

      // (ออปชัน) ถ้า state auth เปลี่ยนระหว่างใช้งาน ให้ sync role อัตโนมัติ
      Supabase.instance.client.auth.onAuthStateChange.listen((event) async {
        if (!mounted) return;
        final u = event.session?.user;
        if (u != null) {
          await context.read<AppState>().loadMyRole();
        } else {
          final app = context.read<AppState>();
          app.isAdmin = false;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    // ถ้าไม่มีผู้ใช้ (เผื่อ dev login ล้มเหลว)
    if (user == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: Text('🔒 กรุณาเข้าสู่ระบบก่อน')),
        ),
      );
    }

    final meta = user.userMetadata ?? {};
    final username = (meta['username'] ?? 'Unknown').toString();
    final colorHex = (meta['colorHex'] ?? '#4285F4').toString();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Main Screen',
      home: MainPage(
        username: username,
        email: user.email ?? '',
        colorHex: colorHex,
      ),
    );
  }
}
