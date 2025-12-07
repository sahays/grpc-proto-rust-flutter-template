import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_web_app/features/auth/presentation/pages/login_page.dart';
import 'package:flutter_web_app/features/auth/presentation/pages/register_page.dart';
import 'package:flutter_web_app/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:flutter_web_app/features/auth/presentation/pages/reset_password_page.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const LoginPage(),
        ),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const RegisterPage(),
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const ForgotPasswordPage(),
        ),
      ),
      GoRoute(
        path: '/reset-password',
        name: 'reset-password',
        pageBuilder: (context, state) {
          final token = state.uri.queryParameters['token'] ?? '';
          return MaterialPage(
            key: state.pageKey,
            child: ResetPasswordPage(token: token),
          );
        },
      ),
      // GoRoute(
      //   path: '/dashboard',
      //   name: 'dashboard',
      //   pageBuilder: (context, state) => MaterialPage(
      //     key: state.pageKey,
      //     child: const DashboardPage(),
      //   ),
      // ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.matchedLocation}'),
      ),
    ),
  );
}
