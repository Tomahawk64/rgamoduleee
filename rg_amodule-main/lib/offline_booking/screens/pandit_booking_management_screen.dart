// lib/offline_booking/screens/pandit_booking_management_screen.dart
// Screen for pandits to manage booking requests (accept/reject)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../models/offline_booking_models.dart';
import '../providers/offline_booking_provider.dart';

class PanditBookingManagementScreen extends ConsumerStatefulWidget {
  const PanditBookingManagementScreen({
    super.key,
    required this.panditId,
  });

  final String panditId;

  @override
  ConsumerState<PanditBookingManagementScreen> createState() =>
      _PanditBookingManagementScreenState();
}

class _PanditBookingManagementScreenState
    extends ConsumerState<PanditBookingManagementScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(panditBookingsProvider(widget.panditId).notifier)
        .loadPendingBookings(widget.panditId);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(panditBookingsProvider(widget.panditId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Booking Requests'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(panditBookingsProvider(widget.panditId).notifier)
                  .loadPendingBookings(widget.panditId);
            },
          ),
        ],
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(PanditBookingsState state) {
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
                ref.read(panditBookingsProvider(widget.panditId).notifier)
                    .loadPendingBookings(widget.panditId);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.pendingBookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No pending requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'New booking requests will appear here',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.pendingBookings.length,
      itemBuilder: (context, index) {
        final booking = state.pendingBookings[index];
        return _BookingRequestCard(
          booking: booking,
          onAccept: () => _acceptBooking(booking),
          onReject: () => _rejectBooking(booking),
        );
      },
    );
  }

  Future<void> _acceptBooking(OfflineBooking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Service: ${booking.serviceName}'),
            Text('Date: ${booking.formattedDate}'),
            Text('Time: ${booking.bookingTime}'),
            Text('Amount: ${booking.amountLabel}'),
            const SizedBox(height: 16),
            const Text(
              'By accepting, you confirm availability for this booking.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(panditBookingsProvider(widget.panditId).notifier)
          .respondToBooking(
            bookingId: booking.id,
            action: 'accept',
          );
    }
  }

  Future<void> _rejectBooking(OfflineBooking booking) async {
    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Service: ${booking.serviceName}'),
            Text('Date: ${booking.formattedDate}'),
            Text('Time: ${booking.bookingTime}'),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Reason for rejection (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(panditBookingsProvider(widget.panditId).notifier)
          .respondToBooking(
            bookingId: booking.id,
            action: 'reject',
            panditNotes: notesController.text.isEmpty ? null : notesController.text,
      );
      notesController.dispose();
    }
  }
}

class _BookingRequestCard extends StatelessWidget {
  const _BookingRequestCard({
    required this.booking,
    required this.onAccept,
    required this.onReject,
  });

  final OfflineBooking booking;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
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
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.pending, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Pending Request',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Text(
                  booking.createdAt.toString().split(' ')[0],
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service Info
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.temple_hindu,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.serviceName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (booking.serviceDescription != null)
                            Text(
                              booking.serviceDescription!,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                
                if (booking.specialRequirements != null &&
                    booking.specialRequirements!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Special: ${booking.specialRequirements}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
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
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: onAccept,
                        icon: const Icon(Icons.check),
                        label: const Text('Accept'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
