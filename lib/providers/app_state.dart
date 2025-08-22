import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/location.dart';

enum AppView {
  home,
  overview,
  permission,
  notification,
  camera,
  table,
  uploadStickers,
}

class AppState extends ChangeNotifier {
  AppView _currentView = AppView.home;
  Location? _selectedLocation;
  List<Location> _locations = [];

  // ลบออกก่อน deploy production
  String loggedInEmail = 'vdowduang@gmail.com';
  String? locationId;

  AppView get currentView => _currentView;
  Location? get selectedLocation => _selectedLocation;
  List<Location> get locations => _locations;

  void setLoggedInEmail(String email) {
    loggedInEmail = email;
    notifyListeners();
  }

  Future<void> loadLocations(String email) async {
    final response = await http.get(
      Uri.parse('http://127.0.0.1:5000/locations?user=$email'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      _locations = data
        .map((json) => Location
        .fromJson(json))
        .toList()
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

  void selectLocation(Location location) {
    _selectedLocation = location;
    _currentView = AppView.overview;
    notifyListeners();
  }

  void backToHome() {
    _selectedLocation = null;
    _currentView = AppView.home;
    notifyListeners();
  }

  void addLocation(Location location) {
    _locations.add(location);
    notifyListeners();
  }


  /// ✅ ตรวจสอบว่า logged-in user เป็น owner ของ selected location
  bool isOwner() {
    final userEmail = loggedInEmail;
    final location = _selectedLocation;
    if (location == null || userEmail.isEmpty) return false;

    return location.ownerEmail == userEmail;
  }

  /// ✅ ตรวจสอบว่า logged-in user มีสิทธิ์ "edit" (หรือเป็น owner)
  bool hasEditPermission() {
    final userEmail = loggedInEmail;
    final location = _selectedLocation;

    if (location == null || userEmail.isEmpty) return false;

    if (location.ownerEmail == userEmail) return true;

    final sharedWith = location.sharedWith;
    return sharedWith.any(
      (item) => item['email'] == userEmail && item['permission'] == 'edit',
    );
  
  }
}
