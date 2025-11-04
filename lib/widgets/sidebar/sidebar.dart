// lib/widgets/sidebar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../providers/permission_provider.dart';
import 'sign_out_btn.dart';
import 'buil_location_menu_item.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCollapsed =
            MediaQuery.of(context).size.width < 1024; // จอเล็กกว่า 1024 มั้ย
        final double sidebarWidth = isCollapsed ? 80 : 288;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: sidebarWidth,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: isCollapsed
                      ? const Icon(
                          Icons.directions_car,
                          color: Colors.white,
                          size: 40,
                        )
                      : const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Home',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
              ),

              // Navigation
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCollapsed ? 8 : 16,
                  ),
                  child: Consumer2<AppState, PermissionProvider>(
                    builder: (context, appState, perm, child) {
                      final bool isOwner = appState.isOwnerWith(perm);
                      final bool canEdit = appState.canEditWith(perm);
                      final bool isAdmin =
                          appState.isAdmin; // ✅ ใช้คุมเมนู Annotation ใต้ Home

                      return Column(
                        children: [
                          // ========= Main Menu =========
                          BuilLocationMenuItem(
                            icon: Icons.home,
                            label: 'Home',
                            isActive: appState.currentView == AppView.home,
                            onTap: () {
                              final email = appState.loggedInEmail;
                              appState.loadLocations(email);
                              appState.backToHome();
                            },
                            isCollapsed: isCollapsed,
                          ),

                          // ✅ Annotation (เฉพาะ admin) — อยู่ "ใต้ Home"
                          if (isAdmin)
                            BuilLocationMenuItem(
                              icon: Icons.label,
                              label: 'Annotation',
                              isActive:
                                  appState.currentView == AppView.annotation,
                              onTap: () => appState.setView(AppView.annotation),
                              isCollapsed: isCollapsed,
                            ),

                          // ========= Location-specific (เมื่อเลือกสถานที่แล้ว) =========
                          if (appState.selectedLocation != null) ...[
                            const SizedBox(height: 24),
                            if (!isCollapsed)
                              buildLocationHeader(appState.selectedLocation!),
                            if (!isCollapsed) const SizedBox(height: 12),

                            BuilLocationMenuItem(
                              icon: Icons.dashboard,
                              label: 'Overview',
                              isActive:
                                  appState.currentView == AppView.overview,
                              onTap: () => appState.setView(AppView.overview),
                              isCollapsed: isCollapsed,
                            ),

                            if (isOwner || canEdit) ...[
                              const SizedBox(height: 8),
                              BuilLocationMenuItem(
                                icon: Icons.sticky_note_2,
                                label: 'Models',
                                isActive:
                                    appState.currentView ==
                                    AppView.managemodels,
                                onTap: () =>
                                    appState.setView(AppView.managemodels),
                                isCollapsed: isCollapsed,
                              ),
                            ],

                            const SizedBox(height: 8),
                            BuilLocationMenuItem(
                              icon: Icons.camera_alt,
                              label: 'Camera',
                              isActive: appState.currentView == AppView.camera,
                              onTap: () => appState.setView(AppView.camera),
                              isCollapsed: isCollapsed,
                            ),
                            const SizedBox(height: 8),
                            BuilLocationMenuItem(
                              icon: Icons.notifications,
                              label: 'Notification',
                              isActive:
                                  appState.currentView == AppView.notification,
                              onTap: () =>
                                  appState.setView(AppView.notification),
                              isCollapsed: isCollapsed,
                            ),
                            const SizedBox(height: 8),
                            BuilLocationMenuItem(
                              icon: Icons.table_chart,
                              label: 'Table',
                              isActive: appState.currentView == AppView.table,
                              onTap: () => appState.setView(AppView.table),
                              isCollapsed: isCollapsed,
                            ),

                            if (isOwner) ...[
                              const SizedBox(height: 8),
                              BuilLocationMenuItem(
                                icon: Icons.vpn_key,
                                label: 'Add Permission',
                                isActive:
                                    appState.currentView == AppView.permission,
                                onTap: () =>
                                    appState.setView(AppView.permission),
                                isCollapsed: isCollapsed,
                              ),
                            ],
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),

              // Sign Out Button
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCollapsed ? 8 : 24,
                  ),
                  child: SignOutButton(isCollapsed: isCollapsed),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildLocationHeader(dynamic location) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.apartment, color: Colors.blue.shade200, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              location.name,
              style: TextStyle(
                color: Colors.blue.shade200,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
