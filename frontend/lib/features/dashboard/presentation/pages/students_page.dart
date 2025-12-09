import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_web_app/core/di/injection.dart';
import 'package:flutter_web_app/features/dashboard/presentation/bloc/students/students_cubit.dart';
import 'package:flutter_web_app/features/dashboard/presentation/bloc/students/students_state.dart';
import 'package:flutter_web_app/features/dashboard/presentation/widgets/common/dashboard_table.dart';
import 'package:intl/intl.dart';

class StudentsPage extends StatelessWidget {
  const StudentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<StudentsCubit>()..loadStudents(),
      child: const _StudentsView(),
    );
  }
}

class _StudentsView extends StatelessWidget {
  const _StudentsView();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Students Management',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement add student
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Student'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        BlocBuilder<StudentsCubit, StudentsState>(
          builder: (context, state) {
            if (state is StudentsLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is StudentsError) {
              return Center(
                child: Text(
                  'Error: ${state.message}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            if (state is StudentsLoaded) {
              return DashboardTable(
                headers: const ['Name', 'Email', 'Grade', 'Join Date', 'Status'],
                columnWidths: const [2, 2.5, 1.5, 1.5, 1],
                rows: state.students.map((student) {
                  return [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          child: Text(student.firstName[0]),
                        ),
                        const SizedBox(width: 12),
                        Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                    Text(student.email),
                    Chip(
                      label: Text(
                        student.gradeLevel,
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                    ),
                    Text(DateFormat.yMMMd().format(student.joinDate)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: student.isActive
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: student.isActive ? Colors.green : Colors.red,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        student.isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: student.isActive ? Colors.green : Colors.red,
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