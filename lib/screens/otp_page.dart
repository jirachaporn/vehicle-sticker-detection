import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myproject/widgets/loading.dart';
import '../widgets/background.dart';
import 'reset_password.dart';
import '../providers/api_service.dart';
import '../widgets/snackbar/fail_snackbar.dart';

class OTPPage extends StatefulWidget {
  final String email;
  const OTPPage({super.key, required this.email});

  @override
  State<OTPPage> createState() => _OTPPageState();
}

class _OTPPageState extends State<OTPPage> {
  final List<TextEditingController> controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> focusNodes = List.generate(4, (_) => FocusNode());
  final List<bool> hasEdited = List.filled(4, false);

  late int _secondsRemaining;
  Timer? _timer;
  bool _isOtpExpired = false;
  bool _isOtpIncorrect = false;
  String OTP = '';
  String email = '';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();

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
    _timer?.cancel();
    for (var controller in controllers) {
      controller.dispose();
    }
    for (var node in focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _secondsRemaining = 180;
    _isOtpExpired = false;
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
        setState(() {
          _isOtpExpired = true;
        });
      }
    });
  }

  void _onChanged(String value, int index) {
    if (value.isEmpty) {
      controllers[index].clear();
      FocusScope.of(context).requestFocus(focusNodes[index]);
      hasEdited[index] = false;
      return;
    }

    // ถ้า paste หลายตัว เช่น "1234"
    if (value.length > 1) {
      for (int i = 0; i < value.length && i < controllers.length; i++) {
        controllers[i].text = value[i];
        hasEdited[i] = true;
      }
      FocusScope.of(context).unfocus();
      return;
    }

    // แทนที่ค่าทันทีที่พิมพ์
    controllers[index]
      ..text = value
      ..selection = TextSelection.collapsed(offset: value.length);

    hasEdited[index] = true;

    // ไปช่องถัดไปถ้ามี
    if (index < focusNodes.length - 1) {
      FocusScope.of(context).requestFocus(focusNodes[index + 1]);
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  // ✅ ทำให้รีเซ็ต OTP ใช้งานได้จริง
  void resetOtp() async {
    setState(() => isLoading = true);
    try {
      // ล้างช่องกรอกทั้งหมด + เคลียร์สถานะผิด
      for (var c in controllers) {
        c.clear();
      }
      setState(() {
        _isOtpIncorrect = false;
      });

      // เรียกหลังบ้านให้ส่ง OTP ใหม่ไปยังอีเมลเดิม
      final ok = await ApiService.sendOtp(widget.email);

      if (!mounted) return;

      if (ok) {
        // รีสตาร์ทตัวนับเวลา + โฟกัสช่องแรก
        _startCountdown();
        FocusScope.of(context).requestFocus(focusNodes[0]);
        
      } else {
        showFailMessage(
          context,
          'Error',
          'Failed to resend the code. Please try again.',
        );
      }
    } catch (e) {
      if (mounted) {
        showFailMessage(context, 'Error', 'An unexpected error occurred');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _onVerifyPressed() async {
    setState(() => isLoading = true);

    try {
      String enteredOtp = controllers.map((c) => c.text).join();

      if (_isOtpExpired || enteredOtp.length != 4) {
        setState(() {
          _isOtpIncorrect = true;
          isLoading = false;
        });
        return;
      }

      // ✅ เรียก backend
      final success = await ApiService.verifyOtp(widget.email, enteredOtp);

      if (success && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResetPasswordPage(email: widget.email),
          ),
        );
      } else {
        setState(() {
          _isOtpIncorrect = true;
        });
        showFailMessage(context, 'OTP Failed', 'Invalid or expired OTP.');
      }
    } catch (e) {
      showFailMessage(context, 'Error', 'Verification failed');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
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
                    children: List.generate(4, _buildOtpBox),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'OTP will expire in: ${_secondsRemaining ~/ 60}:${(_secondsRemaining % 60).toString().padLeft(2, '0')} minutes',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
                      child: ElevatedButton(
                        onPressed: _isOtpExpired ? null : _onVerifyPressed,
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
                        onPressed: resetOtp,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(40),
                          side: const BorderSide(color: Color(0xFF0B87EA)),
                          foregroundColor: const Color(0xFF0B87EA),
                        ),
                        child: const Text('Reset code'),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.black,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          ),
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            child: const Text(
                              'Back to Sign in',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                        ],
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

  // box otp
  Widget _buildOtpBox(int index) {
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
                color: _isOtpIncorrect ? Colors.red : Colors.grey,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: _isOtpIncorrect ? Colors.red : Colors.grey,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: _isOtpIncorrect ? Colors.red : Colors.blue,
                width: 2.0,
              ),
            ),
          ),
          onChanged: (value) => _onChanged(value, index),
        ),
      ),
    );
  }
}
