// lib/pandit/screens/pandit_screen.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/providers/auth_provider.dart';
import '../../booking/models/booking_status.dart';
import '../../consultation/models/scheduled_consultation_request.dart';
import '../../consultation/providers/consultation_provider.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/supabase_storage_upload_helper.dart';
import '../../offline_booking/models/offline_booking_models.dart';
import '../../offline_booking/providers/offline_booking_provider.dart';
import '../../widgets/base_scaffold.dart';
import '../controllers/pandit_dashboard_controller.dart';
import '../models/pandit_dashboard_models.dart';
import '../providers/pandit_provider.dart';

class PanditScreen extends ConsumerStatefulWidget {
  const PanditScreen({super.key});

  @override
  ConsumerState<PanditScreen> createState() => _PanditScreenState();
}

class _PanditScreenState extends ConsumerState<PanditScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(panditDashboardProvider);
    final user = ref.watch(currentUserProvider);

    // Surface any error as a SnackBar
    ref.listen<PanditDashboardState>(panditDashboardProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () =>
                  ref.read(panditDashboardProvider.notifier).clearError(),
            ),
          ),
        );
      }
    });

    return BaseScaffold(
      title: 'Pandit Dashboard',
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Edit Profile',
          onPressed: () => context.push(Routes.editProfile),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: state.loading
              ? null
              : () => ref.read(panditDashboardProvider.notifier).load(),
        ),
      ],
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(panditDashboardProvider.notifier).load(),
              child: NestedScrollView(
                headerSliverBuilder: (ctx, _) => [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        // ── Profile header ────────────────────────────────
                        _ProfileHeader(
                          state: state,
                          user: user,
                          onUploadPhoto: (bytes, ext) async {
                            final client = ref.read(supabaseClientProvider);
                            final uid = client.auth.currentUser?.id;
                            if (uid == null) return;
                            try {
                              final contentType = ext == 'png'
                                  ? 'image/png'
                                  : 'image/jpeg';
                              final fileName =
                                  'avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
                              final url = await SupabaseStorageUploadHelper
                                  .uploadImageWithFallback(
                                client: client,
                                bytes: bytes,
                                fileName: fileName,
                                contentType: contentType,
                                folder: 'avatar',
                                primaryBucket: SupabaseStorageUploadHelper
                                    .profileImagesBucket,
                                fallbackBuckets: const [],
                              );
                              await ref
                                  .read(panditDashboardProvider.notifier)
                                  .uploadAvatar(url);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Photo upload failed: ${e.toString()}'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // ── Active consultation banner ───────────────────────────────
                        if (user != null)
                          _ActiveConsultationBanner(panditId: user.id, panditName: user.name),

                        // ── Stats row ─────────────────────────────────────
                        _StatsRow(state: state),
                        const SizedBox(height: 16),

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),

                  // ── Tab bar ───────────────────────────────────────────
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabHeaderDelegate(
                      tabController: _tab,
                      activeCount: state.activeCount,
                      completedCount: state.completedCount,
                      consultationCount: 0, // updated live via provider
                      offlineCount: 0, // updated live via provider
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tab,
                  children: [
                    _AssignmentList(
                      assignments: state.activeAssignments,
                      emptyLabel: 'No active bookings',
                      emptyIcon: Icons.event_available_outlined,
                    ),
                    _AssignmentList(
                      assignments: state.completedAssignments,
                      emptyLabel: 'No completed bookings yet',
                      emptyIcon: Icons.task_alt_outlined,
                    ),
                    _ConsultationRequestsTab(
                      panditId: user?.id ?? '',
                    ),
                    _OfflineBookingsTab(
                      panditId: user?.id ?? '',
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── Profile Header ────────────────────────────────────────────────────────────

class _ProfileHeader extends ConsumerStatefulWidget {
  const _ProfileHeader({
    required this.state,
    required this.user,
    required this.onUploadPhoto,
  });

  final PanditDashboardState state;
  final dynamic user;
  final Future<void> Function(Uint8List bytes, String ext) onUploadPhoto;

  @override
  ConsumerState<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends ConsumerState<_ProfileHeader> {
  bool _uploading = false;
  Uint8List? _pendingBytes; // shows optimistic preview before upload completes

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    final dotIdx = picked.name.lastIndexOf('.');
    final ext =
        dotIdx != -1 ? picked.name.substring(dotIdx + 1).toLowerCase() : 'jpg';
    setState(() {
      _pendingBytes = bytes;
      _uploading = true;
    });
    try {
      await widget.onUploadPhoto(bytes, ext.isEmpty ? 'jpg' : ext);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final profile = state.profile;
    final name = profile?.name ?? widget.user?.name ?? 'Pandit';
    final initials =
        profile?.initials ?? (name.isNotEmpty ? name[0].toUpperCase() : 'P');
    final avatarUrl = profile?.avatarUrl;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.secondary, AppColors.secondaryLight],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // ── Tappable avatar ───────────────────────────────────────
              GestureDetector(
                onTap: _uploading ? null : _pickAndUpload,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      backgroundImage: _pendingBytes != null
                          ? MemoryImage(_pendingBytes!) as ImageProvider
                          : (avatarUrl != null && avatarUrl.isNotEmpty)
                              ? NetworkImage(avatarUrl)
                              : null,
                      child: (_pendingBytes == null &&
                              (avatarUrl == null || avatarUrl.isEmpty))
                          ? Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    // Camera icon overlay
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _uploading
                              ? Colors.black45
                              : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.secondary, width: 1.5),
                        ),
                        child: _uploading
                            ? const Padding(
                                padding: EdgeInsets.all(3),
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.camera_alt,
                                size: 11, color: AppColors.secondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Name + details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (profile != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        profile.specialties.take(2).join(' · '),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              size: 12, color: Colors.amber),
                          const SizedBox(width: 3),
                          Text(
                            '${profile.rating}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Colors.white54,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${profile.yearsExperience} yrs exp.',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Online/Offline toggle
              Consumer(
                builder: (context, ref, child) {
                  return GestureDetector(
                    onTap: widget.state.togglingOnline
                        ? null
                        : () => ref.read(panditDashboardProvider.notifier).toggleOnlineStatus(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: (widget.state.profile?.isOnline ?? false)
                            ? Colors.green.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (widget.state.profile?.isOnline ?? false)
                              ? Colors.green.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            (widget.state.profile?.isOnline ?? false)
                                ? Icons.circle
                                : Icons.circle_outlined,
                            color: (widget.state.profile?.isOnline ?? false)
                                ? Colors.green
                                : Colors.white70,
                            size: 10,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            (widget.state.profile?.isOnline ?? false) ? 'Online' : 'Offline',
                            style: TextStyle(
                              color: (widget.state.profile?.isOnline ?? false)
                                  ? Colors.green
                                  : Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (widget.state.togglingOnline) ...[
                            const SizedBox(width: 4),
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),

              // Offline Booking toggle
              Consumer(
                builder: (context, ref, child) {
                  return GestureDetector(
                    onTap: widget.state.togglingOfflineBooking
                        ? null
                        : () => ref.read(panditDashboardProvider.notifier).toggleOfflineBooking(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: (widget.state.profile?.offlineBookingEnabled ?? false)
                            ? Colors.blue.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (widget.state.profile?.offlineBookingEnabled ?? false)
                              ? Colors.blue.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            (widget.state.profile?.offlineBookingEnabled ?? false)
                                ? Icons.event_available
                                : Icons.event_busy,
                            color: (widget.state.profile?.offlineBookingEnabled ?? false)
                                ? Colors.blue
                                : Colors.white70,
                            size: 10,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            (widget.state.profile?.offlineBookingEnabled ?? false) ? 'Booking' : 'No Booking',
                            style: TextStyle(
                              color: (widget.state.profile?.offlineBookingEnabled ?? false)
                                  ? Colors.blue
                                  : Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (widget.state.togglingOfflineBooking) ...[
                            const SizedBox(width: 4),
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),

              // Verified badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded,
                        color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'Verified',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.state});
  final PanditDashboardState state;

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem(
        value: '${state.activeCount}',
        label: 'Active',
        color: AppColors.info,
        icon: Icons.event_available_outlined,
      ),
      _StatItem(
        value: '${state.completedCount}',
        label: 'Completed',
        color: AppColors.success,
        icon: Icons.task_alt_outlined,
      ),
      _StatItem(
        value: '${state.totalCount}',
        label: 'Total',
        color: AppColors.primary,
        icon: Icons.assignment_outlined,
      ),
    ];

    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemCount: items.length,
        itemBuilder: (_, i) => items[i],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
  });

  final String value;
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Active Consultation Banner ────────────────────────────────────────────────
//
// Appears on the pandit dashboard when a user has started a live consultation
// session with this pandit. The pandit can tap "Join Chat" to enter the session.

class _ActiveConsultationBanner extends ConsumerWidget {
  const _ActiveConsultationBanner({
    required this.panditId,
    required this.panditName,
  });

  final String panditId;
  final String panditName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      panditActiveSessionProvider('$panditId|$panditName'),
    );

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (session) {
        if (session == null) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              // Pulsing indicator
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Astrology Active',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.success,
                      ),
                    ),
                    Text(
                      'User: ${session.userName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.push(
                  Routes.consultationChat,
                  extra: session,
                ),
                icon: const Icon(Icons.chat_rounded, size: 16),
                label: const Text('Join Chat'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Tab header delegate ───────────────────────────────────────────────────────

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  _TabHeaderDelegate({
    required this.tabController,
    required this.activeCount,
    required this.completedCount,
    required this.consultationCount,
    required this.offlineCount,
  });

  final TabController tabController;
  final int activeCount;
  final int completedCount;
  final int consultationCount;
  final int offlineCount;

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  bool shouldRebuild(_TabHeaderDelegate old) =>
      old.activeCount != activeCount ||
      old.completedCount != completedCount ||
      old.consultationCount != consultationCount ||
      old.offlineCount != offlineCount;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: TabBar(
        controller: tabController,
        indicatorColor: AppColors.primary,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        tabs: [
          _CountTab(label: 'Active', count: activeCount),
          const Tab(text: 'Completed'),
          _CountTab(label: 'Astrology', count: consultationCount),
          _CountTab(label: 'Offline', count: offlineCount),
        ],
      ),
    );
  }
}

class _CountTab extends StatelessWidget {
  const _CountTab({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Assignment list ───────────────────────────────────────────────────────────

class _AssignmentList extends StatelessWidget {
  const _AssignmentList({
    required this.assignments,
    required this.emptyLabel,
    required this.emptyIcon,
  });

  final List<PanditAssignment> assignments;
  final String emptyLabel;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    if (assignments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon,
                size: 64,
                color: AppColors.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              emptyLabel,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemCount: assignments.length,
      itemBuilder: (ctx, i) => _BookingCard(assignment: assignments[i]),
    );
  }
}

// ── Booking card ──────────────────────────────────────────────────────────────

class _BookingCard extends ConsumerWidget {
  const _BookingCard({required this.assignment});
  final PanditAssignment assignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = assignment.booking;
    final statusColor = booking.status.color;

    return GestureDetector(
      onTap: () => context.push(
        Routes.panditBookingDetail.replaceFirst(':id', booking.id),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.temple_hindu,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.packageTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        booking.category,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(booking.status.icon,
                          size: 10, color: statusColor),
                      const SizedBox(width: 3),
                      Text(
                        booking.status.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Info row
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  booking.formattedDate,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.access_time,
                    size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  booking.slot.label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '₹${booking.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  booking.location.isOnline
                      ? Icons.videocam_outlined
                      : Icons.location_on_outlined,
                  size: 12,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    booking.location.isOnline
                        ? 'Online'
                        : (booking.location.city ?? 'Location TBD'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!booking.isPaid)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Unpaid',
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

          ],
        ),
      ),
    );
  }
}

// ── Consultation Requests Tab ─────────────────────────────────────────────────

class _ConsultationRequestsTab extends ConsumerWidget {
  const _ConsultationRequestsTab({required this.panditId});
  final String panditId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (panditId.isEmpty) {
      return const Center(child: Text('Please login to view requests.'));
    }

    ref.listen(consultationRealtimeTickProvider, (_, __) {
      ref.invalidate(panditScheduledConsultationsProvider(panditId));
    });

    final async = ref.watch(panditScheduledConsultationsProvider(panditId));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: AppColors.error.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            const Text('Failed to load requests',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => ref.invalidate(
                  panditScheduledConsultationsProvider(panditId)),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 64,
                    color: AppColors.primary.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                const Text(
                  'No consultation requests yet',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'When users book a consultation, it will appear here.',
                  style: TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
              ],
            ),
          );
        }

        // Sort: pending first, then by date
        final sorted = List<ScheduledConsultationRequest>.from(list)
          ..sort((a, b) {
            const order = {
              ConsultationRequestStatus.pending: 0,
              ConsultationRequestStatus.rescheduleProposed: 1,
              ConsultationRequestStatus.confirmed: 2,
              ConsultationRequestStatus.active: 3,
            };
            final oa = order[a.status] ?? 10;
            final ob = order[b.status] ?? 10;
            if (oa != ob) return oa.compareTo(ob);
            return b.createdAt.compareTo(a.createdAt);
          });

        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(panditScheduledConsultationsProvider(panditId)),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: sorted.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _ConsultationRequestCard(
              request: sorted[i],
              panditId: panditId,
            ),
          ),
        );
      },
    );
  }
}

// ── Consultation Request Card ─────────────────────────────────────────────────

class _ConsultationRequestCard extends ConsumerStatefulWidget {
  const _ConsultationRequestCard({
    required this.request,
    required this.panditId,
  });

  final ScheduledConsultationRequest request;
  final String panditId;

  @override
  ConsumerState<_ConsultationRequestCard> createState() =>
      _ConsultationRequestCardState();
}

class _ConsultationRequestCardState
    extends ConsumerState<_ConsultationRequestCard> {
  bool _busy = false;

  Future<void> _doAction(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(panditScheduledConsultationsProvider(widget.panditId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startChat(
    BuildContext context,
    WidgetRef ref,
    ScheduledConsultationRequest request,
  ) async {
    // Check if scheduled time has arrived (allow 5 min early)
    final now = DateTime.now();
    final earliest = request.scheduledFor.subtract(const Duration(minutes: 5));
    if (now.isBefore(earliest)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Scheduled time hasn\'t arrived yet. Chat opens at ${_fmt(request.scheduledFor)}.',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    setState(() => _busy = true);
    try {
      final repo = ref.read(sessionRepositoryProvider);
      final user = ref.read(currentUserProvider);
      final session = await repo.startScheduledSession(
        request: request,
        currentUserId: user?.id ?? '',
        currentUserName: user?.name ?? 'Pandit',
      );
      if (mounted) {
        context.push(Routes.consultationChat, extra: session);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not start chat: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final repo = ref.read(sessionRepositoryProvider);
    final statusColor = switch (r.status) {
      ConsultationRequestStatus.pending => AppColors.warning,
      ConsultationRequestStatus.confirmed => AppColors.success,
      ConsultationRequestStatus.rescheduleProposed => AppColors.info,
      ConsultationRequestStatus.active => AppColors.success,
      ConsultationRequestStatus.ended => AppColors.textSecondary,
      ConsultationRequestStatus.expired => AppColors.warning,
      ConsultationRequestStatus.refunded => AppColors.info,
      ConsultationRequestStatus.rejected => AppColors.error,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: r.status == ConsultationRequestStatus.pending
            ? Border.all(
                color: AppColors.warning.withValues(alpha: 0.4), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: User name + status chip
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_outline,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${r.durationMinutes} min • ${r.amountLabel}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  r.status.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Schedule info
          Row(
            children: [
              const Icon(Icons.calendar_today,
                  size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                _fmt(r.scheduledFor),
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),

          if (r.proposedFor != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.schedule,
                    size: 12, color: AppColors.warning),
                const SizedBox(width: 4),
                Text(
                  'Proposed: ${_fmt(r.proposedFor!)}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.warning),
                ),
              ],
            ),
          ],

          if ((r.customerNote ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '\u{1F4AC} "${r.customerNote}"',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic),
              ),
            ),
          ],

          // Action buttons for pending requests
          if (r.status == ConsultationRequestStatus.pending && !_busy) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _doAction(() =>
                        repo.panditRespondToScheduledRequest(
                          sessionId: r.id,
                          action: 'accept',
                        )),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Accept'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final dt = await _pickDateTime(context);
                      if (dt == null) return;
                      _doAction(() =>
                          repo.panditRespondToScheduledRequest(
                            sessionId: r.id,
                            action: 'propose',
                            proposedStart: dt,
                          ));
                    },
                    icon: const Icon(Icons.schedule, size: 16),
                    label: const Text('Propose'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.info,
                      side: const BorderSide(color: AppColors.info),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  child: IconButton(
                    onPressed: () => _doAction(() =>
                        repo.panditRespondToScheduledRequest(
                          sessionId: r.id,
                          action: 'reject',
                        )),
                    icon: const Icon(Icons.close, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          AppColors.error.withValues(alpha: 0.1),
                      foregroundColor: AppColors.error,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    tooltip: 'Reject',
                  ),
                ),
              ],
            ),
          ],

          // Chat unlock for confirmed requests
          if (r.status == ConsultationRequestStatus.confirmed && !_busy) ...[
            const SizedBox(height: 12),
            if (!r.isPaid)
              const Text(
                'Waiting for user payment to unlock Chat Now.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _startChat(context, ref, r),
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: const Text('Chat Now'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
          ],

          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _fmt(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final p = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m $p';
  }

  static Future<DateTime?> _pickDateTime(BuildContext context) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      initialDate: now,
    );
    if (d == null || !context.mounted) return null;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 2))),
    );
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }
}

// ── Offline Bookings Tab ──────────────────────────────────────────────────────
//
// Shows pending offline booking requests for this pandit.
// Pandit can accept or reject each request with optional notes.

class _OfflineBookingsTab extends ConsumerStatefulWidget {
  const _OfflineBookingsTab({required this.panditId});
  final String panditId;

  @override
  ConsumerState<_OfflineBookingsTab> createState() =>
      _OfflineBookingsTabState();
}

class _OfflineBookingsTabState extends ConsumerState<_OfflineBookingsTab> {
  @override
  void initState() {
    super.initState();
    if (widget.panditId.isNotEmpty) {
      Future.microtask(() => ref
          .read(panditBookingsProvider(widget.panditId).notifier)
          .loadPendingBookings(widget.panditId));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.panditId.isEmpty) {
      return const Center(child: Text('Please login to view offline bookings.'));
    }

    final state = ref.watch(panditBookingsProvider(widget.panditId));

    // Error listener
    ref.listen<PanditBookingsState>(
        panditBookingsProvider(widget.panditId), (_, next) {
      if (next.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.error!),
          backgroundColor: AppColors.error,
        ));
      }
    });

    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.pendingBookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off_outlined,
                size: 64,
                color: AppColors.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            const Text(
              'No offline booking requests',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'When users book an offline pooja, it will appear here.',
              style: TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref
          .read(panditBookingsProvider(widget.panditId).notifier)
          .loadPendingBookings(widget.panditId),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: state.pendingBookings.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _OfflineBookingCard(
          booking: state.pendingBookings[i],
          panditId: widget.panditId,
        ),
      ),
    );
  }
}

