import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../screens/sign_in_page.dart';

class SignOutButton extends StatefulWidget {
  final bool isCollapsed;

  const SignOutButton({super.key, required this.isCollapsed});

  @override
  State<SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends State<SignOutButton> {
  bool isHovered = false;

  Color get _backgroundColor =>
      isHovered ? Colors.red.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.1);

  @override
  Widget build(BuildContext context) {
    Widget button = MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: () async {
          context.read<AppState>().signOutAndReset();
          if (context.mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 100),
                pageBuilder: (_, __, ___) => const SignInPage(),
                transitionsBuilder: (_, animation, __, child) =>
                    FadeTransition(opacity: animation, child: child),
              ),
              (_) => false,
            );
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: widget.isCollapsed ? 8 : 16,
            vertical: 12,
          ),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 200),
            scale: isHovered ? 1.05 : 1.0,
            child: widget.isCollapsed
                ? const Center(
                    child: Icon(Icons.logout, color: Colors.white, size: 24),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.logout, color: Colors.white, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Sign out',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );

    if (widget.isCollapsed) {
      return Tooltip(
        message: 'Sign out',
        waitDuration: const Duration(seconds: 1),
        child: button,
      );
    }

    return button;
  }
}
