import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../data/models/ipo.dart';

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});

  final IpoStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      IpoStatus.open => ('OPEN', AppColors.mint),
      IpoStatus.upcoming => ('UPCOMING', AppColors.brand),
      IpoStatus.closed => ('CLOSED', AppColors.amber),
      IpoStatus.listed => ('LISTED', Colors.blueGrey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
