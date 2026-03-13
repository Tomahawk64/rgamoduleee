import 'package:flutter/material.dart';

import '../models/package_model.dart';

class PackageListCard extends StatelessWidget {
  const PackageListCard({
    super.key,
    required this.package,
    required this.onTap,
    this.onBook,
  });

  final PackageModel package;
  final VoidCallback onTap;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image header ──────────────────────────────────────────
            Stack(
              children: [
                _ImageBanner(package: package),
                // Discount badge
                if (package.hasDiscount)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _DiscountBadge(
                        percent: package.discountPercent),
                  ),
                // Mode chip
                Positioned(
                  top: 10,
                  right: 10,
                  child: _ModeChip(mode: package.mode),
                ),
              ],
            ),

            // ── Body ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category + title
                  Row(
                    children: [
                      Icon(package.category.icon,
                          size: 14, color: cs.primary),
                      const SizedBox(width: 4),
                      Text(
                        package.category.label,
                        style: tt.labelSmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    package.title,
                    style: tt.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    package.description,
                    style: tt.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),

                  // Stats row
                  Row(
                    children: [
                      Icon(Icons.star_rounded,
                          size: 15, color: Colors.amber[700]),
                      const SizedBox(width: 2),
                      Text(
                        package.rating.toStringAsFixed(1),
                        style: tt.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${package.reviewCount})',
                        style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.schedule_rounded,
                          size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(
                        package.durationLabel,
                        style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Footer: price + CTA ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 12, 12),
              child: Row(
                children: [
                  // Price block
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₹${package.effectivePrice.toStringAsFixed(0)}',
                        style: tt.titleMedium?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (package.hasDiscount)
                        Text(
                          '₹${package.price.toStringAsFixed(0)}',
                          style: tt.labelSmall?.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  // Book button
                  FilledButton(
                    onPressed: onBook ?? onTap,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Book Now',
                        style: TextStyle(
                            fontWeight: FontWeight.w700)),
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

// ── Private sub-widgets ───────────────────────────────────────────────────────

class _ImageBanner extends StatelessWidget {
  const _ImageBanner({required this.package});
  final PackageModel package;

  static const _gradients = {
    PackageCategory.puja: [Color(0xFFFF6B35), Color(0xFFFF8C69)],
    PackageCategory.astrology: [Color(0xFF2D4A8A), Color(0xFF5C7BC4)],
    PackageCategory.vastu: [Color(0xFF1B5E20), Color(0xFF43A047)],
    PackageCategory.havan: [Color(0xFFBF360C), Color(0xFFE64A19)],
    PackageCategory.katha: [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
    PackageCategory.remedies: [Color(0xFF00838F), Color(0xFF4DD0E1)],
    PackageCategory.other: [Color(0xFF37474F), Color(0xFF78909C)],
  };

  @override
  Widget build(BuildContext context) {
    final colors =
        _gradients[package.category] ?? _gradients[PackageCategory.other]!;

    if (package.imageUrl != null) {
      final isLocal = package.imageUrl!.startsWith('assets/');
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: isLocal
            ? Image.asset(
                package.imageUrl!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
              )
            : Image.network(
                package.imageUrl!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _gradient(colors),
              ),
      );
    }
    return _gradient(colors);
  }

  Widget _gradient(List<Color> colors) {
    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Icon(package.category.icon,
            size: 52, color: Colors.white.withAlpha(200)),
      ),
    );
  }
}

class _DiscountBadge extends StatelessWidget {
  const _DiscountBadge({required this.percent});
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red[700],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$percent% OFF',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.mode});
  final PackageMode mode;

  @override
  Widget build(BuildContext context) {
    final (label, icon, bg) = switch (mode) {
      PackageMode.online  => ('Online',    Icons.videocam_rounded,   const Color(0xFF1B5E20)),
      PackageMode.offline => ('On-site',   Icons.home_rounded,       const Color(0xFF2D4A8A)),
      PackageMode.both    => ('Online & On-site', Icons.swap_horiz_rounded, const Color(0xFF4A148C)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withAlpha(200),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 3),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
