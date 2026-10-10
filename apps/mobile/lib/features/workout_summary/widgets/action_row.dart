import 'package:flutter/material.dart';

/// Circular 64px action button matching specification:
/// - 64px circle with a light grey border
/// - Centered icon (supports gradient or solid color)
/// - Label below it
class ActionButtonCircle extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback onTap;
  final bool isLoading;

  const ActionButtonCircle({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: isLoading ? null : onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: const Color(0xFFE5E5EA),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.black,
                      ),
                    )
                  : icon,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF1C1C1E),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}

/// The 5 circular action buttons row at the bottom of the modal sheet:
/// Stories (Instagram gradient icon) | Share | Save | Save All | Text
class ActionRow extends StatelessWidget {
  final VoidCallback onStories;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback onSaveAll;
  final VoidCallback onText;
  final bool isExporting;

  const ActionRow({
    super.key,
    required this.onStories,
    required this.onShare,
    required this.onSave,
    required this.onSaveAll,
    required this.onText,
    this.isExporting = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 1. Stories (Instagram gradient icon)
        ActionButtonCircle(
          label: 'Stories',
          isLoading: isExporting,
          onTap: onStories,
          icon: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              colors: [
                Color(0xFF833AB4),
                Color(0xFFFD1D1D),
                Color(0xFFFCB045),
              ],
            ).createShader(bounds),
            child: const Icon(
              Icons.camera_alt_rounded,
              size: 28,
              color: Colors.white,
            ),
          ),
        ),

        // 2. Share (System share sheet with card PNG)
        ActionButtonCircle(
          label: 'Share',
          isLoading: isExporting,
          onTap: onShare,
          icon: const Icon(
            Icons.ios_share_rounded,
            size: 26,
            color: Color(0xFF1C1C1E),
          ),
        ),

        // 3. Save (Save current card PNG to gallery)
        ActionButtonCircle(
          label: 'Save',
          isLoading: isExporting,
          onTap: onSave,
          icon: const Icon(
            Icons.download_rounded,
            size: 28,
            color: Color(0xFF1C1C1E),
          ),
        ),

        // 4. Save All (Save all 6 cards to gallery)
        ActionButtonCircle(
          label: 'Save All',
          isLoading: isExporting,
          onTap: onSaveAll,
          icon: const Icon(
            Icons.download_for_offline_rounded,
            size: 28,
            color: Color(0xFF1C1C1E),
          ),
        ),

        // 5. Text (Share plain-text summary)
        ActionButtonCircle(
          label: 'Text',
          isLoading: isExporting,
          onTap: onText,
          icon: const Icon(
            Icons.chat_bubble_outline_rounded,
            size: 25,
            color: Color(0xFF1C1C1E),
          ),
        ),
      ],
    );
  }
}
