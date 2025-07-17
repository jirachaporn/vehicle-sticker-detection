import 'package:flutter/material.dart';
import 'package:myproject/screens/generic_screen.dart';
import 'package:myproject/widgets/top_header.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../widgets/sidebar.dart';
import 'home_page.dart';
import 'permission_page.dart';
import 'overview_page.dart';
import 'upload_screen.dart';
import 'camera_page.dart';

class MainScreen extends StatefulWidget {
  final String username;
  final String email;
  final String colorHex;

  const MainScreen({
    super.key,
    required this.username,
    required this.email,
    required this.colorHex,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      Provider.of<AppState>(context, listen: false).loadLocations(widget.email);
    }
  });
}


  Color parseHexColor(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    return Color(int.parse('0x$hexColor'));
  }

  @override
  Widget build(BuildContext context) {
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
                  child: Consumer<AppState>(
                    builder: (context, appState, child) {
                      switch (appState.currentView) {
                        case AppView.home:
                          return const HomePage();
                        case AppView.overview:
                          return OverviewPage();
                        case AppView.permission:
                          return const PermissionPage();
                        case AppView.notification:
                          return const GenericScreen(
                            title: 'Notification',
                            icon: Icons.notifications,
                          );
                        case AppView.camera:
                          return const CameraPage();
                        case AppView.table:
                          return const GenericScreen(
                            title: 'Table',
                            icon: Icons.table_chart,
                          );
                        case AppView.uploadStickers:
                          return  UploadScreen();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
