import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/spot.dart';
import 'glass_card.dart';

class SpotPreviewCard extends StatelessWidget {
  const SpotPreviewCard({super.key, required this.spot, this.onTap});

  final Spot spot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GlassCard(
      width: 210,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox.expand(
                child: spot.content.imageUrl != null
                    ? Image.network(
                        spot.content.imageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              color: colors.magicGold,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: colors.cardSurface.withOpacity(0.5),
                          child: Center(
                            child: Icon(
                              Icons.broken_image,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: colors.cardSurface.withOpacity(0.5),
                        child: Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            spot.content.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: colors.magicGold),
              const SizedBox(width: 4),
              Text(
                '${spot.location.latitude.toStringAsFixed(5)}, ${spot.location.longitude.toStringAsFixed(5)}',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}
