import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/bootstrap/bootstrap_provider.dart';
import '../../core/bootstrap/device_bootstrap.dart';
import '../../core/config/env.dart';
import '../../core/services/data_service_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_shell.dart';
import '../auth/sign_in_screen.dart';
import 'enrollment_screen.dart';

/// Decides which top-level widget the user actually sees on app launch.
///
///  * Mock mode → always [AppShell] (the app is fully offline).
///  * Supabase mode → while `bootstrapProvider` is running, shows a
///    spinner; if it lands on [BootstrapPhase.awaitingEnrollment] we
///    show [EnrollmentScreen]; if it fails we show a retry screen;
///    otherwise we hand off to [AppShell].
class BootstrapGate extends ConsumerWidget {
  const BootstrapGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(dataSourceModeProvider);
    if (mode == DataSourceMode.mock) return const AppShell();

    final state = ref.watch(bootstrapProvider);

    return state.when(
      loading: () => const _BootstrapSplash(message: 'Starting NetworkWise…'),
      error: (err, _) => _BootstrapError(error: err, onRetry: () {
        ref.read(bootstrapProvider.notifier).retry();
      }),
      data: (s) {
        switch (s.phase) {
          case BootstrapPhase.awaitingEnrollment:
            return const EnrollmentScreen();
          case BootstrapPhase.failed:
            return _BootstrapError(
              error: s.error ?? 'Unknown error',
              onRetry: () => ref.read(bootstrapProvider.notifier).retry(),
            );
          case BootstrapPhase.idle:
          case BootstrapPhase.resolvingIdentity:
          case BootstrapPhase.registering:
            return _BootstrapSplash(
              message: _labelFor(s.phase),
            );
          case BootstrapPhase.ready:
            // Endpoint role → straight into the shell; admin role →
            // pass through the auth gate first.
            return Env.isAdminRole ? const _AdminAuthGate() : const AppShell();
        }
      },
    );
  }

  static String _labelFor(BootstrapPhase phase) {
    switch (phase) {
      case BootstrapPhase.resolvingIdentity:
        return 'Resolving device identity…';
      case BootstrapPhase.registering:
        return 'Registering with Supabase…';
      case BootstrapPhase.idle:
        return 'Starting NetworkWise…';
      default:
        return 'Starting NetworkWise…';
    }
  }
}

/// Gates the admin dashboard behind a Supabase Auth sign-in.
class _AdminAuthGate extends ConsumerWidget {
  const _AdminAuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminAuthProvider);

    return state.when(
      loading: () => const _BootstrapSplash(message: 'Restoring session…'),
      error: (err, _) => _BootstrapError(
        error: err,
        onRetry: () => ref.invalidate(adminAuthProvider),
      ),
      data: (s) {
        switch (s.status) {
          case AdminAuthStatus.loading:
            return const _BootstrapSplash(message: 'Restoring session…');
          case AdminAuthStatus.signedOut:
          case AdminAuthStatus.notAdmin:
            return const SignInScreen();
          case AdminAuthStatus.signedIn:
            return const AppShell();
        }
      },
    );
  }
}

class _BootstrapSplash extends StatelessWidget {
  final String message;
  const _BootstrapSplash({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.neutral,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BootstrapError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _BootstrapError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 36,
                  color: AppColors.danger,
                ),
                const SizedBox(height: 12),
                Text(
                  'Could not start NetworkWise',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.neutral),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
