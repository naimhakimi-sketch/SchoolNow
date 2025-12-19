import 'boarding_status.dart';

class TripPassenger {
  final String studentId;
  final BoardingStatus status;
  final DateTime updatedAt;

  const TripPassenger({
    required this.studentId,
    required this.status,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'student_id': studentId,
        'status': BoardingStatusCodec.toJson(status),
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory TripPassenger.fromJson(Map<String, dynamic> json) {
    return TripPassenger(
      studentId: json['student_id'] as String,
      status: BoardingStatusCodec.fromJson(json['status'] as String),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
    );
  }
}
