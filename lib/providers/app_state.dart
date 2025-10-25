// lib/providers/app_state.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  String loggedInEmail = 'vdowduang@gmail.com';
  String? locationId;
  bool isAdmin = false;
  AppView get currentView => _currentView;
  Location? get selectedLocation => _selectedLocation;
  List<Location> get locations => _locations;
  static final String? baseUrl = dotenv.env['API_BASE_URL'];

  void setLoggedInEmail(String email) {
    loggedInEmail = email;
    notifyListeners();
  }

  Future<void> loadLocations(String email) async {
    final response = await http.get(
      Uri.parse('$baseUrl/get_locations?user=$email'),
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

  void selectLocation(Location location) {
    _selectedLocation = location;
    locationId = location.id;
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

  Future<void> loadMyRole() async {
    isAdmin = false;
    final supa = Supabase.instance.client;
    final uid = supa.auth.currentUser?.id;
    if (uid == null) {
      notifyListeners();
      return;
    }
    try {
      final r = await supa.rpc('is_admin');
      if (r is bool) {
        isAdmin = r;
      } else {
        final rows = await supa
            .from('users')
            .select('user_role')
            .eq('user_id', uid)
            .limit(1);
        final role = rows.isNotEmpty
            ? (rows.first['user_role'] as String?)
            : null;
        isAdmin = role == 'admin';
      }
    } catch (e) {
      debugPrint('⚠️ loadMyRole error: $e');
      isAdmin = false;
    }
    notifyListeners();
  }

  bool isOwnerWith(PermissionProvider perm) {
    if (isAdmin) return true;
    final id = locationId;
    if (id == null || id.isEmpty) return false;
    return perm.isOwner(id);
  }

  bool canEditWith(PermissionProvider perm) {
    if (isAdmin) return true;
    final id = locationId;
    if (id == null || id.isEmpty) return false;
    return perm.canEdit(id);
  }

  bool canViewWith(PermissionProvider perm) {
    if (isAdmin) return true;
    final id = locationId;
    if (id == null || id.isEmpty) return false;
    return perm.canView(id);
  }

  Future<void> signOutAndReset() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } finally {
      isAdmin = false;
      _selectedLocation = null;
      locationId = null;
      _currentView = AppView.home;
      notifyListeners();
    }
  }
}