// ── Offline Booking Card ──────────────────────────────────────────────────────

class _OfflineBookingCard extends ConsumerStatefulWidget {
  const _OfflineBookingCard({
    required this.booking,
    required this.panditId,
  });

  final OfflineBooking booking;
  final String panditId;

  @override
  ConsumerState<_OfflineBookingCard> createState() =>
      _OfflineBookingCardState();
}

class _OfflineBookingCardState extends ConsumerState<_OfflineBookingCard> {
  bool _busy = false;

  Future<void> _respond(String action) async {
    String? notes;
    if (action == 'reject') {
      final controller = TextEditingController();
      notes = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reject Booking'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Reason for rejection (optional)',
            ),
            maxLines: 2,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(ctx, controller.text.trim()),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white),
              child: const Text('Reject'),
            ),
          ],
        ),
      );
      if (notes == null && !mounted) return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(panditBookingsProvider(widget.panditId).notifier)
          .respondToBooking(
            bookingId: widget.booking.id,
            action: action, // 'accept' or 'reject'
            panditNotes: notes,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(action == 'accept'
              ? 'Booking accepted!'
              : 'Booking rejected'),
          backgroundColor:
              action == 'accept' ? AppColors.success : AppColors.error,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Action failed: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final statusColor = _offlineStatusColor(b.status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: b.status == OfflineBookingStatus.pending
            ? Border.all(
                color: Colors.orange.withValues(alpha: 0.4), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Service name + status chip
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_on,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.serviceName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (b.serviceDescription != null)
                      Text(
                        b.serviceDescription!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  b.status.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Date + Time
          Row(
            children: [
              const Icon(Icons.calendar_today,
                  size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                b.formattedDate,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.access_time,
                  size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                b.bookingTime,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              const Spacer(),
              Text(
                b.amountLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Address
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  [b.addressLine1, b.city, b.state]
                      .whereType<String>()
                      .where((s) => s.isNotEmpty)
                      .join(', '),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Special requirements
          if ((b.specialRequirements ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '\u{1F4DD} "${b.specialRequirements}"',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic),
              ),
            ),
          ],

          // Accept / Reject buttons for pending
          if (b.status == OfflineBookingStatus.pending && !_busy) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _respond('accept'),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Accept'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _respond('reject'),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Busy indicator
          if (_busy) ...[
            const SizedBox(height: 12),
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],

          // Already responded state
          if (b.status == OfflineBookingStatus.accepted) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle,
                      size: 14, color: AppColors.success),
                  SizedBox(width: 4),
                  Text('Accepted',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
          if (b.status == OfflineBookingStatus.rejected) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cancel, size: 14, color: AppColors.error),
                  SizedBox(width: 4),
                  Text('Rejected',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.error,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _offlineStatusColor(OfflineBookingStatus s) {
    switch (s) {
      case OfflineBookingStatus.pending:
        return Colors.orange;
      case OfflineBookingStatus.accepted:
        return Colors.blue;
      case OfflineBookingStatus.paid:
      case OfflineBookingStatus.confirmed:
      case OfflineBookingStatus.completed:
        return AppColors.success;
      case OfflineBookingStatus.inProgress:
        return AppColors.primary;
      case OfflineBookingStatus.rejected:
      case OfflineBookingStatus.cancelled:
        return AppColors.error;
      case OfflineBookingStatus.refunded:
        return Colors.purple;
    }
  }
}
