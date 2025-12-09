import 'package:equatable/equatable.dart';

class Coach extends Equatable {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String specialization; // e.g., "Tennis", "Swimming"
  final DateTime joinDate;
  final bool isActive;

  const Coach({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.specialization,
    required this.joinDate,
    required this.isActive,
  });

  String get fullName => '$firstName $lastName';

  @override
  List<Object?> get props => [
        id,
        firstName,
        lastName,
        email,
        specialization,
        joinDate,
        isActive,
      ];
}
