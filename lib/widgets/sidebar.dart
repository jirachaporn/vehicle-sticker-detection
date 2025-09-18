// lib/widgets/sidebar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../providers/permission_provider.dart'; // ✅ ใช้เช็คสิทธิ์จริง
import '../screens/sign_in_page.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCollapsed = MediaQuery.of(context).size.width < 1024;
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
                      // ✅ อ่านสิทธิ์ตาม location_id ปัจจุบัน
                      final bool isOwner = appState.isOwnerWith(perm);
                      final bool canEdit = appState.canEditWith(perm);

                      return Column(
                        children: [
                          // Main Menu Items
                          _buildMainMenuItem(
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

                          // Location-specific menu (แสดงเมื่อเลือกสถานที่แล้ว)
                          if (appState.selectedLocation != null) ...[
                            const SizedBox(height: 24),
                            if (!isCollapsed)
                              _buildLocationHeader(appState.selectedLocation!),
                            if (!isCollapsed) const SizedBox(height: 12),

                            // ทุกสิทธิ์เห็น Overview
                            _buildLocationMenuItem(
                              icon: Icons.dashboard,
                              label: 'Overview',
                              isActive:
                                  appState.currentView == AppView.overview,
                              onTap: () => appState.setView(AppView.overview),
                              isCollapsed: isCollapsed,
                            ),

                            // owner หรือ edit → เห็น Stickers
                            if (isOwner || canEdit) ...[
                              const SizedBox(height: 8),
                              _buildLocationMenuItem(
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

                            // ทุกสิทธิ์เห็น Camera, Notification, Table
                            const SizedBox(height: 8),
                            _buildLocationMenuItem(
                              icon: Icons.camera_alt,
                              label: 'Camera',
                              isActive: appState.currentView == AppView.camera,
                              onTap: () => appState.setView(AppView.camera),
                              isCollapsed: isCollapsed,
                            ),
                            const SizedBox(height: 8),
                            _buildLocationMenuItem(
                              icon: Icons.notifications,
                              label: 'Notification',
                              isActive:
                                  appState.currentView == AppView.notification,
                              onTap: () =>
                                  appState.setView(AppView.notification),
                              isCollapsed: isCollapsed,
                            ),
                            const SizedBox(height: 8),
                            _buildLocationMenuItem(
                              icon: Icons.table_chart,
                              label: 'Table',
                              isActive: appState.currentView == AppView.table,
                              onTap: () => appState.setView(AppView.table),
                              isCollapsed: isCollapsed,
                            ),

                            // Owner เท่านั้น → Add Permission
                            if (isOwner) ...[
                              const SizedBox(height: 8),
                              _buildLocationMenuItem(
                                icon: Icons.vpn_key,
                                label: 'Add Permission',
                                isActive:
                                    appState.currentView == AppView.permission,
                                onTap: () =>
                                    appState.setView(AppView.permission),
                                isCollapsed: isCollapsed,
                              ),
                            ],

                            // admin เท่านั้น → Annotation เดี๋ยวมาแก้สิทธิ์ ทำ UI ก่อน
                            if (isOwner) ...[
                              const SizedBox(height: 8),
                              _buildLocationMenuItem(
                                icon: Icons.label,
                                label: 'Annotation',
                                isActive:
                                    appState.currentView == AppView.annotation,
                                onTap: () =>
                                    appState.setView(AppView.annotation),
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
                  child: _buildSignOutButton(context, isCollapsed),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainMenuItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required bool isCollapsed,
  }) {
    bool isHovered = false;

    return StatefulBuilder(
      builder: (context, setState) {
        Widget menuItem = MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isCollapsed ? 8 : 12,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF1D4ED8)
                    : isHovered
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: isCollapsed
                  ? Center(child: Icon(icon, color: Colors.white, size: 24))
                  : Row(
                      children: [
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );

        if (isCollapsed) {
          return Tooltip(
            message: label,
            waitDuration: const Duration(seconds: 1),
            child: menuItem,
          );
        }
        return menuItem;
      },
    );
  }

  Widget _buildSignOutButton(BuildContext context, bool isCollapsed) {
    bool isHovered = false;

    return StatefulBuilder(
      builder: (context, setState) {
        Widget signOutButton = MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 100),
                  pageBuilder: (_, __, ___) => const SignInPage(),
                  transitionsBuilder: (_, animation, __, child) =>
                      FadeTransition(opacity: animation, child: child),
                ),
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isCollapsed ? 8 : 16,
                vertical: 12,
              ),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isHovered
                    ? Colors.red.withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: isHovered ? 1.05 : 1.0,
                child: isCollapsed
                    ? const Center(
                        child: Icon(
                          Icons.logout,
                          color: Colors.white,
                          size: 24,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/icon_BoxMoveLeft.png',
                            width: 25,
                            height: 25,
                          ),
                          const SizedBox(width: 8),
                          const Text(
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

        if (isCollapsed) {
          return Tooltip(
            message: 'Sign out',
            waitDuration: const Duration(seconds: 1),
            child: signOutButton,
          );
        }
        return signOutButton;
      },
    );
  }

  Widget _buildLocationHeader(dynamic location) {
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

  Widget _buildLocationMenuItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required bool isCollapsed,
  }) {
    bool isHovered = false;

    return StatefulBuilder(
      builder: (context, setState) {
        Widget menuItem = MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isCollapsed ? 8 : 12,
                vertical: 12,
              ),
              margin: EdgeInsets.only(left: isCollapsed ? 0 : 16),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF1D4ED8)
                    : isHovered
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: isCollapsed
                  ? Center(child: Icon(icon, color: Colors.white, size: 20))
                  : Row(
                      children: [
                        Icon(icon, color: Colors.white, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isActive)
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                            size: 16,
                          ),
                      ],
                    ),
            ),
          ),
        );

        if (isCollapsed) {
          return Tooltip(
            message: label,
            waitDuration: const Duration(seconds: 1),
            child: menuItem,
          );
        }
        return menuItem;
      },
    );
  }
}
