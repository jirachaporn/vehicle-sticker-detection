import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/app_state.dart';
import '../widgets/background.dart';
import '../widgets/snackbar/fail_snackbar.dart';
import '../widgets/snackbar/success_snackbar.dart';
import 'forgot_password_page.dart';
import 'sign_up_page.dart';
import 'main_page.dart';

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

  void showFailMessage(String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 20,
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
        top: 90,
        right: 16,
        child: Material(
          color: Colors.transparent,
          elevation: 20,
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

  // ------------------------------ Core logic ---------------------------------
  bool _looksLikeEmail(String s) => s.contains('@');

  /// ใช้ RPC (SECURITY DEFINER) เพื่อ map username -> email โดยไม่ติด RLS
  Future<Map<String, String>?> _rpcGetEmailByUsername(String username) async {
    final supabase = Supabase.instance.client;

    final res = await supabase.rpc(
      'get_email_by_username',
      params: {'p_username': username.trim()},
    );

    if (res == null) return null;

    // res อาจเป็น Map หรือ List ก็ได้ ขึ้นกับ PostgREST;
    // ฟังก์ชันนี้คืน table 1 แถว -> ปกติจะได้ List<dynamic> ยาว 1
    Map<String, dynamic>? row;
    if (res is List && res.isNotEmpty) {
      row = (res.first as Map).cast<String, dynamic>();
    } else if (res is Map) {
      row = res.cast<String, dynamic>();
    }

    if (row == null || (row['email'] as String?) == null) return null;

    return {
      'id': (row['id'] as String?) ?? '',
      'email': (row['email'] as String).trim().toLowerCase(),
      'username': (row['username'] as String?)?.trim() ?? '',
      'color': (row['color_profile'] as String?)?.trim() ?? '#3254D0',
    };
  }

  Future<void> handleLogin() async {
    final supabase = Supabase.instance.client;
    final inputRaw = _usernameOrEmailController.text.trim();
    final password = _passwordController.text;

    if (inputRaw.isEmpty || password.isEmpty) {
      showFailMessage('Error', 'Please fill in all required fields.');
      return;
    }

    setState(() => isLoading = true);

    try {
      String loginEmail = '';
      String displayUsername = '';
      String colorHex = '#3254D0';

      if (_looksLikeEmail(inputRaw)) {
        // ป้อนอีเมลโดยตรง
        loginEmail = inputRaw.toLowerCase();
      } else {
        // ป้อนเป็น username → map ไปหา email ผ่าน RPC
        final mapped = await _rpcGetEmailByUsername(inputRaw);
        if (mapped == null || (mapped['email'] ?? '').isEmpty) {
          showFailMessage(
            'User Not Found',
            'No account found with the entered email or username.',
          );
          return;
        }
        loginEmail = mapped['email']!;
        displayUsername = mapped['username']!;
        colorHex = mapped['color']!;
      }

      // 2) เข้าระบบด้วย email
      final authRes = await supabase.auth.signInWithPassword(
        email: loginEmail,
        password: password,
      );
      await context.read<AppState>().loadMyRole();

      if (authRes.user == null) {
        showFailMessage('Login Failed', 'Something is incorrect');
        return;
      }

      // 3) หลังล็อกอินแล้ว ค่อยอ่านโปรไฟล์ล่าสุดด้วยสิทธิ์ authenticated
      final uid = authRes.user!.id;
      final profLatest = await Supabase.instance.client
          .from('users')
          .select('email, username, color_profile')
          .eq('id', uid)
          .limit(1)
          .maybeSingle();

      final resolvedUsername =
          (profLatest?['username'] as String?)?.trim().isNotEmpty == true
          ? (profLatest?['username'] as String).trim()
          : (displayUsername.isNotEmpty ? displayUsername : loginEmail);

      final resolvedColor =
          (profLatest?['color_profile'] as String?)?.trim().isNotEmpty == true
          ? (profLatest?['color_profile'] as String).trim()
          : colorHex;

      showSuccessMessage('Welcome $resolvedUsername!');
      if (!mounted) return;

      context.read<AppState>().setLoggedInEmail(loginEmail);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MainPage(
            username: resolvedUsername,
            email: loginEmail,
            colorHex: resolvedColor,
          ),
        ),
      );
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid') ||
          (msg.contains('email') && msg.contains('password'))) {
        showFailMessage(
          'Invalid Login',
          'The username or password you entered is incorrect.',
        );
      } else if (msg.contains('not confirmed')) {
        showFailMessage(
          'Email not confirmed',
          'Please confirm your email before signing in.',
        );
      } else if (msg.contains('user not found')) {
        showFailMessage(
          'User Not Found',
          'No account found with the entered email or username.',
        );
      } else {
        showFailMessage('Auth Error', e.message);
      }
    } on PostgrestException catch (e) {
      showFailMessage('Database Error', e.message);
    } catch (e) {
      showFailMessage('Unexpected Error', 'Something went wrong.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ------------------------------ UI build -----------------------------------
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
