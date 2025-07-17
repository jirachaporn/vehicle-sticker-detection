import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:myproject/models/location.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../widgets/location_card.dart';
import '../widgets/add_location_dialog.dart';
import '../widgets/responsive_grid.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _showAddLocationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddLocationDialog(),
    );
  }

  Future<List<Location>> fetchLocations() async {
    final response = await http.get(
      Uri.parse('http://127.0.0.1:5000/locations'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Location.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load locations');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'All Locations',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              _buildAnimatedFAB(context),
            ],
          ),
          const SizedBox(height: 48),
          Expanded(
            child: Consumer<AppState>(
              builder: (context, appState, child) {
                return LocationGridView(
                  locations: appState.locations,
                  onLocationTap: (location) {
                    appState.selectLocation(location);
                    // appState.setView(AppView.overview);
                    appState.setView(AppView.camera);

                  },
                  cardBuilder: (location, onTap) =>
                      LocationCard(location: location, onTap: onTap),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedFAB(BuildContext context) {
    bool isHovered = false;
    bool isPressed = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: GestureDetector(
            onTapDown: (_) => setState(() => isPressed = true),
            onTapUp: (_) {
              setState(() => isPressed = false);
              _showAddLocationDialog(context);
            },
            onTapCancel: () => setState(() => isPressed = false),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 150),
              scale: isPressed ? 0.95 : (isHovered ? 1.05 : 1.0),
              curve: Curves.easeInOut,
              child: FloatingActionButton(
                onPressed: () => _showAddLocationDialog(context),
                backgroundColor: isHovered
                    ? Color(0xFF0A46C9)
                    : Color(0xFF2563EB),
                elevation: 6,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ),
        );
      },
    );
  }
}
