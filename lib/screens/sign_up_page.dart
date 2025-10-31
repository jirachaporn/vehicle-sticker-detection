import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myproject/models/user_str.dart';
import 'package:myproject/screens/sign_in_page.dart';
import 'package:myproject/widgets/back_to_sign.dart';
import '../widgets/background.dart';
import 'otp_page.dart';
import '../providers/api_service.dart';
import '../providers/snackbar_func.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  bool isLoading = false;
  bool isEmailTaken = false;
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

  Future<void> checkEmailExists(String email) async {
    final supabase = Supabase.instance.client;
    final e = email.trim();

    try {
      final res = await supabase
          .from('auth_users')
          .select('auth_id')
          .eq('auth_email', e)
          .maybeSingle();

      debugPrint('checkEmailExists: $res');
      setState(() => isEmailTaken = res != null);
    } on PostgrestException catch (err) {
      debugPrint('Supabase error: ${err.message}');
      setState(() => isEmailTaken = false);
    } catch (err) {
      debugPrint('Unknown error: $err');
      setState(() => isEmailTaken = false);
    }
  }

  // --- Sign up ---------------------------------------------------------------
  Future<void> signUpUser() async {
    final email = userStr.email.trim();
    final username = userStr.username.trim();
    final password = userStr.password;

    if (!(formKey.currentState?.validate() ?? false)) return;

    setState(() => isLoading = true);

    try {
      // เช็คอีเมลซ้ำ
      await checkEmailExists(email);
      if (isEmailTaken) {
        showFailMessage(context,'Email Error', 'Email already registered');
        return;
      }

      // ส่ง OTP
      final otpRes = await ApiService.sendSignupOtp(email);
      if (otpRes['success'] != true) {
        showFailMessage(context,'OTP Error', otpRes['message'] ?? 'Failed to send OTP');
        return;
      }

      await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => OTPPage(email: email, type: 'signup'),
        ),
      );

      final supabase = Supabase.instance.client;
      final passwordHash = sha256.convert(utf8.encode(password)).toString();
      final colors = ['#4285F4', '#EA4335', '#FBBC05', '#34A853', '#AB47BC'];
      final color = colors[Random.secure().nextInt(colors.length)];
      final newAuthId = const Uuid().v4();
      final nowThai = DateTime.now().toUtc().add(const Duration(hours: 7));

      await supabase.from('auth_users').insert({
        'auth_id': newAuthId,
        'auth_email': email,
        'auth_username': username,
        'password_hash': passwordHash,
        'created_at': nowThai.toIso8601String(),
        'last_sign_in': null,
      });

      await supabase.from('users').insert({
        'user_id': newAuthId, 
        'user_name': username,
        'user_email': email,
        'color_profile': color,
        'user_role': 'user',
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SignInPage()),
      );
    } catch (e) {
      debugPrint('❌ Signup failed: $e');
      showFailMessage(context,'Signup Failed', 'Please try to sign up again.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
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
                        userStr.username = v.trim();
                      },
                      onSaved: (v) => userStr.username = (v ?? '').trim(),
                      decoration: InputDecoration(
                        labelText: 'Username',
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
                      onChanged: (v) async {
                        userStr.email = v.trim();
                        if (v.trim().isNotEmpty) {
                          await checkEmailExists(v.trim());
                        } else {
                          setState(() => isEmailTaken = false);
                        }
                      },
                      onSaved: (v) => userStr.email = (v ?? '').trim(),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        errorText: isEmailTaken
                            ? 'This email is already registered'
                            : null,
                      ),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isEmpty) return 'Please enter an email';
                        if (!RegExp(
                          r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$',
                        ).hasMatch(s)) {
                          return 'Invalid email';
                        }
                        if (isEmailTaken) {
                          return 'This email is already registered';
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
                        if (!RegExp(r'[A-Z]').hasMatch(s)) {
                          return '1 uppercase letter';
                        }
                        if (!RegExp(r'[0-9]').hasMatch(s)) return '1 digit';
                        if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(s)) {
                          return '1 special char';
                        }
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
                        if (v != password_Controller.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: isLoading || isEmailTaken
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
