import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myproject/widgets/snackbar/fail_snackbar.dart';
import 'package:myproject/widgets/snackbar/success_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:myproject/models/user_str.dart';
import 'package:myproject/screens/sign_in_page.dart';
import 'package:myproject/widgets/back_to_sign.dart';
import '../widgets/background.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  bool isLoading = false;
  bool isUsernameTaken = false;
  bool _obscureText = true;

  final formKey = GlobalKey<FormState>();
  UserStr userStr = UserStr("", "", "");

  final TextEditingController password_Controller = TextEditingController();
  final TextEditingController confirmPassword_Controller =
      TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  void _togglePasswordVisibility() =>
      setState(() => _obscureText = !_obscureText);

  // ใช้ Edge Function เป็นหน้า landing หลังยืนยันอีเมล
  // ตั้งค่าใน .env: CONFIRM_REDIRECT_URL=https://.../functions/v1/confirm-signup
  String _buildEmailRedirect() {
    final url =
        (dotenv.env['CONFIRM_REDIRECT_URL'] ??
                'https://qwiofwruecrdyfqdbwvu.supabase.co/functions/v1/confirm-signup')
            .trim();
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  Future<void> checkUsernameExists(String username) async {
    final supabase = Supabase.instance.client;
    final u = username.trim();
    try {
      final res = await supabase
          .from('users')
          .select('id')
          .eq('username', u)
          .limit(1);
      setState(() => isUsernameTaken = res.isNotEmpty);
    } on PostgrestException {
      setState(() => isUsernameTaken = false);
    } catch (_) {
      setState(() => isUsernameTaken = false);
    }
  }

  Future<void> _showConfirmDialog(String title, String message) async {
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.amber[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Confirm Your Email',
                      style: GoogleFonts.roboto(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.amber[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFF3254D0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Sign up ---------------------------------------------------------------
  Future<void> signUpUser() async {
    userStr.email = userStr.email.trim();
    userStr.username = userStr.username.trim();
    if (!(formKey.currentState?.validate() ?? false)) return;

    setState(() => isLoading = true);
    final supabase = Supabase.instance.client;

    final colors = ['#4285F4', '#EA4335', '#FBBC05', '#34A853', '#AB47BC'];
    final color = colors[Random.secure().nextInt(colors.length)];

    try {
      final email = userStr.email;
      final username = userStr.username;
      final redirectUrl = _buildEmailRedirect();

      if (!RegExp(r'^[A-Za-z0-9_]{3,20}$').hasMatch(username)) {
        showFailMessage(
          'Invalid username',
          'Use 3–20 chars: A–Z a–z 0–9 or underscore.',
        );
        return;
      }

      debugPrint('🔄 Starting signup process...');
      debugPrint('Email: $email');
      debugPrint('Username: $username');
      debugPrint('Color: $color');
      debugPrint('Redirect: $redirectUrl');

      final authRes = await supabase.auth.signUp(
        email: email,
        password: userStr.password,
        emailRedirectTo: redirectUrl,
        data: {'username': username, 'color_profile': color},
      );

      if (authRes.user == null) {
        throw const AuthException(
          'User creation returned null',
          statusCode: '500',
        );
      }
      debugPrint('✅ Auth user created: ${authRes.user!.id}');

      if (!mounted) return;

      if (authRes.user!.emailConfirmedAt == null) {
        await _showConfirmDialog(
          'Confirm Your Email',
          'We sent a confirmation link to:\n\n$email\n\nPlease verify your email before logging in.',
        );
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 120),
          pageBuilder: (_, __, ___) => const SignInPage(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } on AuthException catch (e) {
      debugPrint('❌ Signup failed: ${e.message}');
      debugPrint('📄 Error code: ${e.statusCode}');
      String userMessage =
          'There was a database error while creating your account. Please try again.';
      final m = e.message.toLowerCase();
      if (m.contains('user already registered')) {
        userMessage =
            'This email is already registered. Try signing in instead.';
      } else if (m.contains('invalid email')) {
        userMessage = 'Please enter a valid email address.';
      }
      showFailMessage('Signup Failed', userMessage);
    } catch (e) {
      debugPrint('❌ Signup failed (unknown): $e');
      String userMessage = 'An unexpected error occurred';

      final s = e.toString().toLowerCase();
      if (s.contains('duplicate key') && s.contains('username')) {
        userMessage =
            'This username is already taken. Please choose a different one.';
      }

      showFailMessage('Signup Failed', userMessage);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- Snackbars -------------------------------------------------------------
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
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 10,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: SuccessSnackbar(
            message: message,
            onClose: () => entry.remove(),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) entry.remove();
    });
  }

  // --- UI --------------------------------------------------------------------
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
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        'Sign Up',
                        style: GoogleFonts.roboto(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1B3BA7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: usernameController,
                      onChanged: (v) {
                        final s = v.trim();
                        userStr.username = s;
                        if (s.length >= 3) {
                          checkUsernameExists(s);
                        } else {
                          setState(() => isUsernameTaken = false);
                        }
                      },
                      onSaved: (v) =>
                          userStr.username = (v ?? '').trim(),
                      decoration: InputDecoration(
                        labelText: 'Username',
                        errorText: isUsernameTaken
                            ? 'Username already exists'
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isEmpty) return 'Please enter a username';
                        if (s.length < 3) return 'At least 3 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      onChanged: (v) => userStr.email = v,
                      onSaved: (v) =>
                          userStr.email = (v ?? '').trim(),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isEmpty) return 'Please enter an email';
                        if (!RegExp(
                          r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$',
                        ).hasMatch(s)) {
                          return 'Invalid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: password_Controller,
                      obscureText: _obscureText,
                      onSaved: (v) => userStr.password = v ?? '',
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureText
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: _togglePasswordVisibility,
                        ),
                      ),
                      validator: (v) {
                        final s = v ?? '';
                        if (s.isEmpty) return 'Enter password';
                        if (s.length < 8) return 'Min 8 chars';
                        if (!RegExp(r'[A-Z]').hasMatch(s))
                          return '1 uppercase letter';
                        if (!RegExp(r'[0-9]').hasMatch(s)) return '1 digit';
                        if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(s))
                          return '1 special char';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPassword_Controller,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Confirm password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (v) {
                        if ((v ?? '').isEmpty) return 'Confirm password';
                        if (v != password_Controller.text)
                          return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: isLoading || isUsernameTaken
                          ? null
                          : () async {
                              if (formKey.currentState?.validate() ?? false) {
                                formKey.currentState?.save();
                                await signUpUser();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                        backgroundColor: const Color(0xFF3254D0),
                        foregroundColor: Colors.white,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Sign Up'),
                    ),
                    BackToSign(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
