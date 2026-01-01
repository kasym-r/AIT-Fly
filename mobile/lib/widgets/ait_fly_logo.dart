// """
// AIT Fly Logo Widget
// ===================
// Custom logo widget matching the brand design
// """

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AITFlyLogo extends StatelessWidget {
  final double size;
  final bool showTagline;

  const AITFlyLogo({
    super.key,
    this.size = 120,
    this.showTagline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Just text logo
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'AIT',
              style: TextStyle(
                fontSize: size * 0.5,
                fontWeight: FontWeight.bold,
                color: AITFlyTheme.darkPurple,
                letterSpacing: 2,
              ),
            ),
            Text(
              ' fly',
              style: TextStyle(
                fontSize: size * 0.45,
                fontWeight: FontWeight.w500,
                color: AITFlyTheme.primaryPurple,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        if (showTagline) ...[
          const SizedBox(height: 8),
          Text(
            'Your Journey Starts Here',
            style: AITFlyTheme.bodySmall.copyWith(
              color: AITFlyTheme.mediumGray,
            ),
          ),
        ],
      ],
    );
  }
}


