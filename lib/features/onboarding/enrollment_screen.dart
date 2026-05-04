import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bootstrap/bootstrap_provider.dart';
import '../../core/services/enrollment_provider.dart';
import '../../core/theme/app_colors.dart';

/// First-run screen shown when this endpoint has never been enrolled
/// into an organisation.
///
/// Collects the `MSH-XXXX-YYYY` code the operator was given in the
/// admin dashboard, stores it in SharedPreferences, and re-invalidates
/// the bootstrap so registration can proceed with the new code.
class EnrollmentScreen extends ConsumerStatefulWidget {
  const EnrollmentScreen({super.key});

  @override
  ConsumerState<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends ConsumerState<EnrollmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(enrollmentCodeProvider.notifier)
          .set(_controller.text);
      // Re-run bootstrap — register-device will now be called with the
      // fresh code.
      await ref.read(bootstrapProvider.notifier).retry();
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
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
                        Icons.vpn_key_outlined,
                        size: 36,
                        color: AppColors.seed,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Enrol this device',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Enter the enrollment code your administrator '
                        'copied from the NetworkWise dashboard. '
                        'Format looks like MSH-7F2K-91QR.',
                        style: TextStyle(color: AppColors.neutral),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _controller,
                        enabled: !_busy,
                        autofocus: true,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9-]'),
                          ),
                          LengthLimitingTextInputFormatter(24),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Enrollment code',
                          hintText: 'MSH-XXXX-YYYY',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.qr_code_2),
                        ),
                        validator: (raw) {
                          final v = (raw ?? '').trim();
                          if (v.length < 6) return 'Code is too short.';
                          if (!RegExp(r'^[A-Za-z0-9-]+$').hasMatch(v)) {
                            return 'Letters, digits and dashes only.';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _busy ? null : _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _ErrorBanner(text: _error!),
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
                            : const Icon(Icons.check),
                        label: Text(_busy ? 'Enrolling…' : 'Continue'),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'You can rotate this code from the Settings '
                        'screen once the device is online.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.neutral,
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
