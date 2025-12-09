import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter_web_app/features/dashboard/domain/entities/coach.dart';
import 'package:flutter_web_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:flutter_web_app/features/dashboard/presentation/bloc/coaches/coaches_state.dart';

@injectable
class CoachesCubit extends Cubit<CoachesState> {
  final DashboardRepository _dashboardRepository;

  CoachesCubit(this._dashboardRepository) : super(CoachesInitial());

  Future<void> loadCoaches() async {
    emit(CoachesLoading());
    try {
      final coaches = await _dashboardRepository.getCoaches();
      emit(CoachesLoaded(coaches));
    } catch (e) {
      emit(CoachesError(e.toString()));
    }
  }
}
