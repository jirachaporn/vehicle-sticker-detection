import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'providers/app_state.dart';
import 'screens/main_page.dart';
import 'providers/api_service.dart';
import 'providers/permission_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load();
  await initializeDateFormatting('en');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  await _loginDevUser(); // เฉพาะเครื่อง dev

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService()),
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => PermissionProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

Future<void> _loginDevUser() async {
  final supabase = Supabase.instance.client;
  // final session = supabase.auth.currentSession;

  final res = await supabase.auth.signInWithPassword(
    email: 'vdowduang@gmail.com',
    password: '123456789A.',
  );
  if (res.user != null) {
    debugPrint('✅ Dev login: ${res.user!.email}');
  }
  // if (session == null) {
  //   final res = await supabase.auth.signInWithPassword(
  //     email: 'vdowduang@gmail.com',
  //     password: '123456789A.',
  //   );
  //   if (res.user != null) {
  //     debugPrint('✅ Dev login: ${res.user!.email}');
  //     await supabase.auth.refreshSession();
  //   } else {
  //     debugPrint('❌ Login failed');
  //   }
  // } else {
  //   debugPrint('✅ Already logged in: ${session.user.email}');
  // }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: Text('🔒 กรุณาเข้าสู่ระบบก่อน'))),
      );
    }

    final meta = user.userMetadata ?? {};
    final username = meta['username'] ?? 'Unknown';
    final colorHex = meta['colorHex'] ?? '#4285F4';

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
