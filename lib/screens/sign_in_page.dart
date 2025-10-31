import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/app_state.dart';
import '../widgets/background.dart';
import 'forgot_password_page.dart';
import 'sign_up_page.dart';
import 'main_page.dart';
import '../providers/snackbar_func.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final TextEditingController _usernameOrEmailController =
      TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscureText = true;
  bool isHoveringForgot = false;
  bool isHoveringSignin = false;
  bool isLoading = false;

  // ------------------------------ UI helpers ---------------------------------
  void _togglePasswordVisibility() {
    setState(() => _obscureText = !_obscureText);
  }

  Future<void> handleLogin() async {
    final supabase = Supabase.instance.client;
    final email = _usernameOrEmailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showFailMessage(context,'Error', 'Please fill in all required fields.');
      return;
    }

    setState(() => isLoading = true);

    try {
      final authUser = await supabase
          .from('auth_users')
          .select('*')
          .eq('auth_email', email)
          .maybeSingle();

      debugPrint('authUser: ${authUser.toString()}');
      if (authUser == null) {
        showFailMessage(context,'Login Failed', 'Email or password is incorrect.');
        return;
      }
      final passwordHash = sha256.convert(utf8.encode(password)).toString();
      if (passwordHash != (authUser['password_hash'] as String)) {
        showFailMessage(context,'Login Failed', 'Email or password is incorrect.');
        return;
      }

      await supabase
          .from('auth_users')
          .update({'last_sign_in': DateTime.now().toIso8601String()})
          .eq('auth_id', authUser['auth_id']);

      final userProfile = await supabase
          .from('users')
          .select('user_name, color_profile')
          .eq('user_email', email)
          .limit(1)
          .maybeSingle();

      final userName = (userProfile?['user_name'] as String?)?.trim() ?? email;
      final colorHex =
          (userProfile?['color_profile'] as String?)?.trim() ?? '#3254D0';

      showSuccessMessage(context,'Welcome $userName!');
      if (!mounted) return;

      context.read<AppState>().setLoggedInEmail(email);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              MainPage(username: userName, email: email, colorHex: colorHex),
        ),
      );
    } catch (e) {
      debugPrint('Login error: $e');
      showFailMessage(context,'Unexpected Error', 'Something went wrong.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ------------------------------ UI -----------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2042BD),
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: BackgroundPainter())),
          Center(
            child: Container(
              width: 600,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Sign in',
                    style: GoogleFonts.roboto(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1B3BA7),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _usernameOrEmailController,
                    decoration: InputDecoration(
                      labelText: 'Username or Email',
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF949494)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFF005FAB),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscureText,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF949494)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFF005FAB),
                          width: 2,
                        ),
                      ),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: _togglePasswordVisibility,
                          child: Icon(
                            _obscureText
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5.0, bottom: 10.0),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        onEnter: (_) => setState(() => isHoveringForgot = true),
                        onExit: (_) => setState(() => isHoveringForgot = false),
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordPage(),
                            ),
                          ),
                          child: Text(
                            'Forgot password?',
                            style: TextStyle(
                              fontSize: 12,
                              color: isHoveringForgot
                                  ? const Color(0xFF4264D5)
                                  : const Color(0xFF0B87EA),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: isLoading ? null : handleLogin,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 40),
                      backgroundColor: const Color(0xFF3254D0),
                      foregroundColor: Colors.white,
                    ),
                    child: isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : const Text('Sign in'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? "),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SignUpPage()),
                        ),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) =>
                              setState(() => isHoveringSignin = true),
                          onExit: (_) =>
                              setState(() => isHoveringSignin = false),
                          child: Text(
                            'Sign up',
                            style: TextStyle(
                              color: const Color(0xFF0B87EA),
                              decoration: isHoveringSignin
                                  ? TextDecoration.underline
                                  : TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
