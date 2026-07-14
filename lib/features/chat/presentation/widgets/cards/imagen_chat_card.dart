import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';

class ImagenChatCard extends StatelessWidget {
  final String urlArchivo;
  final bool isMe;

  const ImagenChatCard({
    super.key,
    required this.urlArchivo,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      width: 250,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: isMe ? colors.primary : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          urlArchivo,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            height: 150,
            color: Colors.grey.shade300,
            child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
          ),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 150,
              color: Colors.grey.shade200,
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
