import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter_web_app/features/dashboard/data/datasources/dashboard_remote_datasource.dart';
import 'package:flutter_web_app/features/dashboard/domain/entities/class_entity.dart';
import 'package:flutter_web_app/features/dashboard/domain/entities/coach.dart';
import 'package:flutter_web_app/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:flutter_web_app/features/dashboard/domain/entities/notification_item.dart';
import 'package:flutter_web_app/features/dashboard/domain/entities/student.dart';

@LazySingleton(as: DashboardRemoteDataSource)
class DashboardMockDataSource implements DashboardRemoteDataSource {
  final List<NotificationItem> _notifications = [
    NotificationItem(
      id: '1',
      title: 'New student registration: Emily Chen',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      isRead: false,
      type: NotificationType.enrollment,
    ),
    NotificationItem(
      id: '2',
      title: 'Class cancellation: Swimming 101',
      description: 'Pool maintenance scheduled',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      isRead: false,
      type: NotificationType.classCancellation,
    ),
    NotificationItem(
      id: '3',
      title: 'Payment received from Michael Torres',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      isRead: true,
      type: NotificationType.payment,
    ),
    NotificationItem(
      id: '4',
      title: 'Coach David requested time off',
      description: 'December 20-22, 2025',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      isRead: true,
      type: NotificationType.timeOff,
    ),
    NotificationItem(
      id: '5',
      title: 'Equipment delivery scheduled for tomorrow',
      description: 'New basketball hoops arriving at 10 AM',
      timestamp: DateTime.now().subtract(const Duration(hours: 8)),
      isRead: true,
      type: NotificationType.delivery,
    ),
  ];

  @override
  Future<DashboardStats> getDashboardStats() async {
    await Future.delayed(const Duration(milliseconds: 500));

    return DashboardStats(
      totalStudents: 247,
      activeCoaches: 18,
      classesThisWeek: 42,
      attendanceRate: 87.5,
      recentActivities: [
        RecentActivity(
          id: '1',
          title: 'John Doe enrolled in Tennis Basics',
          timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
          icon: Icons.person_add,
        ),
        RecentActivity(
          id: '2',
          title: 'Coach Sarah updated Soccer Advanced schedule',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          icon: Icons.calendar_today,
        ),
        RecentActivity(
          id: '3',
          title: 'Basketball Court A maintenance completed',
          timestamp: DateTime.now().subtract(const Duration(hours: 4)),
          icon: Icons.check_circle,
        ),
        RecentActivity(
          id: '4',
          title: 'New payment received from Emily Chen',
          timestamp: DateTime.now().subtract(const Duration(hours: 6)),
          icon: Icons.payment,
        ),
        RecentActivity(
          id: '5',
          title: 'Swimming pool inspection scheduled',
          timestamp: DateTime.now().subtract(const Duration(hours: 8)),
          icon: Icons.event,
        ),
      ],
    );
  }

  @override
  Future<List<NotificationItem>> getNotifications() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.from(_notifications);
  }

  @override
  Future<void> markNotificationAsRead(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
    }
  }

  @override
  Future<List<Student>> getStudents() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return [
      Student(
        id: '1',
        firstName: 'Emily',
        lastName: 'Chen',
        email: 'emily.chen@example.com',
        gradeLevel: 'Intermediate',
        joinDate: DateTime(2023, 9, 15),
        isActive: true,
      ),
      Student(
        id: '2',
        firstName: 'Michael',
        lastName: 'Torres',
        email: 'michael.t@example.com',
        gradeLevel: 'Advanced',
        joinDate: DateTime(2023, 8, 20),
        isActive: true,
      ),
      Student(
        id: '3',
        firstName: 'Sarah',
        lastName: 'Johnson',
        email: 'sarah.j@example.com',
        gradeLevel: 'Beginner',
        joinDate: DateTime(2024, 1, 10),
        isActive: true,
      ),
      Student(
        id: '4',
        firstName: 'David',
        lastName: 'Smith',
        email: 'david.smith@example.com',
        gradeLevel: 'Beginner',
        joinDate: DateTime(2024, 2, 1),
        isActive: false,
      ),
      Student(
        id: '5',
        firstName: 'Jessica',
        lastName: 'Wong',
        email: 'jessica.w@example.com',
        gradeLevel: 'Intermediate',
        joinDate: DateTime(2023, 11, 5),
        isActive: true,
      ),
    ];
  }

  @override
  Future<List<Coach>> getCoaches() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return [
      Coach(
        id: '1',
        firstName: 'John',
        lastName: 'Doe',
        email: 'john.doe@academy.com',
        specialization: 'Tennis',
        joinDate: DateTime(2022, 5, 10),
        isActive: true,
      ),
      Coach(
        id: '2',
        firstName: 'Jane',
        lastName: 'Smith',
        email: 'jane.smith@academy.com',
        specialization: 'Swimming',
        joinDate: DateTime(2021, 3, 15),
        isActive: true,
      ),
      Coach(
        id: '3',
        firstName: 'Robert',
        lastName: 'Brown',
        email: 'robert.b@academy.com',
        specialization: 'Basketball',
        joinDate: DateTime(2023, 1, 20),
        isActive: true,
      ),
       Coach(
        id: '4',
        firstName: 'Alice',
        lastName: 'Davis',
        email: 'alice.d@academy.com',
        specialization: 'Gymnastics',
        joinDate: DateTime(2023, 6, 1),
        isActive: false,
      ),
    ];
  }

  @override
  Future<List<ClassEntity>> getClasses() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return [
      const ClassEntity(
        id: '1',
        name: 'Tennis Basics',
        description: 'Introduction to tennis for beginners',
        coachId: '1',
        coachName: 'John Doe',
        schedule: 'Mon, Wed 10:00 AM',
        maxCapacity: 10,
        currentEnrollment: 8,
      ),
      const ClassEntity(
        id: '2',
        name: 'Swimming 101',
        description: 'Learn to swim with confidence',
        coachId: '2',
        coachName: 'Jane Smith',
        schedule: 'Tue, Thu 2:00 PM',
        maxCapacity: 12,
        currentEnrollment: 12,
      ),
      const ClassEntity(
        id: '3',
        name: 'Advanced Basketball',
        description: 'Competitive basketball training',
        coachId: '3',
        coachName: 'Robert Brown',
        schedule: 'Fri 4:00 PM',
        maxCapacity: 15,
        currentEnrollment: 10,
      ),
       const ClassEntity(
        id: '4',
        name: 'Gymnastics for Kids',
        description: 'Fun gymnastics exercises for children',
        coachId: '4',
        coachName: 'Alice Davis',
        schedule: 'Sat 10:00 AM',
        maxCapacity: 8,
        currentEnrollment: 5,
      ),
    ];
  }
}