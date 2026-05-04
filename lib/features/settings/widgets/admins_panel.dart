import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/admin/admin_members_provider.dart';
import '../../../core/admin/admin_members_service.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import 'settings_section.dart';

/// Admin-only Settings panel. Shows the signed-in admin, offers a
/// sign-out button, and lets existing admins invite new ones via the
/// `invite-admin` Edge Function.
class AdminsPanel extends ConsumerWidget {
  const AdminsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(adminAuthProvider).valueOrNull;
    final member = auth?.member;

    return SettingsSection(
      title: 'Admins',
      subtitle:
          'Dashboard sign-in accounts for your organisation. Endpoint '
          'devices never see this panel.',
      icon: Icons.admin_panel_settings_outlined,
      children: [
        if (member != null) ...[
          _CurrentAdminRow(
            email: member.email,
            fullName: member.fullName,
            role: member.role,
            onSignOut: () => _confirmSignOut(context, ref),
          ),
          const Divider(height: 1, color: AppColors.divider),
        ],
        const _InviteAdminForm(),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will be returned to the sign-in screen. Your enrolled '
          'endpoints keep running and reporting; only this dashboard '
          'session ends.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(adminAuthProvider.notifier).signOut();
  }
}

// ---------------------------------------------------------------------

class _CurrentAdminRow extends StatelessWidget {
  const _CurrentAdminRow({
    required this.email,
    required this.fullName,
    required this.role,
    required this.onSignOut,
  });

  final String email;
  final String? fullName;
  final String role;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.infoBg,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.person_outline,
              color: AppColors.info,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fullName == null || fullName!.trim().isEmpty
                      ? email
                      : fullName!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$email  •  ${role.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.neutral,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------

class _InviteAdminForm extends ConsumerStatefulWidget {
  const _InviteAdminForm();

  @override
  ConsumerState<_InviteAdminForm> createState() => _InviteAdminFormState();
}

class _InviteAdminFormState extends ConsumerState<_InviteAdminForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _fullName = TextEditingController();
  final _password = TextEditingController();
  String _role = 'admin';
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _email.dispose();
    _fullName.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final service = ref.read(adminMembersServiceProvider);
      final result = await service.invite(
        email: _email.text,
        password: _password.text,
        fullName: _fullName.text,
        role: _role,
      );
      if (!mounted) return;
      setState(() {
        _success =
            '${result.email} invited as ${result.role.toUpperCase()}.';
        _email.clear();
        _fullName.clear();
        _password.clear();
        _role = 'admin';
      });
    } on InviteAdminException catch (err) {
      if (!mounted) return;
      setState(() => _error = err.message);
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Invite a new admin',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Creates a Supabase Auth account and attaches it to your '
              'organisation. Share the initial password securely — the new '
              'admin can change it after first sign-in.',
              style: TextStyle(fontSize: 11.5, color: AppColors.neutral),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _email,
                    enabled: !_busy,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.mail_outline),
                      isDense: true,
                    ),
                    validator: (raw) {
                      final v = (raw ?? '').trim();
                      if (v.isEmpty) return 'Required.';
                      if (!v.contains('@')) return 'Enter a valid email.';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _fullName,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Full name (optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _password,
                    enabled: !_busy,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'Initial password',
                      helperText:
                          'Minimum 8 characters. The new admin should '
                          'change this after sign-in.',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.password_outlined),
                      isDense: true,
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'Show' : 'Hide',
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 18,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 8) ? 'At least 8 chars.' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _role,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _role = v ?? 'admin'),
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.verified_user_outlined),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      DropdownMenuItem(value: 'owner', child: Text('Owner')),
                    ],
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _Banner(
                icon: Icons.error_outline,
                color: AppColors.danger,
                background: AppColors.dangerBg,
                text: _error!,
              ),
            ],
            if (_success != null) ...[
              const SizedBox(height: 12),
              _Banner(
                icon: Icons.check_circle_outline,
                color: AppColors.success,
                background: AppColors.successBg,
                text: _success!,
              ),
            ],
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.person_add_alt_1, size: 16),
                label: Text(_busy ? 'Inviting…' : 'Send invite'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.background,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
