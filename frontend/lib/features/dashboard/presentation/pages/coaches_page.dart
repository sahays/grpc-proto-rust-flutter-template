import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_web_app/core/di/injection.dart';
import 'package:flutter_web_app/features/dashboard/presentation/bloc/coaches/coaches_cubit.dart';
import 'package:flutter_web_app/features/dashboard/presentation/bloc/coaches/coaches_state.dart';
import 'package:flutter_web_app/features/dashboard/presentation/widgets/common/dashboard_table.dart';
import 'package:intl/intl.dart';

class CoachesPage extends StatelessWidget {
  const CoachesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<CoachesCubit>()..loadCoaches(),
      child: const _CoachesView(),
    );
  }
}

class _CoachesView extends StatelessWidget {
  const _CoachesView();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Coaches Management',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement add coach
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Coach'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        BlocBuilder<CoachesCubit, CoachesState>(
          builder: (context, state) {
            if (state is CoachesLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is CoachesError) {
              return Center(
                child: Text(
                  'Error: ${state.message}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            if (state is CoachesLoaded) {
              return DashboardTable(
                headers: const ['Name', 'Email', 'Specialization', 'Join Date', 'Status'],
                columnWidths: const [2, 2.5, 1.5, 1.5, 1],
                rows: state.coaches.map((coach) {
                  return [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          child: Text(coach.firstName[0]),
                        ),
                        const SizedBox(width: 12),
                        Text(coach.fullName, style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                    Text(coach.email),
                    Chip(
                      label: Text(
                        coach.specialization,
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
                    ),
                    Text(DateFormat.yMMMd().format(coach.joinDate)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: coach.isActive
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: coach.isActive ? Colors.green : Colors.red,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        coach.isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: coach.isActive ? Colors.green : Colors.red,
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