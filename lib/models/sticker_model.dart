enum StickerStatus { processing, ready, failed }

StickerStatus parseStatus(String? status) {
  switch (status?.toLowerCase()) {
    case 'ready':
      return StickerStatus.ready;
    case 'failed':
      return StickerStatus.failed;
    case 'processing':
    default:
      return StickerStatus.processing;
  }
}

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

  factory StickerModel.fromJson(Map<String, dynamic> json) {
    final List<String> imageList = (json['image_urls'] as List<dynamic>?)
            ?.map((item) => item.toString())
            .toList() ??
        [];

    return StickerModel(
      id: json['model_id'] as String,
      name: json['model_name'] as String,
      images: imageList,
      isActive: json['is_active'] as bool,
      uploadDate: DateTime.parse(json['created_at']),
      status: parseStatus(json['sticker_status']),
    );
  }

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
