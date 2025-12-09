import 'package:equatable/equatable.dart';

class ClassEntity extends Equatable {
  final String id;
  final String name;
  final String description;
  final String coachId;
  final String coachName;
  final String schedule; // e.g., "Mon, Wed 10:00 AM"
  final int maxCapacity;
  final int currentEnrollment;

  const ClassEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.coachId,
    required this.coachName,
    required this.schedule,
    required this.maxCapacity,
    required this.currentEnrollment,
  });

  bool get isFull => currentEnrollment >= maxCapacity;

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        coachId,
        coachName,
        schedule,
        maxCapacity,
        currentEnrollment,
      ];
}
