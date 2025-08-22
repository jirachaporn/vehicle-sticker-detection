import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myproject/widgets/back_to_sign.dart';
import '../widgets/background.dart';
import '../providers/api_service.dart';
import 'otp_page.dart';
import '../widgets/snackbar/fail_snackbar.dart';
import '../widgets/loading.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPasswordPage> {
  bool find_email = true;
  String OTP = '';
  bool isLoading = false;

  final TextEditingController email_controller = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  void _submit() async {
    final email = email_controller.text.trim();

    setState(() {
      isLoading = true;
      find_email = true;
    });

    try {
      final success = await ApiService.sendOtp(email);

      setState(() => isLoading = false);

      if (success && mounted) {
        Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 100),
            pageBuilder: (_, __, ___) => OTPPage(email: email),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
      } else {
        showFailMessage(
          context,
          'OTP Failed',
          'Email not found or OTP not sent.',
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      showFailMessage(context, 'Error', 'Unexpected error occurred.');
    }
  }

  showFailMessage(BuildContext context, String errorMessage, dynamic error) {
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
            title: errorMessage,
            message: error,
            onClose: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      ),
    );
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/icon_Forgot_Password.png',
                      width: 130,
                      height: 130,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      'Forgot password',
                      style: GoogleFonts.roboto(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Center(
                    child: Text(
                      'Enter your email and we’ll send you link to reset your password',
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF949494),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: email_controller,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'E-mail',
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: !find_email
                              ? Color(0xFFCF181D)
                              : Color(0xFF949494),
                        ),
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

                  if (!find_email)
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Text(
                        'Please enter a valid email address.',
                        style: TextStyle(
                          color: Color(0xFFCF181D),
                          fontSize: 12,
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),
                  Center(
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(40),
                          backgroundColor: const Color(0xFF0B87EA),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Submit'),
                      ),
                    ),
                  ),

                  Center(child: BackToSign()),
                ],
              ),
            ),
          ),
          Loading(visible: isLoading),
        ],
      ),
    );
  }
}
