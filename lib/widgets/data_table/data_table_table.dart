import 'package:flutter/material.dart';

class DataTableContent extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final ScrollController controller;
  final void Function(String?) onViewImage;

  const DataTableContent({
    super.key,
    required this.data,
    required this.controller,
    required this.onViewImage,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('No records'));

    return Scrollbar(
      thumbVisibility: true,
      controller: controller,
      child: SingleChildScrollView(
        controller: controller,
        child: DataTable(
          columnSpacing: 22,
          headingRowHeight: 44,
          dataRowMinHeight: 48,
          dividerThickness: 0.6,
          columns: const [
            DataColumn(label: Text("VEHICLE ID")),
            DataColumn(label: Text("LICENSE PLATE")),
            DataColumn(label: Text("TYPE")),
            DataColumn(label: Text("STATUS")),
            DataColumn(label: Text("TIMESTAMP")),
            DataColumn(label: Text("CONFIDENCE")),
            DataColumn(label: Text("IMAGE")),
          ],
          rows: data.map((d) {
            return DataRow(
              cells: [
                DataCell(Text(d['vehId'] ?? '-')),
                DataCell(Text(d['lp'] ?? '-')),
                DataCell(Text(d['bodyType'] ?? '-')),
                DataCell(d['statusChip'] ?? const SizedBox()),
                DataCell(Text(d['ts'] ?? '-')),
                DataCell(Text(d['conf'] ?? '-')),
                DataCell(
                  IconButton(
                    tooltip: 'View image',
                    icon: const Icon(Icons.remove_red_eye_outlined),
                    onPressed: () => onViewImage(d['imgUrl']),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
