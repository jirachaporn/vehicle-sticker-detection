import 'package:flutter/material.dart';
import '../screens/sign_in_page.dart';

class BackToSign extends StatelessWidget {
  const BackToSign({super.key});

  void _navigateToSignIn(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 100),
        pageBuilder: (_, __, ___) => const SignInPage(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => _navigateToSignIn(context),
            ),
            InkWell(
              onTap: () => _navigateToSignIn(context),
              child: const Text(
                'Back to Sign in',
                style: TextStyle(
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
