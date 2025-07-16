enum StickerStatus { active, inactive, processing }

class StickerModel {
  final String id;
  final String name;
  final List<String> images;
  final bool isActive;
  final DateTime uploadDate;
  final StickerStatus status;

  StickerModel({
    required this.id,
    required this.name,
    required this.images,
    required this.isActive,
    required this.uploadDate,
    required this.status,
  });

  StickerModel copyWith({
    String? id,
    String? name,
    List<String>? images,
    bool? isActive,
    DateTime? uploadDate,
    StickerStatus? status,
  }) {
    return StickerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      images: images ?? this.images,
      isActive: isActive ?? this.isActive,
      uploadDate: uploadDate ?? this.uploadDate,
      status: status ?? this.status,
    );
  }
}