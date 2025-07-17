class BoundingBox {
  final double x;
  final double y;
  final double width;
  final double height;

  BoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    return BoundingBox(
      x: json['x'].toDouble(),
      y: json['y'].toDouble(),
      width: json['width'].toDouble(),
      height: json['height'].toDouble(),
    );
  }
}

class DetectionResult {
  final String className;
  final double confidence;
  final BoundingBox boundingBox;
  final DateTime timestamp;

  DetectionResult({
    required this.className,
    required this.confidence,
    required this.boundingBox,
    required this.timestamp,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    return DetectionResult(
      className: json['class_name'],
      confidence: json['confidence'].toDouble(),
      boundingBox: BoundingBox.fromJson(json['bounding_box']),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
