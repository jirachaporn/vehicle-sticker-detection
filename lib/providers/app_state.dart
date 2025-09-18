import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/location.dart';
import 'permission_provider.dart'; 

enum AppView {
  home,
  overview,
  permission,
  notification,
  camera,
  table,
  managemodels,
  annotation,
}

class AppState extends ChangeNotifier {
  AppView _currentView = AppView.home;
  Location? _selectedLocation;
  List<Location> _locations = [];

  // NOTE: dev only (อย่าลืมลบเมื่อขึ้น prod)
  String loggedInEmail = 'vdowduang@gmail.com';

  /// ใช้คู่กับ PermissionProvider เพื่อเช็คสิทธิ์
  String? locationId;

  AppView get currentView => _currentView;
  Location? get selectedLocation => _selectedLocation;
  List<Location> get locations => _locations;

  void setLoggedInEmail(String email) {
    loggedInEmail = email;
    notifyListeners();
  }

  /// โหลดรายการสถานที่ที่ผู้ใช้งาน “มีสิทธิ์” จาก backend (ผ่าน location_members)
  Future<void> loadLocations(String email) async {
    final response = await http.get(
      Uri.parse('http://127.0.0.1:5000/locations?user=$email'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      _locations = data.map((json) => Location.fromJson(json)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    } else {
      throw Exception('Failed to load locations');
    }
  }

  void setView(AppView view) {
    _currentView = view;
    notifyListeners();
  }

  void setLocationId(String id) {
    locationId = id;
    debugPrint('✅ AppState >> locationId set to: $locationId');
    notifyListeners();
  }

  /// เลือกการ์ดสถานที่จากหน้า Home
  void selectLocation(Location location) {
    _selectedLocation = location;
    locationId = location.id; // ✅ ผูกกับ id สำหรับ PermissionProvider
    _currentView = AppView.overview;
    notifyListeners();
  }

  void backToHome() {
    _selectedLocation = null;
    locationId = null;
    _currentView = AppView.home;
    notifyListeners();
  }

  void addLocation(Location location) {
    _locations.add(location);
    notifyListeners();
  }

  bool isOwnerWith(PermissionProvider perm) {
    final id = locationId;
    if (id == null || id.isEmpty) return false;
    return perm.isOwner(id);
  }

  bool canEditWith(PermissionProvider perm) {
    final id = locationId;
    if (id == null || id.isEmpty) return false;
    return perm.canEdit(id);
  }

  bool canViewWith(PermissionProvider perm) {
    final id = locationId;
    if (id == null || id.isEmpty) return false;
    return perm.canView(id);
  }
}
