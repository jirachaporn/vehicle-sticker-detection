import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/permission_provider.dart';

class InviteTab extends StatelessWidget {
  final String locationId;
  final TextEditingController inviteEmailCtrl;
  final TextEditingController inviteNameCtrl;
  final String invitePerm;
  final ValueChanged<String> onPermChanged;
  final bool loading;
  final Future<void> Function() onSubmit;

  const InviteTab({
    super.key,
    required this.locationId,
    required this.inviteEmailCtrl,
    required this.inviteNameCtrl,
    required this.invitePerm,
    required this.onPermChanged,
    required this.loading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    context.watch<PermissionProvider>();

    return Container(
      color: Colors.grey.shade100,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ===== Card เชิญสมาชิกใหม่ =====
                Card(
                  color: Colors.white,
                  elevation: 2,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.shield_outlined,
                              color: Colors.black54,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Invite New Member',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Enter the email of the person you want to invite and select the permission. '
                          'The system will send a confirmation link automatically.',
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 12),
                        Column(
                          children: [
                            TextField(
                              controller: inviteEmailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Invitee Email *',
                                labelStyle: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black,
                                ),
                                prefixIcon: const Icon(Icons.email_outlined),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF2563EB),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: inviteNameCtrl,
                              decoration: InputDecoration(
                                labelText: 'Name (Optional)',
                                labelStyle: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black,
                                ),
                                prefixIcon: const Icon(Icons.person_outline),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF2563EB),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Permission Picker Inline
                            DropdownButtonFormField<String>(
                              value: invitePerm,
                              isExpanded: true,
                              dropdownColor: Colors.white,
                              elevation: 8,
                              borderRadius: BorderRadius.circular(12),
                              decoration: InputDecoration(
                                labelText: 'Permission *',
                                labelStyle: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black,
                                ),
                                prefixIcon: const Icon(Icons.security_outlined),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF2563EB),
                                    width: 2,
                                  ),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem<String>(
                                  value: 'view',
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 10.0,
                                      horizontal: 4.0,
                                    ),
                                    child: Text(
                                      'Viewer',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ),
                                DropdownMenuItem<String>(
                                  value: 'edit',
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 10.0,
                                      horizontal: 4.0,
                                    ),
                                    child: Text(
                                      'Editor',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) onPermChanged(v);
                              },
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: loading ? null : onSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.send),
                                label: loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Send Invitation'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // ===== Card วิธีใช้ลิงก์ยืนยัน =====
                Card(
                  color: Colors.white,
                  elevation: 2,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.shield_outlined,
                              color: Colors.black54,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'How to Use the Confirmation Link',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '1) The system will send an email with a confirmation link to the invitee.',
                            ),
                            Text(
                              '2) The invitee must click the confirmation link to accept the invitation.',
                            ),
                            Text(
                              '3) Once confirmed, the invitee will gain access to the specified location according to the assigned permission.',
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Permission Levels:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '• View – Can only view the location data. Cannot edit or upload any information.',
                            ),
                            Text(
                              '• Edit – Can view, edit, and upload information for the location.',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
