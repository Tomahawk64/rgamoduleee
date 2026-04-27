// lib/admin/screens/_admin_catalogue_tab.dart
// Catalogue tab inside AdminShellScreen — manage poojas, packages, products.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../models/admin_models.dart';
import '../providers/admin_package_catalog_provider.dart';

class AdminCatalogueTab extends StatelessWidget {
  const AdminCatalogueTab({
    super.key,
    required this.state,
    required this.catalogState,
  });

  final AdminState state;
  final AdminPackageCatalogState catalogState;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // ── Special Poojas ───────────────────────────────────────────────────
        _CatalogueSectionCard(
          icon: Icons.auto_awesome_rounded,
          color: const Color(0xFF6A1B9A),
          title: 'Special Poojas',
          count: state.poojas.length,
          countLabel: 'listings',
          description: 'Manage special pooja ceremonies — add, edit, toggle visibility.',
          onManage: () => context.push(Routes.adminPoojas),
          items: state.poojas.take(3).map((p) => _CatalogueItem(
            name: p.title,
            meta: '₹${p.basePrice.toStringAsFixed(0)} · ${p.durationLabel}',
            isActive: p.isActive,
            imageUrl: p.imageUrl,
          )).toList(),
        ),

        const SizedBox(height: 14),

        // ── Pooja Packages ───────────────────────────────────────────────────
        _CatalogueSectionCard(
          icon: Icons.temple_hindu_rounded,
          color: AppColors.primary,
          title: 'Pooja Packages',
          count: catalogState.packages.length,
          countLabel: 'packages',
          description: 'Manage bookable pooja packages — pricing, pandits, schedules.',
          onManage: () => context.push(Routes.adminPackages),
          items: catalogState.packages.take(3).map((p) => _CatalogueItem(
            name: p.title,
            meta: '₹${p.price.toStringAsFixed(0)} · ${p.durationLabel}',
            isActive: p.isActive,
            imageUrl: p.imageUrl,
          )).toList(),
        ),

        const SizedBox(height: 14),

        // ── Shop Products ────────────────────────────────────────────────────
        _CatalogueSectionCard(
          icon: Icons.shopping_bag_rounded,
          color: const Color(0xFFE65100),
          title: 'Shop Products',
          count: state.products.length,
          countLabel: 'products',
          description: 'Manage shop inventory — offerings, pricing and stock status.',
          onManage: () => context.push(Routes.adminProducts),
          items: state.products.take(3).map((p) => _CatalogueItem(
            name: p.name,
            meta: '₹${p.priceRupees.toStringAsFixed(0)}',
            isActive: p.isActive,
            imageUrl: p.imageUrl,
          )).toList(),
        ),
      ],
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _CatalogueSectionCard extends StatelessWidget {
  const _CatalogueSectionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.count,
    required this.countLabel,
    required this.description,
    required this.onManage,
    required this.items,
  });

  final IconData icon;
  final Color color;
  final String title;
  final int count;
  final String countLabel;
  final String description;
  final VoidCallback onManage;
  final List<_CatalogueItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 22, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: color,
                        ),
                      ),
                      Text(
                        '$count $countLabel',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: onManage,
                  icon: Icon(Icons.open_in_new_rounded, size: 14, color: color),
                  label: Text(
                    'Manage',
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: color.withValues(alpha: 0.08),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),

          // Description
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Text(
              description,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),

          // Preview items
          if (items.isNotEmpty) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            ...items.map((item) => _ItemTile(item: item, accentColor: color)),
            const SizedBox(height: 4),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                'No items added yet.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Item tile ─────────────────────────────────────────────────────────────────

class _CatalogueItem {
  const _CatalogueItem({
    required this.name,
    required this.meta,
    required this.isActive,
    this.imageUrl,
  });
  final String name;
  final String meta;
  final bool isActive;
  final String? imageUrl;
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.accentColor});
  final _CatalogueItem item;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: item.imageUrl != null && item.imageUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                item.imageUrl!,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _iconFallback(accentColor),
              ),
            )
          : _iconFallback(accentColor),
      title: Text(
        item.name,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        item.meta,
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: item.isActive
              ? AppColors.success.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          item.isActive ? 'Active' : 'Inactive',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: item.isActive ? AppColors.success : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _iconFallback(Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(Icons.image_outlined, size: 18, color: color.withValues(alpha: 0.5)),
    );
  }
}
