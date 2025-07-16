import 'package:flutter/material.dart';
// import 'screens/sign_in_page.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/app_state.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en');
  runApp(
    ChangeNotifierProvider(create: (_) => AppState(), child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // debugShowCheckedModeBanner: false,
      // title: 'Sign In Page',
      // home: const SignInPage(),

      // debugShowCheckedModeBanner: false,
      // title: 'Sign In Page',
      // home: const UploadScreen(),
      debugShowCheckedModeBanner: false,
      title: 'Sign In Page',
      home: const MainScreen(
        username: 'vdowduang',
        email: 'vdowduang@gmail.com',
        colorHex: '#AB47BC',
      ),
    );
  }
}
