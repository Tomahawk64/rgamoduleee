// lib/offline_booking/screens/offline_pandit_profile_screen.dart
// Screen showing detailed pandit profile with booking option

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../models/offline_booking_models.dart';
import '../providers/offline_booking_provider.dart';
import 'offline_booking_form_screen.dart';

class OfflinePanditProfileScreen extends ConsumerStatefulWidget {
  const OfflinePanditProfileScreen({
    super.key,
    required this.panditId,
  });

  final String panditId;

  @override
  ConsumerState<OfflinePanditProfileScreen> createState() =>
      _OfflinePanditProfileScreenState();
}

class _OfflinePanditProfileScreenState
    extends ConsumerState<OfflinePanditProfileScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(panditProfileProvider(widget.panditId).notifier)
          .loadAll(widget.panditId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(panditProfileProvider(widget.panditId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, state),
          if (state.loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(
                      state.error!,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else if (state.profile != null)
            _buildContent(context, state),
        ],
      ),
      bottomNavigationBar: state.profile != null && !state.loading
          ? _buildBottomBar(context, state.profile!)
          : null,
    );
  }

  Widget _buildAppBar(BuildContext context, PanditProfileState state) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: state.profile?.avatarUrl != null
            ? Image.network(
                state.profile!.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppColors.primary,
                  child: Center(
                    child: Text(
                      state.profile?.name.substring(0, 2).toUpperCase() ?? '',
                      style: const TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              )
            : Container(
                color: AppColors.primary,
                child: Center(
                  child: Text(
                    state.profile?.name.substring(0, 2).toUpperCase() ?? '',
                    style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, PanditProfileState state) {
    final profile = state.profile!;
    
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        profile.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (profile.isVerified)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, color: Colors.blue, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Verified',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  profile.location,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatChip(
                      icon: Icons.star_rounded,
                      label: profile.rating > 0 
                          ? profile.rating.toStringAsFixed(1) 
                          : 'New',
                      value: profile.totalReviews > 0 
                          ? '(${profile.totalReviews} reviews)' 
                          : 'No reviews',
                    ),
                    const SizedBox(width: 12),
                    _buildStatChip(
                      icon: Icons.work_outline,
                      label: profile.experienceLabel,
                      value: 'Experience',
                    ),
                    const SizedBox(width: 12),
                    _buildStatChip(
                      icon: Icons.calendar_today,
                      label: '${profile.totalBookings}',
                      value: 'Bookings',
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Bio Section
          _buildSection(
            title: 'About',
            child: Text(
              profile.bio ?? 'No bio available',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          
          // Languages Section
          if (profile.languages.isNotEmpty) _buildSection(
            title: 'Languages',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: profile.languages.map((lang) {
                return Chip(
                  label: Text(lang),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                  labelStyle: const TextStyle(color: AppColors.primary),
                );
              }).toList(),
            ),
          ),
          
          // Specialties Section
          if (profile.specialties.isNotEmpty) _buildSection(
            title: 'Specialties',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: profile.specialties.map((specialty) {
                return Chip(
                  label: Text(specialty),
                  backgroundColor: AppColors.secondary.withValues(alpha: 0.08),
                  labelStyle: const TextStyle(color: AppColors.secondary),
                );
              }).toList(),
            ),
          ),
          
          // Services Section
          if (state.services.isNotEmpty) _buildSection(
            title: 'Services',
            child: Column(
              children: state.services.map((service) {
                return _ServiceCard(service: service);
              }).toList(),
            ),
          ),
          
          // Reviews Section
          if (state.reviews.isNotEmpty) _buildSection(
            title: 'Reviews',
            child: Column(
              children: state.reviews.take(5).map((review) {
                return _ReviewCard(review: review);
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 100), // Space for bottom bar
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, OfflinePanditProfile profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Starting from',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '₹${profile.basePrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OfflineBookingFormScreen(
                        panditId: profile.id,
                        panditName: profile.name,
                        serviceId: null,
                        serviceName: 'General Service',
                        serviceDescription: null,
                        amount: profile.basePrice,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Book Now',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service});

  final OfflinePanditService service;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.serviceName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (service.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    service.description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (service.durationMinutes != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    service.durationLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            service.priceLabel,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final OfflinePanditReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < review.rating
                        ? Icons.star
                        : Icons.star_border,
                    color: Colors.amber,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                review.createdAt.toString().split(' ')[0],
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (review.reviewText != null) ...[
            const SizedBox(height: 8),
            Text(
              review.reviewText!,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}
