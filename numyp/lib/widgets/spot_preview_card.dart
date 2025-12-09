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
                    ? Image.network(spot.content.imageUrl!, fit: BoxFit.cover)
                    : Container(
                        color: AppColors.cardSurface.withOpacity(0.5),
                        child: const Center(
                          child: Icon(Icons.image_not_supported,
                              color: Colors.white54),
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
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: AppColors.magicGold),
              const SizedBox(width: 4),
              Text(
                '${spot.location.latitude.toStringAsFixed(5)}, ${spot.location.longitude.toStringAsFixed(5)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
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
