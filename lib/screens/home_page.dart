// import 'dart:convert';
import 'package:logger/logger.dart';

import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:myproject/models/location.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../widgets/location_card.dart';
import '../widgets/add_location_dialog.dart';
import '../widgets/responsive_grid.dart';
import '../widgets/loading.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final logger = Logger();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserLocations();
  }

  Future<void> _loadUserLocations() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final email = appState.loggedInEmail;

    setState(() => isLoading = true);

    try {
      await appState.loadLocations(email);
      logger.d('✅ Loaded locations for $email');
    } catch (e) {
      logger.d('🔥 Error loading locations: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showAddLocationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddLocationDialog(),
    );
  }

  @override
Widget build(BuildContext context) {
  return Stack(
    children: [
      Padding(
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
                      debugPrint('📌 Selected Location ID: ${location.id}');
                      appState.setLocationId(location.id);
                      appState.setView(AppView.uploadStickers);
                    },
                    cardBuilder: (location, onTap) =>
                        LocationCard(location: location, onTap: onTap),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      Loading(visible: isLoading),
    ],
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
                    ? const Color(0xFF0A46C9)
                    : const Color(0xFF2563EB),
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
