// lib/helpers/snackbar_helper.dart

import 'package:flutter/material.dart';
import '../widgets/snackbar/fail_snackbar.dart';
import '../widgets/snackbar/success_snackbar.dart';

void showFailMessage(BuildContext context, String errorMessage, dynamic error) {
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
        elevation: 50,
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

void showSuccessMessage(BuildContext context, String message) {
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
