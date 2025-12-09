import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter_web_app/features/dashboard/domain/entities/class_entity.dart';
import 'package:flutter_web_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:flutter_web_app/features/dashboard/presentation/bloc/classes/classes_state.dart';

@injectable
class ClassesCubit extends Cubit<ClassesState> {
  final DashboardRepository _dashboardRepository;

  ClassesCubit(this._dashboardRepository) : super(ClassesInitial());

  Future<void> loadClasses() async {
    emit(ClassesLoading());
    try {
      final classes = await _dashboardRepository.getClasses();
      emit(ClassesLoaded(classes));
    } catch (e) {
      emit(ClassesError(e.toString()));
    }
  }
}
