import 'package:flutter_web_app/features/dashboard/domain/entities/class_entity.dart';
import 'package:flutter_web_app/features/dashboard/domain/entities/coach.dart';
import 'package:flutter_web_app/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:flutter_web_app/features/dashboard/domain/entities/notification_item.dart';
import 'package:flutter_web_app/features/dashboard/domain/entities/student.dart';

abstract class DashboardRemoteDataSource {
  Future<DashboardStats> getDashboardStats();
  Future<List<NotificationItem>> getNotifications();
  Future<void> markNotificationAsRead(String id);
  
  // New methods
  Future<List<Student>> getStudents();
  Future<List<Coach>> getCoaches();
  Future<List<ClassEntity>> getClasses();
}