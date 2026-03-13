// lib/admin/screens/admin_users_screen.dart
// Admin User Management — view all users, change roles, toggle active status.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../models/admin_models.dart';
import '../providers/admin_providers.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  String _search = '';
  String? _roleFilter;

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(adminProvider.notifier).loadUsers());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminProvider);
    final isLoading = state.isSectionLoading(AdminSection.users);

    ref.listen<AdminState>(adminProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.error!),
          backgroundColor: AppColors.error,
        ));
        ref.read(adminProvider.notifier).clearError();
      }
    });

    final all = state.users;
    final filtered = all.where((u) {
      final matchRole =
          _roleFilter == null || u.role == _roleFilter;
      final q = _search.toLowerCase();
      final matchSearch = q.isEmpty ||
          u.fullName.toLowerCase().contains(q) ||
          (u.email?.toLowerCase().contains(q) ?? false) ||
          (u.phone?.contains(q) ?? false);
      return matchRole && matchSearch;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('User Management',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () =>
                  ref.read(adminProvider.notifier).loadUsers(),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search by name, email, phone…',
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),

          // Role filter chips
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _RoleChip(
                  label: 'All (${all.length})',
                  selected: _roleFilter == null,
                  color: AppColors.textSecondary,
                  onTap: () => setState(() => _roleFilter = null),
                ),
                for (final role in ['user', 'pandit', 'admin']) ...[
                  const SizedBox(width: 8),
                  _RoleChip(
                    label:
                        '${role[0].toUpperCase()}${role.substring(1)} (${all.where((u) => u.role == role).length})',
                    selected: _roleFilter == role,
                    color: _roleColor(role),
                    onTap: () =>
                        setState(() => _roleFilter = role),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),

          // List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      isLoading ? 'Loading users…' : 'No users found',
                      style: const TextStyle(
                          color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 8),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _UserCard(
                      user: filtered[i],
                      onToggle: (active) => ref
                          .read(adminProvider.notifier)
                          .toggleUser(filtered[i].id,
                              isActive: active),
                      onRoleChange: (role) => ref
                          .read(adminProvider.notifier)
                          .updateUserRole(filtered[i].id, role),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':  return const Color(0xFFEF4444);
      case 'pandit': return const Color(0xFF8B5CF6);
      default:       return const Color(0xFF10B981);
    }
  }
}

// ── Role chip ─────────────────────────────────────────────────────────────────

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight:
                  selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? color : AppColors.textSecondary,
            ),
          ),
        ),
      );
}

// ── User card ─────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onToggle,
    required this.onRoleChange,
  });

  final AdminUser user;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onRoleChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: user.roleColor.withValues(alpha: 0.12),
            child: Text(
              user.initials,
              style: TextStyle(
                color: user.roleColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.fullName.isEmpty
                            ? 'Unnamed User'
                            : user.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _RoleBadge(role: user.role, color: user.roleColor),
                  ],
                ),
                if (user.email != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    user.email!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (user.phone != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    user.phone!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),

          // Actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Active toggle
              Switch(
                value: user.isActive,
                onChanged: onToggle,
                activeColor: AppColors.success,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),

              // Role dropdown
              PopupMenuButton<String>(
                initialValue: user.role,
                onSelected: (role) {
                  if (role == user.role) return;
                  showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Change Role'),
                      content: Text(
                        'Change ${user.fullName}\'s role to "$role"?\n\nThis affects their access level.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.pop(context, true),
                          child: const Text('Confirm'),
                        ),
                      ],
                    ),
                  ).then((confirmed) {
                    if (confirmed == true) onRoleChange(role);
                  });
                },
                itemBuilder: (_) => [
                  for (final r in ['user', 'pandit', 'admin'])
                    PopupMenuItem<String>(
                      value: r,
                      child: Text(
                          '${r[0].toUpperCase()}${r.substring(1)}'),
                    ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Role',
                          style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role, required this.color});
  final String role;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          role.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      );
}
