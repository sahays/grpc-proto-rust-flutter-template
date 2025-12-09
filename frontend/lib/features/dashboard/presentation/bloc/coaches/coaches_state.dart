import 'package:equatable/equatable.dart';
import 'package:flutter_web_app/features/dashboard/domain/entities/coach.dart';

abstract class CoachesState extends Equatable {
  const CoachesState();

  @override
  List<Object> get props => [];
}

class CoachesInitial extends CoachesState {}

class CoachesLoading extends CoachesState {}

class CoachesLoaded extends CoachesState {
  final List<Coach> coaches;

  const CoachesLoaded(this.coaches);

  @override
  List<Object> get props => [coaches];
}

class CoachesError extends CoachesState {
  final String message;

  const CoachesError(this.message);

  @override
  List<Object> get props => [message];
}
