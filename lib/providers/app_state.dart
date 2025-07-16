import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/location.dart';
import '../models/user.dart';

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
  String loggedInEmail = '';

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
      _locations = data.map((json) => Location.fromJson(json)).toList();
      notifyListeners();
    } else {
      throw Exception('Failed to load locations');
    }
  }

  final List<User> _users = [
    User(
      id: '1',
      name: 'Jirachaporn P.',
      email: 'pam@example.com',
      role: UserRole.admin,
      permissions: [],
      lastLogin: '2024-01-15 14:30',
    ),
    User(
      id: '2',
      name: 'Somchai Manager',
      email: 'somchai@example.com',
      role: UserRole.manager,
      permissions: [],
      lastLogin: '2024-01-15 10:15',
    ),
    User(
      id: '3',
      name: 'Malee Viewer',
      email: 'malee@example.com',
      role: UserRole.viewer,
      permissions: [],
      lastLogin: '2024-01-14 16:45',
    ),
  ];

  AppView get currentView => _currentView;
  Location? get selectedLocation => _selectedLocation;
  List<Location> get locations => _locations;
  List<User> get users => _users;

  void setView(AppView view) {
    _currentView = view;
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

  void addUser(User user) {
    _users.add(user);
    notifyListeners();
  }

  void updateUser(User updatedUser) {
    final index = _users.indexWhere((user) => user.id == updatedUser.id);
    if (index != -1) {
      _users[index] = updatedUser;
      notifyListeners();
    }
  }
}
