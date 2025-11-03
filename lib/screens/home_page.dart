// import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:myproject/models/location.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../widgets/location/location_card.dart';
import '../widgets/location/add_location_dialog.dart';
import '../widgets/loading.dart';
import '../widgets/location/license/add_license_dialog.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../providers/snackbar_func.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isLoading = true;
  String _searchQuery = '';
  bool _sortDescending = true;
  static final String? baseUrl = dotenv.env['API_BASE_URL'];

  @override
  void initState() {
    super.initState();
    loadUserLocations();
  }

  Future<void> loadUserLocations() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final email = appState.loggedInEmail;

    setState(() => isLoading = true);

    try {
      await appState.loadLocations(email);
      debugPrint('Loaded locations for $email');
    } catch (e) {
      debugPrint('Error loading locations: $e');
      showFailMessage(context, 'Error', 'Fail loading locations.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> showAddLocationDialog(BuildContext context) async {
    // 1) เปิด dialog แรกด้วย root navigator เสมอ
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const AddLocationDialog(),
    );

    // 2) ได้ผลลัพธ์แล้ว ค่อยเปิด dialog ที่สอง จาก context ของหน้าแม่ (ยังมี Overlay อยู่)
    if (result?['ok'] == true && context.mounted) {
      await Future.delayed(Duration.zero);

      await showDialog(
        context: Navigator.of(context, rootNavigator: true).context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => AddLicenseDialog(
          locationLicense: result!['locationLicense'] as String?,
          isEdit: false,
          locationData: null,
          initialLocation: null,
        ),
      );
    }
  }

  void showEditDialog(Location location) {
    showDialog(
      context: context,
      builder: (_) => AddLocationDialog(initialLocation: location),
    );
  }

  void confirmDelete(Location location) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Location?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${location.name}"?\nThis action cannot be undone.',
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              side: const BorderSide(color: Colors.grey),
              foregroundColor: Colors.black,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete, size: 16),
                SizedBox(width: 8),
                Text('Delete'),
              ],
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final response = await http.delete(
        Uri.parse('$baseUrl/delete_location/${location.id}'),
      );

      if (!mounted) return;

      final appState = context.read<AppState>();

      if (response.statusCode == 200) {
        await appState.loadLocations(appState.loggedInEmail);
        showSuccessMessage(context, 'Deleted "${location.name}" successfully!');
      } else {
        showFailMessage(
          context,
          'Error',
          'Failed to delete "${location.name}"',
        );
      }
    }
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
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(
                  left: 30,
                  right: 30,
                  bottom: 16,
                  top: 8,
                ),
                child: Row(
                  children: [
                    // Search Box
                    Expanded(
                      flex: 9,
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Search locations',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(
                              color: Color(0xFF2563EB),
                              width: 1.5,
                            ),
                          ),
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Sort Dropdown
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<bool>(
                        value: _sortDescending,
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.black54,
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Sort by',
                          labelStyle: const TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.grey.shade400,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF2563EB),
                              width: 2,
                            ),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: true, child: Text('Newest')),
                          DropdownMenuItem(value: false, child: Text('Oldest')),
                        ],
                        onChanged: (v) => setState(() => _sortDescending = v!),
                      ),
                    ),
                  ],
                ),
              ),

              // แสดงข้อความเมื่อไม่มีสถานที่
              Expanded(
                child: Consumer<AppState>(
                  builder: (context, appState, child) {
                    var filtered = appState.locations
                        .where(
                          (loc) => loc.name.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ),
                        )
                        .toList();

                    filtered.sort(
                      (a, b) => _sortDescending
                          ? b.createdAt.compareTo(a.createdAt)
                          : a.createdAt.compareTo(b.createdAt),
                    );

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          'No location. Please add a location.',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 400,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: 250,
                          ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final location = filtered[index];
                        return LocationCard(
                          location: location,
                          loggedInEmail: appState.loggedInEmail,
                          onTap: () {
                            appState.selectLocation(location);
                            appState.setView(AppView.overview);
                          },
                          onEdit: () => showEditDialog(location),
                          onDelete: () => confirmDelete(location),
                        );
                      },
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
              showAddLocationDialog(context);
            },
            onTapCancel: () => setState(() => isPressed = false),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 150),
              scale: isPressed ? 0.95 : (isHovered ? 1.05 : 1.0),
              curve: Curves.easeInOut,
              child: FloatingActionButton(
                onPressed: () => showAddLocationDialog(context),
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
