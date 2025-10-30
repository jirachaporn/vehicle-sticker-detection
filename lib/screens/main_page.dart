import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:myproject/widgets/top_header.dart';
import '../providers/app_state.dart';
import '../widgets/sidebar.dart';
import 'home_page.dart';
import 'permission_page.dart';
import 'overview_page.dart';
import 'manage_models.dart';
import 'camera_page.dart';
import 'notification_page.dart';
import 'data_table_page.dart';
import 'annotation_page.dart';
import '../providers/permission_provider.dart';
import '../providers/api_service.dart';

class MainPage extends StatefulWidget {
  final String username;
  final String email;
  final String colorHex;

  const MainPage({
    super.key,
    required this.username,
    required this.email,
    required this.colorHex,
  });

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final appState = context.read<AppState>();

      try {
        await appState.loadLocations(widget.email);

        if (mounted && appState.locations.isNotEmpty) {
          final permissionProvider = context.read<PermissionProvider>();
          await permissionProvider.loadMembers(appState.locations.first.id);
        }
      } catch (e) {
        debugPrint('❌ Error loading initial data: $e');
      }
    });
  }

  Color parseHexColor(String hexColor) {
    var h = hexColor.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse('0x$h'));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final location = appState.selectedLocation;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F1),
      body: Row(
        children: [
          const Sidebar(),
          Expanded(
            child: Column(
              children: [
                TopHeader(
                  email: widget.email,
                  username: widget.username,
                  color: parseHexColor(widget.colorHex),
                ),
                Expanded(
                  child: () {
                    // หน้าแรก
                    if (appState.currentView == AppView.home) {
                      return const HomePage();
                    }
                    if (appState.currentView == AppView.annotation) {
                      return const AnnotationPage();
                    }
                    if (location == null) {
                      return const Center(
                        child: Text(
                          'Please select a location first.',
                          style: TextStyle(fontSize: 18),
                        ),
                      );
                    }
                    switch (appState.currentView) {
                      case AppView.home:
                        return const HomePage();
                      case AppView.overview:
                        return OverviewPage(
                          locationId: appState.locationId ?? '',
                        );
                      case AppView.permission:
                        return PermissionPage(
                          locationId: appState.locationId ?? '',
                          locationName: location.name,
                        );
                      case AppView.camera:
                        {
                          final locId = appState.locationId ?? '';
                          return Provider<ApiService>.value(
                            value: context.read<ApiService>(),
                            child: CameraPage(locationId: locId),
                          );
                        }

                      case AppView.notification:
                        return NotificationPage(
                          locationId: appState.locationId ?? '',
                          locationName: location.name,
                        );
                      case AppView.table:
                        return DataTablePage(
                          locationId: appState.locationId ?? '',
                        );
                      case AppView.managemodels:
                        return ManageModels(
                          locationId: appState.locationId ?? '',
                        );
                      case AppView.annotation:
                        return AnnotationPage();
                    }
                  }(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
