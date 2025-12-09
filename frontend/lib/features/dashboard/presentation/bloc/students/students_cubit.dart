import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter_web_app/features/dashboard/domain/entities/student.dart';
import 'package:flutter_web_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:flutter_web_app/features/dashboard/presentation/bloc/students/students_state.dart';

@injectable
class StudentsCubit extends Cubit<StudentsState> {
  final DashboardRepository _dashboardRepository;

  StudentsCubit(this._dashboardRepository) : super(StudentsInitial());

  Future<void> loadStudents() async {
    emit(StudentsLoading());
    try {
      final students = await _dashboardRepository.getStudents();
      emit(StudentsLoaded(students));
    } catch (e) {
      emit(StudentsError(e.toString()));
    }
  }
}
