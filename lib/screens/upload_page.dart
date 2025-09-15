import 'package:flutter/material.dart';
import 'package:myproject/models/sticker_model.dart';
import 'package:myproject/widgets/manage_model/file_upload.dart';
import 'package:myproject/widgets/manage_model/sticker_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:collection/collection.dart';
import '../widgets/snackbar/fail_snackbar.dart';
import '../widgets/loading.dart';

class UploadPage extends StatefulWidget {
  final String locationId;
  const UploadPage({super.key, required this.locationId});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  bool isUploading = false;
  List<StickerModel> models = [];
  bool isLoading = true;

  StickerModel? get activeModel => models.firstWhereOrNull(
    (m) => m.isActive && m.status == StickerStatus.ready,
  );

  List<StickerModel> get inactiveModels =>
      models.where((m) => !m.isActive).toList();

  @override
  void initState() {
    super.initState();
    fetchStickerModels();
  }

  Future<void> fetchStickerModels() async {
    setState(() {
      isLoading = true;
    });

    final supabase = Supabase.instance.client;

    final response = await supabase
        .from('model')
        .select()
        .filter('location_id', 'eq', widget.locationId)
        .order('created_at', ascending: false);

    final List<StickerModel> fetched = (response as List<dynamic>)
        .map((e) => StickerModel.fromJson(e))
        .toList();

    setState(() {
      models = fetched;
      isLoading = false;
      debugPrint('📦 Models fetched in UploadPage: ${models.length}');
      for (final m in models) {
        debugPrint(
          '📦 Model: ${m.name},${m.id}, isActive: ${m.isActive}, status: ${m.status}',
        );
      }
    });
  }

  void handleActivate(String modelId) async {
    debugPrint('🧨 Deleting model_id: $modelId');
    final supabase = Supabase.instance.client;
    setState(() => isLoading = true);

    try {
      await supabase
          .from('model')
          .update({'is_active': false})
          .eq('location_id', widget.locationId);

      await supabase
          .from('model')
          .update({'is_active': true})
          .eq('id', modelId);

      await fetchStickerModels();
    } catch (e) {
      showFailMessage(context, 'Activate Model Failed', e.toString());
    } finally {
      setState(() => isLoading = false);
    }
  }

  showFailMessage(BuildContext context, String errorMessage, dynamic error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        duration: const Duration(seconds: 3),
        padding: EdgeInsets.zero,
        content: Align(
          alignment: Alignment.topRight,
          child: FailSnackbar(
            title: errorMessage,
            message: error,
            onClose: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      ),
    );
  }

  void handleDelete(String modelId) async {
    debugPrint("🧾 Sending delete request for modelId: $modelId");

    final supabase = Supabase.instance.client;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Model?'),
        content: const Text(
          'This action cannot be undone. Do you want to proceed?',
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

    if (confirm != true) return;

    final res = await supabase
      .from('model')
      .delete()
      .eq('model_id', modelId);
    debugPrint('🗑️ Delete result: $res');
    if (res == null || (res is List && res.isEmpty)) {
      debugPrint("❌ Nothing deleted — maybe wrong ID or permission issue?");
    }

    await fetchStickerModels();
  }

  void onUploadStart() {
    setState(() {
      isUploading = true;
    });
  }

  void onUploadComplete() async {
    setState(() {
      isUploading = false;
    });
    await fetchStickerModels();
  }

  void onUploadError() {
    setState(() {
      isUploading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: isLoading
                ? const SizedBox.shrink()
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          children: const [
                            Text(
                              'Manage Models',
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
                        if (activeModel != null) _buildActiveModelSection(),
                        if (inactiveModels.isNotEmpty) _buildAllModelsSection(),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return SizedBox(
                              width: double.infinity,
                              child: FileUpload(
                                isUploading: isUploading,
                                locationId: widget.locationId,
                                onUploadStart: onUploadStart,
                                onUploadComplete: onUploadComplete,
                                onUploadError: onUploadError,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        if (isLoading || isUploading) Loading(visible: true),
      ],
    );
  }

  Widget _buildActiveModelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          'Currently Active Model',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        StickerCard(
          model: activeModel!,
          onActivate: () {},
          onDelete: () => handleDelete(activeModel!.id),
        ),
      SizedBox(height: 32),
      ],
    );
  }

  Widget _buildAllModelsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'All Models',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            int getColumns() {
              if (inactiveModels.length == 1) return 1;
              if (constraints.maxWidth < 600) return 1;
              return 2;
            }

            final columns = getColumns();
            final spacing = 16.0;
            final totalSpacing = spacing * (columns - 1);
            final cardWidth = (constraints.maxWidth - totalSpacing) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: 16.0,
              children: inactiveModels.map((model) {
                return SizedBox(
                  width: cardWidth,
                  height: 320,
                  child: StickerCard(
                    model: model,
                    onActivate: () => handleActivate(model.id),
                    onDelete: () => handleDelete(model.id),
                  ),
                );
              }).toList(),
            );
          },
        ),
        SizedBox(height: 32),
      ],
    );
  }
}
