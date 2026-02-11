import 'package:flutter/material.dart';
import '../utils/app_styles.dart';

/// A consistent footer bar used across all screens.
/// During gameplay, this displays piece information.
/// For other screens, it displays system messages or remains empty.
class AppFooter extends StatelessWidget {
  final String? message;
  final Widget? child;

  const AppFooter({super.key, this.message, this.child});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 12 + bottomPadding,
      ),
      decoration: BoxDecoration(
        color: AppStyles.burgundy.withValues(alpha: 0.8),
      ),
      child:
          child ??
          Text(
            message ?? '',
            style: AppStyles.bodyText.copyWith(color: AppStyles.cream),
            textAlign: TextAlign.center,
          ),
    );
  }
}
