import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Pre-sign-in help dialog. Explains, in plain English, how a new
/// Windows PC gets enrolled once the admin signs in to the dashboard.
///
/// Deliberately does NOT hit Supabase — the user may be looking at this
/// from the sign-in screen and therefore has no session yet. For the
/// signed-in flow (reveal code, copy, rotate) use `showAddDeviceDialog`
/// from `features/devices/widgets/add_device_dialog.dart`.
Future<void> showEnrollmentHelpDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => const _EnrollmentHelpDialog(),
  );
}

class _EnrollmentHelpDialog extends StatelessWidget {
  const _EnrollmentHelpDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.help_outline, color: AppColors.info),
          SizedBox(width: 10),
          Expanded(child: Text('How to enrol a new PC')),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'NetworkWise uses a rolling enrollment code to onboard '
              'every Windows PC into your fleet. You generate the code '
              'from this dashboard and paste it on the endpoint.',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            const _Step(
              number: 1,
              title: 'Sign in as an admin',
              detail:
                  'Use your organisation\'s admin email + password on '
                  'this dashboard. Only members of admin_members can sign '
                  'in — owners can invite more admins from '
                  'Settings ▸ Admins once signed in.',
            ),
            const _Step(
              number: 2,
              title: 'Copy the enrollment code',
              detail:
                  'On the Devices tab, click "Add device". You will see '
                  'a one-time rolling code (e.g. MS-ORG-7F3K-QW29) with '
                  'a copy button. The same code lives in '
                  'Settings ▸ Enrollment Code for easy reference.',
            ),
            const _Step(
              number: 3,
              title: 'Install the endpoint build on the new PC',
              detail:
                  'Install NetworkWise on the Windows PC you want to '
                  'monitor. Its .env has APP_ROLE=endpoint, so on first '
                  'launch it stops at the enrollment screen instead of '
                  'the dashboard.',
            ),
            const _Step(
              number: 4,
              title: 'Paste the code and Continue',
              detail:
                  'On the endpoint PC, paste the code and press '
                  'Continue. The device appears in your Devices list '
                  'within a few seconds and starts shipping heartbeats '
                  'every 60 seconds.',
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.infoBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined,
                      size: 18, color: AppColors.info),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Rotate the code from Settings ▸ Enrollment Code '
                      'whenever you want to invalidate it. Devices that '
                      'already enrolled stay connected — only new '
                      'enrollments need the fresh code.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String title;
  final String detail;

  const _Step({
    required this.number,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(top: 1),
            decoration: const BoxDecoration(
              color: AppColors.infoBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.info,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
