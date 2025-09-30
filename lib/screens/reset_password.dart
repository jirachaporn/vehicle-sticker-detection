import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myproject/screens/sign_in_page.dart';
import 'package:myproject/widgets/back_to_sign.dart';
import 'package:myproject/widgets/snackbar/success_snackbar.dart';
import '../widgets/background.dart';
import '../widgets/snackbar/fail_snackbar.dart';
import '../widgets/loading.dart';
import 'package:myproject/providers/api_service.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;
  const ResetPasswordPage({super.key, required this.email});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPagetate();
}

class _ResetPasswordPagetate extends State<ResetPasswordPage> {
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();

  bool hasUppercase = false;
  bool hasDigit = false;
  bool hasSpecialChar = false;
  bool hasMinLength = false;
  bool isConfirmMatch = true;
  bool showConfirmError = false;
  bool isLoading = false;

  void _validatePassword(String password) {
    setState(() {
      hasUppercase = password.contains(RegExp(r'[A-Z]'));
      hasDigit = password.contains(RegExp(r'\d'));
      hasSpecialChar = password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
      hasMinLength = password.length >= 8;
    });
  }

  Future<void> handleSubmit() async {
    final isMatch = confirmController.text == passwordController.text;

    setState(() {
      isConfirmMatch = isMatch;
      showConfirmError = !isMatch;
    });

    if (!isMatch) {
      showFailMessage('Error', 'Passwords do not match');
      return;
    }

    setState(() => isLoading = true);

    final success = await ApiService.resetPassword(
      widget.email,
      passwordController.text,
    );

    setState(() => isLoading = false);

    if (success) {
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SignInPage()),
          (route) => false,
        );
        showSuccessMessage('Successfully!');
      });
    } else {
      showFailMessage('Failed to change password', 'Please try again later');
    }
  }

  void showSuccessMessage(String message) {
    final nav = Navigator.of(context, rootNavigator: true);
    final overlay = nav.overlay;
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 90,
        right: 16,
        child: Material(
          color: Colors.transparent,
          elevation: 20,
          child: SuccessSnackbar(
            message: message,
            onClose: () {
              if (entry.mounted) entry.remove();
            },
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3)).then((_) {
      if (entry.mounted) entry.remove();
    });
  }

  void showFailMessage(String errorMessage, dynamic error) {
    final nav = Navigator.of(context, rootNavigator: true);
    final overlay = nav.overlay;
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        bottom: 10,
        right: 16,
        child: Material(
          color: Colors.transparent,
          elevation: 50, // สูงกว่า dialog
          child: FailSnackbar(
            title: errorMessage,
            message: error,
            onClose: () {
              if (entry.mounted) entry.remove();
            },
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3)).then((_) {
      if (entry.mounted) entry.remove();
    });
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
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      'Reset Password',
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
                      'Please enter a new password for your account.',
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF949494),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    onChanged: _validatePassword,
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
                    ),
                  ),
                  const SizedBox(height: 10),

                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildCondition(
                              'At least one uppercase letter (A-Z)',
                              hasUppercase,
                            ),
                          ),
                          Expanded(
                            child: _buildCondition(
                              'At least one digit (0-9)',
                              hasDigit,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildCondition(
                              'At least one special character (e.g. !@#\$%)',
                              hasSpecialChar,
                            ),
                          ),
                          Expanded(
                            child: _buildCondition(
                              'Minimum of 8 characters',
                              hasMinLength,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  TextField(
                    controller: confirmController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Confirm password',
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: showConfirmError
                              ? Colors.red
                              : Color(0xFF949494),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: showConfirmError
                              ? Colors.red
                              : Color(0xFF005FAB),
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  if (showConfirmError)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Icon(Icons.cancel, color: Colors.red, size: 18),
                          const SizedBox(width: 6),
                          const Text(
                            'Passwords do not match',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 30),
                  Center(
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
                      child: ElevatedButton(
                        onPressed:
                            (hasUppercase &&
                                hasDigit &&
                                hasSpecialChar &&
                                hasMinLength)
                            ? handleSubmit
                            : null,

                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(40),
                          backgroundColor: const Color(0xFF0B87EA),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFB0C4DE),
                          disabledForegroundColor: Colors.white,
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

  Widget _buildCondition(String text, bool conditionMet) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          conditionMet ? Icons.check_circle : Icons.cancel,
          color: conditionMet ? Colors.green : Colors.red,
          size: 18,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: conditionMet ? Colors.green : Colors.red,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
