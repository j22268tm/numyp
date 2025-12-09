import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/spot.dart';
import 'glass_card.dart';

class SpotDetailCard extends StatelessWidget {
  const SpotDetailCard({super.key, required this.spot, this.onClose});

  final Spot spot;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 90,
                  width: 110,
                  child: spot.content.imageUrl != null
                      ? Image.network(
                          spot.content.imageUrl!,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: AppColors.cardSurface.withOpacity(0.5),
                          child: const Icon(Icons.photo, color: Colors.white54),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            spot.content.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (onClose != null)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            color: AppColors.textSecondary,
                            onPressed: onClose,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _StatusChip(label: spot.status.crowdLevel.label),
                        const SizedBox(width: 8),
                        _StatusChip(
                          icon: Icons.star,
                          label: spot.status.rating.toString(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      spot.content.description ?? '詳細情報は後ほど公開されます。',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.fantasyPurple,
                          backgroundImage: spot.author.iconUrl != null
                              ? NetworkImage(spot.author.iconUrl!)
                              : null,
                          child: spot.author.iconUrl == null
                              ? const Icon(Icons.person, size: 16)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          spot.author.username,
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                        const Spacer(),
                        if (spot.skin.imageUrl != null)
                          Chip(
                            backgroundColor:
                                AppColors.cardSurface.withOpacity(0.7),
                            avatar: CircleAvatar(
                              backgroundImage: NetworkImage(spot.skin.imageUrl!),
                            ),
                            label: Text(
                              spot.skin.name,
                              style: const TextStyle(color: AppColors.textPrimary),
                            ),
                          ),
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({this.icon, required this.label});

  final IconData? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardSurface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.magicGold),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
