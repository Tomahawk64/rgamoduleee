// lib/offline_booking/screens/offline_booking_tracking_screen.dart
// Screen for users to track their offline booking status

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../models/offline_booking_models.dart';
import '../providers/offline_booking_provider.dart';
import 'offline_payment_screen.dart';

class OfflineBookingTrackingScreen extends ConsumerStatefulWidget {
  const OfflineBookingTrackingScreen({super.key});

  @override
  ConsumerState<OfflineBookingTrackingScreen> createState() =>
      _OfflineBookingTrackingScreenState();
}

class _OfflineBookingTrackingScreenState
    extends ConsumerState<OfflineBookingTrackingScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        ref.read(userBookingsProvider(user.id).notifier).loadUserBookings(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text('Please login to view bookings'),
        ),
      );
    }

    final state = ref.watch(userBookingsProvider(user.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(UserBookingsState state) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              state.error!,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final user = ref.read(currentUserProvider);
                if (user != null) {
                  ref.read(userBookingsProvider(user.id).notifier).loadUserBookings(user.id);
                }
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No bookings yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Book a pandit to get started',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.bookings.length,
      itemBuilder: (context, index) {
        final booking = state.bookings[index];
        return _BookingCard(booking: booking);
      },
    );
  }
}

class _BookingCard extends ConsumerWidget {
  const _BookingCard({required this.booking});

  final OfflineBooking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor(booking.status).withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getStatusIcon(booking.status),
                  color: _getStatusColor(booking.status),
                ),
                const SizedBox(width: 8),
                Text(
                  booking.status.label,
                  style: TextStyle(
                    color: _getStatusColor(booking.status),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                if (booking.isPaid)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Paid',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          // Booking Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pandit Info
                Row(
                  children: [
                    if (booking.panditAvatarUrl != null)
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: NetworkImage(booking.panditAvatarUrl!),
                      )
                    else
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        child: Text(
                          booking.panditName?.substring(0, 2).toUpperCase() ?? '',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.panditName ?? 'Pandit',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            booking.serviceName,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Date and Time
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      booking.formattedDate,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.access_time,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      booking.bookingTime,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Address
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        booking.fullAddress,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Amount
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Amount',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      booking.amountLabel,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                
                // Contact Details (visible after payment)
                if (booking.contactVisible && booking.panditContactPhone != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pandit Contact Details',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.phone, size: 16, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(
                              booking.panditContactPhone!,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Action Buttons
                const SizedBox(height: 16),
                _buildActionButtons(context, ref, booking),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(OfflineBookingStatus status) {
    switch (status) {
      case OfflineBookingStatus.pending:
        return Colors.orange;
      case OfflineBookingStatus.accepted:
        return Colors.blue;
      case OfflineBookingStatus.paid:
      case OfflineBookingStatus.confirmed:
        return Colors.green;
      case OfflineBookingStatus.inProgress:
        return AppColors.primary;
      case OfflineBookingStatus.completed:
        return Colors.green;
      case OfflineBookingStatus.rejected:
      case OfflineBookingStatus.cancelled:
        return Colors.red;
      case OfflineBookingStatus.refunded:
        return Colors.purple;
    }
  }

  IconData _getStatusIcon(OfflineBookingStatus status) {
    switch (status) {
      case OfflineBookingStatus.pending:
        return Icons.pending;
      case OfflineBookingStatus.accepted:
        return Icons.check_circle_outline;
      case OfflineBookingStatus.paid:
      case OfflineBookingStatus.confirmed:
        return Icons.verified;
      case OfflineBookingStatus.inProgress:
        return Icons.play_circle_outline;
      case OfflineBookingStatus.completed:
        return Icons.done_all;
      case OfflineBookingStatus.rejected:
        return Icons.cancel;
      case OfflineBookingStatus.cancelled:
        return Icons.cancel_outlined;
      case OfflineBookingStatus.refunded:
        return Icons.currency_exchange;
    }
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, OfflineBooking booking) {
    if (booking.status.requiresPayment && !booking.isPaid) {
      return ElevatedButton(
        onPressed: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => OfflinePaymentScreen(
                bookingId: booking.id,
                amount: booking.amount,
                panditName: booking.panditName ?? 'Pandit',
                serviceName: booking.serviceName,
                bookingDate: booking.bookingDate,
                bookingTime: booking.bookingTime,
              ),
            ),
          );
          if (result == true && context.mounted) {
            // Reload bookings after successful payment
            final user = ref.read(currentUserProvider);
            if (user != null) {
              ref.read(userBookingsProvider(user.id).notifier).loadUserBookings(user.id);
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text('Proceed to Payment'),
      );
    }

    if (booking.status == OfflineBookingStatus.completed) {
      return OutlinedButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Write a Review'),
              content: const Text('Review functionality coming soon.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        },
        icon: const Icon(Icons.star_rate),
        label: const Text('Write a Review'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 48),
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }

    if (booking.status == OfflineBookingStatus.pending ||
        booking.status == OfflineBookingStatus.accepted) {
      return OutlinedButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Cancel Booking'),
              content: const Text('Are you sure you want to cancel this booking?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    try {
                      await ref
                          .read(offlineBookingRepositoryProvider)
                          .adminCancelBooking(booking.id, 'Cancelled by user');
                      final user = ref.read(currentUserProvider);
                      if (user != null) {
                        ref.read(userBookingsProvider(user.id).notifier).loadUserBookings(user.id);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to cancel: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
        },
        icon: const Icon(Icons.cancel_outlined),
        label: const Text('Cancel Booking'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          minimumSize: const Size(double.infinity, 48),
          side: const BorderSide(color: Colors.red),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
