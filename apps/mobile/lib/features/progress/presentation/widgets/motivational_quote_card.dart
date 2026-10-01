import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/alpha_x_design_system.dart';

class MotivationalQuoteCard extends StatefulWidget {
  final VoidCallback? onQuoteChanged;

  const MotivationalQuoteCard({super.key, this.onQuoteChanged});

  @override
  State<MotivationalQuoteCard> createState() => _MotivationalQuoteCardState();
}

class _MotivationalQuoteCardState extends State<MotivationalQuoteCard> {
  static const List<Map<String, String>> _quotes = [
    {
      'quote': 'Consistency creates results.',
      'author': 'Alpha X Philosophy',
    },
    {
      'quote': 'Progress, not perfection.',
      'author': 'Daily Focus',
    },
    {
      'quote': 'One week at a time. One goal at a time.',
      'author': 'Weekly Standard',
    },
    {
      'quote': "Your future self will thank you for today's discipline.",
      'author': 'Mindset',
    },
    {
      'quote': 'Small progress every single day adds up to massive results.',
      'author': 'Compound Effort',
    },
    {
      'quote': 'Discipline is choosing between what you want now and what you want most.',
      'author': 'Training Creed',
    },
    {
      'quote': 'Show up for yourself every week. The momentum will do the rest.',
      'author': 'Habit System',
    },
  ];

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Deterministic quote based on day of year
    _currentIndex = DateTime.now().day % _quotes.length;
  }

  void _nextQuote() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % _quotes.length;
    });
    widget.onQuoteChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final item = _quotes[_currentIndex];

    return InkWell(
      onTap: _nextQuote,
      borderRadius: BorderRadius.circular(AlphaXRadius.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AlphaXColors.surfaceCard,
          borderRadius: BorderRadius.circular(AlphaXRadius.md),
          border: Border.all(
            color: AlphaXColors.gold.withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AlphaXColors.gold.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.format_quote_rounded,
                color: AlphaXColors.gold,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WEEKLY MOTIVATION',
                    style: TextStyle(
                      color: AlphaXColors.gold.withValues(alpha: 0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '"${item['quote']}"',
                    style: const TextStyle(
                      color: AlphaXColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '— ${item['author']}',
                        style: const TextStyle(
                          color: AlphaXColors.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Text(
                        'tap to rotate',
                        style: TextStyle(
                          color: AlphaXColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
