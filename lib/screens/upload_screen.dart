import 'package:flutter/material.dart';
import '../models/sticker_model.dart';
import '../widgets/file_upload.dart';
import '../widgets/sticker_card.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool isUploading = false;

  List<StickerModel> models = [
    StickerModel(
      id: '1',
      name: 'Portrait Model v1',
      images: [
        'https://images.pexels.com/photos/1239291/pexels-photo-1239291.jpeg',
        'https://images.pexels.com/photos/1024384/pexels-photo-1024384.jpeg',
        'https://images.pexels.com/photos/1181519/pexels-photo-1181519.jpeg',
        'https://images.pexels.com/photos/1065084/pexels-photo-1065084.jpeg',
        'https://images.pexels.com/photos/1040881/pexels-photo-1040881.jpeg',
      ],
      isActive: true,
      uploadDate: DateTime(2024, 1, 15),
      status: StickerStatus.active,
    ),
    StickerModel(
      id: '2',
      name: 'Casual Style Model',
      images: [
        'https://images.pexels.com/photos/1559486/pexels-photo-1559486.jpeg',
        'https://images.pexels.com/photos/1559821/pexels-photo-1559821.jpeg',
        'https://images.pexels.com/photos/1559825/pexels-photo-1559825.jpeg',
        'https://images.pexels.com/photos/1559808/pexels-photo-1559808.jpeg',
        'https://images.pexels.com/photos/1559810/pexels-photo-1559810.jpeg',
      ],
      isActive: false,
      uploadDate: DateTime(2024, 1, 10),
      status: StickerStatus.inactive,
    ),
  ];

  StickerModel? get activeModel =>
      models.firstWhere((m) => m.isActive, orElse: () => models.first);
  List<StickerModel> get inactiveModels =>
      models.where((m) => !m.isActive).toList();

  // แก้ไข parameter type จาก List<File> เป็น List<FileWrapper>
  void handleUpload(List<FileWrapper> files) async {
    setState(() => isUploading = true);

    await Future.delayed(const Duration(seconds: 2));

    // สร้าง image paths จาก FileWrapper
    List<String> imagePaths = files.map((fileWrapper) {
      // สำหรับ web ใช้ name, สำหรับ mobile/desktop ใช้ path
      if (fileWrapper.isWeb) {
        return fileWrapper.name; // หรือจะใช้ ObjectURL หรือ base64
      } else {
        return fileWrapper.path ?? fileWrapper.name;
      }
    }).toList();

    final newModel = StickerModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'New Model ${DateTime.now().millisecondsSinceEpoch}',
      images: imagePaths,
      isActive: false,
      uploadDate: DateTime.now(),
      status: StickerStatus.processing,
    );

    setState(() {
      models = [
        newModel,
        ...models.map(
          (m) => m.copyWith(isActive: false, status: StickerStatus.inactive),
        ),
      ];
      isUploading = false;
    });
  }

  void handleActivate(String modelId) {
    setState(() {
      models = models.map((model) {
        final isActive = model.id == modelId;
        return model.copyWith(
          isActive: isActive,
          status: isActive ? StickerStatus.active : StickerStatus.inactive,
        );
      }).toList();
    });
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
            if (inactiveModels.isNotEmpty) _buildPreviousModelsSection(),
            const SizedBox(height: 32),
            LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  width: double.infinity,
                  child: FileUpload(onUpload: handleUpload, isUploading: isUploading),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveModelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text(
              'Currently Active Model',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        StickerCard(model: activeModel!, onActivate: () {}),
      ],
    );
  }

  Widget _buildPreviousModelsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Previous Models',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.5,
          ),
          itemCount: inactiveModels.length,
          itemBuilder: (context, index) {
            final model = inactiveModels[index];
            return StickerCard(
              model: model,
              onActivate: () => handleActivate(model.id),
            );
          },
        ),
      ],
    );
  }

}
