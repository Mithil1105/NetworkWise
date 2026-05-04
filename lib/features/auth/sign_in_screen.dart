import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import 'enrollment_help_dialog.dart';

/// Email + password sign-in for the admin dashboard. Rendered only on
/// the main dashboard machine (the endpoint fleet never sees it — their
/// entry point is [EnrollmentScreen]).
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    await ref.read(adminAuthProvider.notifier).signIn(
          email: _email.text,
          password: _password.text,
        );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminAuthProvider).valueOrNull;
    final errorMsg = state?.errorMessage;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.divider),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.admin_panel_settings_outlined,
                        size: 36,
                        color: AppColors.seed,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'NetworkWise admin',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Sign in with your Mistry & Shah admin '
                        'credentials.',
                        style: TextStyle(color: AppColors.neutral),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _email,
                        enabled: !_busy,
                        autofillHints: const [AutofillHints.email],
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: (raw) {
                          final v = (raw ?? '').trim();
                          if (v.isEmpty) return 'Required.';
                          if (!v.contains('@')) return 'Enter a valid email.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        enabled: !_busy,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip:
                                _obscure ? 'Show password' : 'Hide password',
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) =>
                            (v == null || v.length < 6) ? 'Too short.' : null,
                        onFieldSubmitted: (_) => _busy ? null : _submit(),
                      ),
                      if (errorMsg != null && errorMsg.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _ErrorBanner(text: errorMsg),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _busy ? null : _submit,
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.login),
                        label: Text(_busy ? 'Signing in…' : 'Sign in'),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Only listed admins can sign in. To add or '
                        'remove an admin, use Settings ▸ Admins on an '
                        'already-signed-in machine.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.neutral,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Divider with label — helps separate auth from
                      // the secondary "enrol a PC" call-to-action so
                      // operators who opened this build just to learn
                      // the workflow don't bounce off a plain form.
                      Row(
                        children: const [
                          Expanded(child: Divider(color: AppColors.divider)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'ENROL A NEW PC',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w700,
                                color: AppColors.neutral,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: AppColors.divider)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () =>
                            showEnrollmentHelpDialog(context),
                        icon: const Icon(Icons.devices_outlined, size: 18),
                        label: const Text(
                          'How to add a PC with an enrollment code',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in first to reveal the code. New PCs paste '
                        'the code on their own first-run screen.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.neutral,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String text;
  const _ErrorBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
