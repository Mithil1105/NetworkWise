import 'package:flutter/material.dart';

import '../../shared/widgets/placeholder_page.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      icon: Icons.insert_chart_outlined,
      title: 'Reports',
      body:
          'Exportable reports and historical trends will be added after the '
          'core screens and state layer are in place.',
    );
  }
}
