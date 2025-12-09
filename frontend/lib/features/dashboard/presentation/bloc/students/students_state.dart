import 'package:equatable/equatable.dart';
import 'package:flutter_web_app/features/dashboard/domain/entities/student.dart';

abstract class StudentsState extends Equatable {
  const StudentsState();

  @override
  List<Object> get props => [];
}

class StudentsInitial extends StudentsState {}

class StudentsLoading extends StudentsState {}

class StudentsLoaded extends StudentsState {
  final List<Student> students;

  const StudentsLoaded(this.students);

  @override
  List<Object> get props => [students];
}

class StudentsError extends StudentsState {
  final String message;

  const StudentsError(this.message);

  @override
  List<Object> get props => [message];
}
