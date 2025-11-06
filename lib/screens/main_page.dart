import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:myproject/widgets/top_header.dart';
import '../providers/app_state.dart';
import '../widgets/sidebar/sidebar.dart';
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
import '../providers/camera_manager.dart';

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
  State<MainPage> createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  String? _previousLocationId;
  late VoidCallback _appStateListener;
  AppState? _appState;
  CameraManager? _cameraManager;
  PermissionProvider? _permissionProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState ??= context.read<AppState>();
    _cameraManager ??= context.read<CameraManager>();
    _permissionProvider ??= context.read<PermissionProvider>();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // โหลด locations
        await _appState!.loadLocations(widget.email);

        if (mounted && _appState!.locations.isNotEmpty) {
          // โหลดสมาชิก
          await _permissionProvider!.loadMembers(_appState!.locations.first.id);
        }

        // สร้าง listener
        _appStateListener = () async {
          final selected = _appState!.selectedLocation;
          if (selected?.id == _previousLocationId) return;
          _previousLocationId = selected?.id;

          if (selected != null) {
            final modelId = _appState!.getActiveModelFor(selected.id);

            try {
              final cameras = await availableCameras();

              await _cameraManager!.stopDetection();
              await Future.delayed(const Duration(milliseconds: 150));

              await _cameraManager!.init(cameras);

              _cameraManager!.updateLocationAndModel(
                location: selected.id,
                model: modelId,
              );

              _cameraManager!.startDetection();
            } catch (e) {
              debugPrint('Error initializing camera: $e');
            }
          } else {
            await _cameraManager!.stopDetection();
          }
        };

        // เพิ่ม listener
        _appState!.addListener(_appStateListener);
      } catch (e) {
        debugPrint('Error initializing MainPage: $e');
      }
    });
  }

  @override
  void dispose() {
    _appState?.removeListener(_appStateListener);
    super.dispose();
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
                        final locId = appState.locationId ?? '';
                        return Provider<ApiService>.value(
                          value: context.read<ApiService>(),
                          child: CameraPage(locationId: locId),
                        );
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
                      default:
                        return const Center(child: Text('Unknown view'));
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
