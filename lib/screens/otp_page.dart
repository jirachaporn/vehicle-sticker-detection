// import
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myproject/screens/sign_in_page.dart';
import 'package:myproject/widgets/loading.dart';
import '../widgets/background.dart';
import 'reset_password.dart';
import '../providers/api_service.dart';
import '../providers/snackbar_func.dart';

class OTPPage extends StatefulWidget {
  final String email;
  final String type;
  const OTPPage({super.key, required this.email, required this.type});

  @override
  State<OTPPage> createState() => _OTPPageState();
}

class _OTPPageState extends State<OTPPage> {
  // ===== ตัวแปร =====
  final List<TextEditingController> controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> focusNodes = List.generate(4, (_) => FocusNode());
  final List<bool> hasEdited = List.filled(4, false);

  late int secondsRemaining;
  Timer? timer;
  bool isOtpExpired = false;
  bool isOtpIncorrect = false;
  String OTP = '';
  String email = '';
  bool isLoading = false;
  int resendCooldown = 0;
  Timer? resendTimer;

  // ===== ฟังก์ชัน =====
  @override
  void initState() {
    super.initState();
    startCountdown();
    startResendCooldown(); // เริ่มมาก็กันกดสแปม 30 วิแรก

    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNodes[0].requestFocus();
    });

    for (int i = 0; i < focusNodes.length; i++) {
      focusNodes[i].addListener(() {
        if (focusNodes[i].hasFocus && !hasEdited[i]) {
          controllers[i].clear();
          hasEdited[i] = true;
        }
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    resendTimer?.cancel();
    for (var controller in controllers) {
      controller.dispose();
    }
    for (var node in focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void startCountdown() {
    secondsRemaining = 180;
    isOtpExpired = false;
    timer?.cancel();

    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsRemaining > 0) {
        setState(() => secondsRemaining--);
      } else {
        timer.cancel();
        setState(() => isOtpExpired = true);
      }
    });
  }

  // เริ่มคูลดาวน์ 30 วิ สำหรับปุ่ม Reset
  void startResendCooldown() {
    resendTimer?.cancel();
    setState(() => resendCooldown = 30);

    resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (resendCooldown > 0) {
        setState(() => resendCooldown--);
      } else {
        t.cancel();
      }
    });
  }

  void onChanged(String value, int index) {
    if (value.isEmpty) {
      controllers[index].clear();
      FocusScope.of(context).requestFocus(focusNodes[index]);
      hasEdited[index] = false;
      return;
    }
    if (value.length > 1) {
      for (int i = 0; i < value.length && i < controllers.length; i++) {
        controllers[i].text = value[i];
        hasEdited[i] = true;
      }
      FocusScope.of(context).unfocus();
      return;
    }
    controllers[index]
      ..text = value
      ..selection = TextSelection.collapsed(offset: value.length);
    hasEdited[index] = true;

    if (index < focusNodes.length - 1) {
      FocusScope.of(context).requestFocus(focusNodes[index + 1]);
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  // กดขอ OTP ใหม่
  void resetOtp() async {
    if (resendCooldown > 0) return;

    setState(() => isLoading = true);
    try {
      for (var c in controllers) {
        c.clear();
      }
      setState(() => isOtpIncorrect = false);

      bool ok = false;
      if (widget.type == 'signup') {
        final res = await ApiService.sendSignupOtp(widget.email);
        ok = res['success'] == true;
      } else {
        ok = await ApiService.sendOtp(widget.email);
      }

      if (!mounted) return;

      if (ok) {
        startCountdown();
        startResendCooldown();
        FocusScope.of(context).requestFocus(focusNodes[0]);
      } else {
        showFailMessage(context,'Error', 'Failed to resend the code.');
      }
    } catch (e) {
      if (mounted) showFailMessage(context,'Error', 'Unexpected error occurred');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void onVerifyPressed() async {
    setState(() => isLoading = true);
    try {
      String enteredOtp = controllers.map((c) => c.text).join();
      if (isOtpExpired || enteredOtp.length != 4) {
        setState(() {
          isOtpIncorrect = true;
          isLoading = false;
        });
        return;
      }
      bool success = false;
      if (widget.type == 'signup') {
        final res = await ApiService.verifySignupOtp(widget.email, enteredOtp);
        success = res['success'] == true;
      } else {
        success = await ApiService.verifyOtp(widget.email, enteredOtp);
      }

      if (!mounted) return;

      if (success) {
        if (widget.type == 'reset') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ResetPasswordPage(email: widget.email),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const SignInPage()),
          );
        }
      } else {
        setState(() => isOtpIncorrect = true);
        showFailMessage(context,'OTP Failed', 'Invalid or expired OTP.');
      }
    } catch (e) {
      showFailMessage(context,'Error', 'Verification failed');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }


  // ===== Widget หลัก =====
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset('assets/icon_Mail.png', width: 150, height: 150),
                  const SizedBox(height: 10),
                  Text(
                    'OTP Verification',
                    style: GoogleFonts.roboto(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'A One-Time Password has been sent to your email',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.email,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, buildOtpBox),
                  ),
                  const SizedBox(height: 10),

                  Text(
                    'OTP will expire in: ${secondsRemaining ~/ 60}:${(secondsRemaining % 60).toString().padLeft(2, '0')} minutes',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 20),

                  Center(
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
                      child: ElevatedButton(
                        onPressed: isOtpExpired ? null : onVerifyPressed,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(40),
                          backgroundColor: const Color(0xFF0B87EA),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Verify'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
                      child: OutlinedButton(
                        onPressed: (resendCooldown > 0) ? null : resetOtp,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(40),
                          side: const BorderSide(color: Color(0xFF0B87EA)),
                          foregroundColor: const Color(0xFF0B87EA),
                        ),
                        child: Text(
                          (resendCooldown > 0)
                              ? 'Reset code (${resendCooldown}s)'
                              : 'Reset code',
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () {
                          if (widget.type == 'signup') {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SignInPage(),
                              ),
                            );
                          } else {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Loading(visible: isLoading),
        ],
      ),
    );
  }

  // ===== Widget ย่อย: ช่อง OTP =====
  Widget buildOtpBox(int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: SizedBox(
        width: 45,
        height: 50,
        child: TextField(
          controller: controllers[index],
          focusNode: focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            counterText: '',
            border: OutlineInputBorder(
              borderSide: BorderSide(
                color: isOtpIncorrect ? Colors.red : Colors.grey,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: isOtpIncorrect ? Colors.red : Colors.grey,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: isOtpIncorrect ? Colors.red : Colors.blue,
                width: 2.0,
              ),
            ),
          ),
          onChanged: (value) => onChanged(value, index),
        ),
      ),
    );
  }
}
