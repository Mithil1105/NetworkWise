import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/admin_member.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/config/env.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/theme/app_colors.dart';

/// Top bar: page title (left) + quick actions + profile menu (right).
class AppTopBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onRefresh;

  const AppTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: AppConstants.topBarHeight,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          _IconButton(
            icon: Icons.search,
            tooltip: 'Search',
            onTap: () {},
          ),
          const SizedBox(width: 4),
          _IconButton(
            icon: Icons.refresh,
            tooltip: 'Refresh',
            onTap: onRefresh ?? () {},
          ),
          const SizedBox(width: 4),
          const _ThemeToggleButton(),
          const SizedBox(width: 4),
          _IconButton(
            icon: Icons.notifications_none,
            tooltip: 'Notifications',
            onTap: () {},
          ),
          const SizedBox(width: 12),
          const _ProfileChip(),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 20),
        color: theme.colorScheme.onSurfaceVariant,
        onPressed: onTap,
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _ThemeToggleButton extends ConsumerWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final current = settings.themeMode;
    final isDark = current == ThemeMode.dark ||
        (current == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    final icon = isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined;
    final tooltip =
        isDark ? 'Switch to light mode' : 'Switch to dark mode';
    return _IconButton(
      icon: icon,
      tooltip: tooltip,
      onTap: () {
        final controller = ref.read(settingsProvider.notifier);
        controller.setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
      },
    );
  }
}

class _ProfileChip extends ConsumerWidget {
  const _ProfileChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(adminAuthProvider);
    final member = authState.valueOrNull?.member;
    final status = authState.valueOrNull?.status;

    // Endpoint role (non-admin) installs don't have a Supabase auth
    // session — keep the profile chip for branding but omit the sign-out
    // option so nobody accidentally disables the local endpoint agent.
    final canSignOut =
        Env.isAdminRole && status == AdminAuthStatus.signedIn;

    final displayName = _resolveDisplayName(member);
    final subtitle = _resolveSubtitle(member);
    final initials = _initialsFromName(displayName);

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: theme.colorScheme.primary,
            child: Text(
              initials,
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayName,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Icon(Icons.keyboard_arrow_down,
              size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
        ],
      ),
    );

    if (!canSignOut) {
      return Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        child: content,
      );
    }

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(24),
      child: PopupMenuButton<_ProfileAction>(
        tooltip: 'Account',
        position: PopupMenuPosition.under,
        offset: const Offset(0, 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        itemBuilder: (ctx) => <PopupMenuEntry<_ProfileAction>>[
          PopupMenuItem<_ProfileAction>(
            enabled: false,
            padding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    member?.email ?? subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (member?.role != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _roleLabel(member!.role),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<_ProfileAction>(
            value: _ProfileAction.signOut,
            child: Row(
              children: [
                Icon(Icons.logout,
                    size: 18, color: AppColors.danger),
                const SizedBox(width: 10),
                const Text(
                  'Sign out',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
        ],
        onSelected: (action) async {
          switch (action) {
            case _ProfileAction.signOut:
              await _confirmSignOut(context, ref);
              break;
          }
        },
        child: content,
      ),
    );
  }

  static Future<void> _confirmSignOut(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will be returned to the sign-in screen. Endpoint agents on '
          'monitored devices keep running — this only signs you out of the '
          'admin dashboard on this machine.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(adminAuthProvider.notifier).signOut();
  }

  static String _resolveDisplayName(AdminMember? member) {
    if (member == null) {
      return Env.isAdminRole ? 'Admin' : 'Endpoint agent';
    }
    final full = member.fullName;
    if (full != null && full.trim().isNotEmpty) return full.trim();
    final email = member.email;
    if (email.contains('@')) return email.split('@').first;
    return email;
  }

  static String _resolveSubtitle(AdminMember? member) {
    if (member == null) {
      return Env.isAdminRole ? 'Not signed in' : 'This device';
    }
    return _roleLabel(member.role);
  }

  static String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return 'Organisation Owner';
      case 'admin':
        return 'IT Administrator';
      default:
        return role;
    }
  }

  static String _initialsFromName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'MS';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      final w = parts.first;
      return w.length >= 2
          ? w.substring(0, 2).toUpperCase()
          : w.toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

enum _ProfileAction { signOut }
