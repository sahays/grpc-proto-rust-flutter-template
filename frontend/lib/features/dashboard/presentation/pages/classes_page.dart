import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_web_app/core/di/injection.dart';
import 'package:flutter_web_app/features/dashboard/presentation/bloc/classes/classes_cubit.dart';
import 'package:flutter_web_app/features/dashboard/presentation/bloc/classes/classes_state.dart';
import 'package:flutter_web_app/features/dashboard/presentation/widgets/common/dashboard_table.dart';

class ClassesPage extends StatelessWidget {
  const ClassesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<ClassesCubit>()..loadClasses(),
      child: const _ClassesView(),
    );
  }
}

class _ClassesView extends StatelessWidget {
  const _ClassesView();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Classes Management',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement add class
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Class'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        BlocBuilder<ClassesCubit, ClassesState>(
          builder: (context, state) {
            if (state is ClassesLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is ClassesError) {
              return Center(
                child: Text(
                  'Error: ${state.message}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            if (state is ClassesLoaded) {
              return DashboardTable(
                headers: const ['Class Name', 'Coach', 'Schedule', 'Enrolled', 'Status'],
                columnWidths: const [2, 2, 2, 1.5, 1],
                rows: state.classes.map((classEntity) {
                  final isFull = classEntity.isFull;
                  final enrollmentPercentage = classEntity.currentEnrollment / classEntity.maxCapacity;

                  return [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          classEntity.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          classEntity.description,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(classEntity.coachName),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(classEntity.schedule),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${classEntity.currentEnrollment}/${classEntity.maxCapacity}'),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: enrollmentPercentage,
                          color: isFull ? Colors.red : Colors.green,
                          backgroundColor: Colors.grey.withOpacity(0.2),
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isFull
                            ? Colors.red.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isFull ? Colors.red : Colors.green,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        isFull ? 'Full' : 'Open',
                        style: TextStyle(
                          color: isFull ? Colors.red : Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ];
                }).toList(),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}