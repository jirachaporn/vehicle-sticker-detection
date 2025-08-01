import 'package:flutter/material.dart';
import 'package:myproject/models/sticker_model.dart';
import 'package:myproject/widgets/file_upload.dart';
import 'package:myproject/widgets/sticker_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:collection/collection.dart';
import '../widgets/loading.dart';

class UploadScreen extends StatefulWidget {
  final String locationId;
  const UploadScreen({super.key, required this.locationId});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
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
        .from('stickers')
        .select()
        // .filter('location_id', 'eq', widget.locationId)
        .order('created_at', ascending: false);

    debugPrint('📥 Supabase raw response: $response');

    final List<StickerModel> fetched = (response as List<dynamic>)
        .map((e) => StickerModel.fromJson(e))
        .toList();

    setState(() {
      models = fetched;
      isLoading = false;
      debugPrint('📦 Models fetched in UploadScreen: ${models.length}');
      for (final m in models) {
        debugPrint(
          '📦 Model: ${m.name}, isActive: ${m.isActive}, status: ${m.status}',
        );
      }
    });
  }

  void handleActivate(String modelId) {
    setState(() {
      models = models.map((model) {
        final isActive = model.id == modelId;
        return model.copyWith(isActive: isActive);
      }).toList();
    });

    // TODO: อัปเดตค่า is_active ใน Supabase ด้วยถ้าต้องการ
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
                              'Upload Stickers',
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
                        const SizedBox(height: 24),
                        if (activeModel != null) _buildActiveModelSection(),
                        const SizedBox(height: 32),
                        if (inactiveModels.isNotEmpty) _buildAllModelsSection(),
                        const SizedBox(height: 32),
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
        Positioned.fill(child: Loading(visible: isLoading || isUploading)),
      ],
    );
  }

  Widget _buildActiveModelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Currently Active Model',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        StickerCard(model: activeModel!, onActivate: () {}),
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
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
