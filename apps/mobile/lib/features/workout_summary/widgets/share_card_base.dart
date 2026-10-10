import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/workout_summary_models.dart';

/// Reusable shareable card wrapper providing:
/// - Background #0A0A0A, radius 32, padding 24
/// - Top-left plan name in grey, Week · Day in white bold
/// - Top-right formatted date in grey
/// - Thin yellow #FFC400 divider line
/// - Footer: App logo + wordmark on left, @username on right
class ShareCardBase extends StatelessWidget {
  final WorkoutSummary summary;
  final Widget child;
  final String? customWordmark;

  const ShareCardBase({
    super.key,
    required this.summary,
    required this.child,
    this.customWordmark,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final formattedDate = dateFormat.format(summary.date);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- 1. Header ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top-Left: Plan Name & Week/Day
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.planName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Week ${summary.week} · Day ${summary.day}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Top-Right: Date
              Text(
                formattedDate,
                style: const TextStyle(
                  color: Color(0xFF9E9E9E),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Thin yellow #FFC400 divider line
          Container(
            height: 1.5,
            decoration: BoxDecoration(
              color: const Color(0xFFFFC400),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 12),

          // --- 2. Middle Content ---
          Expanded(child: child),

          const SizedBox(height: 10),

          // --- 3. Footer ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: App Logo + Wordmark
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAppLogo(),
                  const SizedBox(width: 8),
                  Text(
                    customWordmark ?? 'ALPHA X',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
              // Right: Athlete handle
              Text(
                summary.username.startsWith('@')
                    ? summary.username
                    : '@${summary.username}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppLogo() {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: const Color(0xFFFFC400),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Image.asset(
          'assets/images/alpha_x_logo.png',
          width: 16,
          height: 16,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.fitness_center_rounded,
            size: 14,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
