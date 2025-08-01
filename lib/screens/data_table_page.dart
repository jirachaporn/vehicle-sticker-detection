import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DataTablePage extends StatefulWidget {
   final String locationId;
  const DataTablePage({super.key, required this.locationId});

  @override
  State<DataTablePage> createState() => _DataTablePageState();
}

class _DataTablePageState extends State<DataTablePage> {
  final TextEditingController _searchController = TextEditingController();
  String selectedStatus = 'All';

  final List<Map<String, dynamic>> vehicles = [
    {
      "vehicleId": "VH-001",
      "license": "ABC-123",
      "type": "Sedan",
      "location": "Zone A - Gate 1",
      "status": "Active",
      "timestamp": DateTime.parse("2025-07-15 14:32:55"),
      "confidence": 95.8,
      "duration": "00:13:03",
      "imageUrl": "https://i.imgur.com/ZF6s192.jpg",
    },
    {
      "vehicleId": "VH-002",
      "license": "XYZ-789",
      "type": "SUV",
      "location": "Zone B - Parking",
      "status": "Parked",
      "timestamp": DateTime.parse("2025-07-15 14:28:05"),
      "confidence": 92.3,
      "duration": "00:46:55",
      "imageUrl": "https://i.imgur.com/G6YgG6Q.png",
    },
  ];

  List<Map<String, dynamic>> get filteredVehicles {
    return vehicles.where((v) {
      final query = _searchController.text.toLowerCase();
      final matchesSearch =
          v['license'].toLowerCase().contains(query) ||
          v['type'].toLowerCase().contains(query);

      final matchesStatus =
          selectedStatus == 'All' || v['status'] == selectedStatus;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: const [
                Text(
                  'Vehicle Table Data',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Spacer(),
                SizedBox(width: 56, height: 56),
              ],
            ),
            const SizedBox(height: 16),
            _buildFilters(),
            const SizedBox(height: 16),
            SizedBox(height: 500, child: _buildTable()),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black12,
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          flex: 6,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search License or Type',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 16),

        // 🔽 Dropdown
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 48,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade400),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedStatus,
                  borderRadius: BorderRadius.circular(12),
                  dropdownColor: Colors.white,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  items: ['All', 'Active', 'Parked', 'Exited'].map((s) {
                    return DropdownMenuItem(value: s, child: Text(s));
                  }).toList(),
                  onChanged: (value) => setState(() => selectedStatus = value!),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),

        // 📁 Export CSV Button
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text("Export CSV"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF11A64E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              // TODO: Add CSV export logic
            },
          ),
        ),
      ],
    ),
  );
}


  Widget _buildTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text("Vehicle ID")),
          DataColumn(label: Text("License Plate")),
          DataColumn(label: Text("Type")),
          DataColumn(label: Text("Location")),
          DataColumn(label: Text("Status")),
          DataColumn(label: Text("Timestamp")),
          DataColumn(label: Text("Confidence")),
          DataColumn(label: Text("Duration")),
          DataColumn(label: Text("Image")),
        ],
        rows: filteredVehicles.map((v) {
          return DataRow(
            cells: [
              DataCell(Text(v['vehicleId'])),
              DataCell(Text(v['license'])),
              DataCell(Text(v['type'])),
              DataCell(Text(v['location'])),
              DataCell(
                Text(
                  v['status'],
                  style: TextStyle(
                    color: v['status'] == "Active"
                        ? Colors.green
                        : (v['status'] == "Parked" ? Colors.blue : Colors.red),
                  ),
                ),
              ),
              DataCell(
                Text(DateFormat('yyyy-MM-dd – kk:mm').format(v['timestamp'])),
              ),
              DataCell(Text("${v['confidence']}%")),
              DataCell(Text(v['duration'])),
              DataCell(Image.network(v['imageUrl'], width: 60, height: 60)),
            ],
          );
        }).toList(),
      ),
    );
  }
}
