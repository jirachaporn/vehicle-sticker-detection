import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

Future<void> copyToClipboardAndDialogSuccess(
  BuildContext context, {
  required String title,
  required String message,
  required String copyText,
}) async {
  await Clipboard.setData(ClipboardData(text: copyText));
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 8),
          Text('สำเร็จ'),
        ],
      ),
      content: Text('$title\n\n$message'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ปิด'),
        ),
      ],
    ),
  );
}

Future<bool?> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'ยืนยัน',
  Color? confirmColor,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: confirmColor),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
}
