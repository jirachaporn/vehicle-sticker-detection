// lib/models/license_plate_model.dart

class LicensePlate {
  // ทำให้ licenseId เป็น nullable เพราะตอนสร้างใหม่ยังไม่มีค่า (ให้ DB สร้าง)
  final String? licenseId;
  final String locationLicense;
  final String licenseText;
  final String licenseLocal;
  final String carOwner;
  final String? note;

  // ctor หลัก (เรียบง่าย)
  const LicensePlate({
    required this.licenseId,
    required this.locationLicense,
    required this.licenseText,
    required this.licenseLocal,
    required this.carOwner,
    this.note,
  });

  // แปลงจาก Map (เช่นผลลัพธ์จาก Supabase)
  factory LicensePlate.fromMap(Map<String, dynamic> map) {
    return LicensePlate(
      licenseId: map['license_id'] == null || '${map['license_id']}'.isEmpty
          ? null
          : '${map['license_id']}',
      locationLicense: (map['location_license'] ?? '') as String,
      licenseText: (map['license_text'] ?? '') as String,
      licenseLocal: (map['license_local'] ?? '') as String,
      carOwner: (map['car_owner'] ?? '') as String,
      note: map['note'] as String?,
    );
  }

  // สำหรับแปลงกลับไปเป็น Map (ทั่วไป)
  Map<String, dynamic> toMap() {
    return {
      'license_id': licenseId,
      'location_license': locationLicense,
      'license_text': licenseText,
      'license_local': licenseLocal,
      'car_owner': carOwner,
      'note': note,
    };
  }

  // ใช้สำหรับ insert/upsert
  Map<String, dynamic> toInsertMap() {
    final m = <String, dynamic>{
      'location_license': locationLicense,
      'license_text': licenseText,
      'license_local': licenseLocal,
      'car_owner': carOwner,
      'note': note,
    };
    if (licenseId != null && licenseId!.isNotEmpty) {
      m['license_id'] = licenseId;
    }
    return m;
  }

  // แก้บางฟิลด์แบบง่าย
  LicensePlate copyWith({
    String? licenseId,
    String? locationLicense,
    String? licenseText,
    String? licenseLocal,
    String? carOwner,
    String? note,
  }) {
    return LicensePlate(
      licenseId: licenseId ?? this.licenseId,
      locationLicense: locationLicense ?? this.locationLicense,
      licenseText: licenseText ?? this.licenseText,
      licenseLocal: licenseLocal ?? this.licenseLocal,
      carOwner: carOwner ?? this.carOwner,
      note: note ?? this.note,
    );
  }

  @override
  String toString() =>
      'LicensePlate(id: $licenseId, text: $licenseText, local: $licenseLocal, owner: $carOwner)';

  // เทียบแบบง่าย: ถ้ามี id ให้เทียบ id, ถ้าไม่มีให้เทียบฟิลด์หลักๆ
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LicensePlate) return false;
    if (licenseId != null && other.licenseId != null) {
      return licenseId == other.licenseId;
    }
    return locationLicense == other.locationLicense &&
        licenseText == other.licenseText &&
        licenseLocal == other.licenseLocal &&
        carOwner == other.carOwner &&
        note == other.note;
  }

  @override
  int get hashCode => Object.hash(
        licenseId,
        locationLicense,
        licenseText,
        licenseLocal,
        carOwner,
        note,
      );
}
