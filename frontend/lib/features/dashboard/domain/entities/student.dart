import 'package:equatable/equatable.dart';

class Student extends Equatable {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String gradeLevel; // e.g., "Beginner", "Intermediate"
  final DateTime joinDate;
  final bool isActive;

  const Student({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.gradeLevel,
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
        gradeLevel,
        joinDate,
        isActive,
      ];
}
