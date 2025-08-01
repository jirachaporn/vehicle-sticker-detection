import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

import '../providers/app_state.dart';
import '../widgets/background.dart';
import '../widgets/fail_snackbar.dart';
import '../widgets/success_snackbar.dart';
import 'forgot_password_page.dart';
import 'sign_up_page.dart';
import 'main_screen.dart';

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

  static final Logger _logger = Logger();

  void _togglePasswordVisibility() {
    setState(() => _obscureText = !_obscureText);
  }

  void showFailMessage(String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        duration: const Duration(seconds: 3),
        padding: EdgeInsets.zero,
        content: Align(
          alignment: Alignment.topRight,
          child: FailSnackbar(
            title: title,
            message: message,
            onClose: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      ),
    );
  }

  void showSuccessMessage(String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 10,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: SuccessSnackbar(
            message: message,
            onClose: () => overlayEntry.remove(),
          ),
        ),
      ),
    );
    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), () {
      if (overlayEntry.mounted) overlayEntry.remove();
    });
  }

  Future<void> handleLogin() async {
    final supabase = Supabase.instance.client;
    final input = _usernameOrEmailController.text.trim();
    final password = _passwordController.text;

    if (input.isEmpty || password.isEmpty) {
      showFailMessage('Error', 'Please fill in all required fields.');
      return;
    }

    setState(() => isLoading = true);

    try {
      final profile = await supabase
          .from('users')
          .select('email, username, color_profile')
          .or('email.eq.$input,username.eq.$input')
          .limit(1)
          .single();

      final email = profile['email'];
      final username = profile['username'];
      final color = profile['color_profile'];

      final authRes = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authRes.user == null) {
        showFailMessage('Login Failed', 'Something is incorrect');
        return;
      }

      showSuccessMessage('Welcome $username!');
      if (!mounted) return;
      context.read<AppState>().setLoggedInEmail(email);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              MainScreen(username: username, email: email, colorHex: color),
        ),
      );
    } catch (e) {
      _logger.e('Login error: $e');
      if (e.toString().contains('invalid')) {
        showFailMessage(
          'Invalid Login',
          'The username or password you entered is incorrect.',
        );
      } else if (e.toString().contains('401')) {
        showFailMessage(
          'Unauthorized',
          'Please check your credentials and try again.',
        );
      } else if (e.toString().contains('404')) {
        showFailMessage(
          'User Not Found',
          'No account found with the entered email or username.',
        );
      } else {
        showFailMessage(
          'Unexpected Error',
          'Something went wrong. Please try again later.',
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

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
