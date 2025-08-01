import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myproject/models/user_str.dart';
import 'package:myproject/screens/sign_in_page.dart';
import 'package:myproject/widgets/back_to_sign.dart';
import '../widgets/background.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  static final Logger _logger = Logger();
  bool isLoading = false;
  bool isUsernameTaken = false;
  bool isEmailTaken = false;
  bool _obscureText = true;

  final formKey = GlobalKey<FormState>();
  UserStr userStr = UserStr("", "", "");
  final TextEditingController password_Controller = TextEditingController();
  final TextEditingController confirmPassword_Controller =
      TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  void _togglePasswordVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  Future<void> checkUsernameExists(String username) async {
    final supabase = Supabase.instance.client;
    final res = await supabase
        .from('users')
        .select('id')
        .eq('username', username)
        .maybeSingle();
    setState(() => isUsernameTaken = res != null);
  }

  Future<void> checkEmailExists(String email) async {
    final supabase = Supabase.instance.client;
    final res = await supabase
        .from('users')
        .select('id')
        .eq('email', email)
        .maybeSingle();
    setState(() => isEmailTaken = res != null);
  }

  Future<void> signUpUser() async {
    setState(() => isLoading = true);
    final supabase = Supabase.instance.client;
    final colors = ['#4285F4', '#EA4335', '#FBBC05', '#34A853', '#AB47BC'];
    final randomColor = (colors..shuffle()).first;

    try {
      final authRes = await supabase.auth.signUp(
        email: userStr.email.trim(),
        password: userStr.password,
        emailRedirectTo: kIsWeb ? null : 'http://localhost',
      );

      final user = authRes.user;
      if (user == null) throw Exception("Failed to create user");

      await supabase.from('users').insert({
        'id': user.id,
        'username': userStr.username,
        'email': userStr.email,
        'color_profile': randomColor,
      });

      if (!mounted) return;

      if (user.emailConfirmedAt == null) {
        await showDialog(
          context: context,
          builder: (_) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 400,
              ), // 👈 ปรับขนาดตรงนี้
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
                        const Icon(
                          Icons.email_outlined,
                          color: Color(0xFF2042BD),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Confirm Your Email',
                          style: GoogleFonts.roboto(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: const Color(0xFF2042BD),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                        children: [
                          const TextSpan(
                            text: 'We sent a confirmation link to:\n\n',
                          ),
                          TextSpan(
                            text: user.email,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(
                            text:
                                '\n\nPlease check your inbox and click the link to verify your email before logging in.',
                          ),
                        ],
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

      _logger.i('✅ User registered successfully');

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 100),
          pageBuilder: (_, __, ___) => const SignInPage(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } catch (e) {
      _logger.e('❌ Signup failed: $e');
      await showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                      const Icon(Icons.error_outline, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Text(
                        'Signup Failed',
                        style: GoogleFonts.roboto(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    e.toString(),
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
                      onChanged: (val) {
                        userStr.username = val;
                        checkUsernameExists(val);
                      },
                      onSaved: (val) => userStr.username = val!,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        errorText: isUsernameTaken
                            ? 'Username already exists'
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Please enter a username';
                        }
                        if (val.length < 5) {
                          return 'At least 5 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      onChanged: (val) {
                        userStr.email = val;
                        checkEmailExists(val);
                      },
                      onSaved: (val) => userStr.email = val!,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        errorText: isEmailTaken ? 'Email already exists' : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Please enter an email';
                        }
                        if (!RegExp(
                          r"^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$",
                        ).hasMatch(val)) {
                          return 'Invalid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: password_Controller,
                      obscureText: _obscureText,
                      onSaved: (val) => userStr.password = val!,
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
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Enter password';
                        }
                        if (val.length < 8) {
                          return 'Min 8 chars';
                        }
                        if (!RegExp(r'[A-Z]').hasMatch(val)) {
                          return '1 uppercase letter';
                        }
                        if (!RegExp(r'[0-9]').hasMatch(val)) {
                          return '1 digit';
                        }
                        if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(val)) {
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
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Confirm password';
                        }
                        if (val != password_Controller.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: isLoading || isUsernameTaken || isEmailTaken
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
