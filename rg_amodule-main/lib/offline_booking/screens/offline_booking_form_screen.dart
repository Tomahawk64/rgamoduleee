// lib/offline_booking/screens/offline_booking_form_screen.dart
// Booking request form with date/time slot picker

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../providers/offline_booking_provider.dart';

class OfflineBookingFormScreen extends ConsumerStatefulWidget {
  const OfflineBookingFormScreen({
    super.key,
    required this.panditId,
    required this.panditName,
    required this.serviceId,
    required this.serviceName,
    required this.serviceDescription,
    required this.amount,
  });

  final String panditId;
  final String panditName;
  final String? serviceId;
  final String serviceName;
  final String? serviceDescription;
  final double amount;

  @override
  ConsumerState<OfflineBookingFormScreen> createState() =>
      _OfflineBookingFormScreenState();
}

class _OfflineBookingFormScreenState
    extends ConsumerState<OfflineBookingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _specialRequirementsController = TextEditingController();
  final _userNotesController = TextEditingController();

  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  final List<String> _timeSlots = [
    '09:00 AM - 10:00 AM',
    '10:00 AM - 11:00 AM',
    '11:00 AM - 12:00 PM',
    '12:00 PM - 01:00 PM',
    '02:00 PM - 03:00 PM',
    '03:00 PM - 04:00 PM',
    '04:00 PM - 05:00 PM',
    '05:00 PM - 06:00 PM',
    '06:00 PM - 07:00 PM',
    '07:00 PM - 08:00 PM',
  ];

  @override
  void dispose() {
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _landmarkController.dispose();
    _specialRequirementsController.dispose();
    _userNotesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedTimeSlot = null; // Reset time slot when date changes
      });
    }
  }

  void _submitBooking() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date')),
      );
      return;
    }

    if (_selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot')),
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to continue')),
      );
      return;
    }

    final controller = ref.read(bookingCreationProvider.notifier);

    // Parse time slot
    final timeParts = _selectedTimeSlot!.split(' - ');
    final startTime = timeParts[0];

    controller.createBooking(
      userId: user.id,
      panditId: widget.panditId,
      serviceId: widget.serviceId,
      addressLine1: _addressLine1Controller.text,
      addressLine2: _addressLine2Controller.text.isEmpty
          ? null
          : _addressLine2Controller.text,
      city: _cityController.text,
      state: _stateController.text,
      pincode: _pincodeController.text,
      landmark: _landmarkController.text.isEmpty
          ? null
          : _landmarkController.text,
      bookingDate: _selectedDate!,
      bookingTime: startTime,
      serviceName: widget.serviceName,
      serviceDescription: widget.serviceDescription,
      amount: widget.amount,
      specialRequirements: _specialRequirementsController.text.isEmpty
          ? null
          : _specialRequirementsController.text,
      userNotes: _userNotesController.text.isEmpty
          ? null
          : _userNotesController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(bookingCreationProvider);

    ref.listen<BookingCreationState>(bookingCreationProvider, (previous, next) {
      if (next.booking != null && next.creating == false) {
        // Booking created — go back to browsing. Pandit must accept first.
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Booking request sent! You will be notified once the pandit accepts.'
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          // Pop back to browsing screen
          Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name == 'offline-pandits');
        }
      } else if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Book Appointment'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Pandit Info
            _buildPanditInfo(),
            const SizedBox(height: 24),

            // Service Info
            _buildServiceInfo(),
            const SizedBox(height: 24),

            // Date Selection
            _buildDateSelection(),
            const SizedBox(height: 24),

            // Time Slot Selection
            _buildTimeSlotSelection(),
            const SizedBox(height: 24),

            // Address Section
            _buildAddressSection(),
            const SizedBox(height: 24),

            // Additional Requirements
            _buildAdditionalRequirements(),
            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              onPressed: bookingState.creating ? null : _submitBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: bookingState.creating
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Submit Booking Request',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanditInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.person,
              size: 32,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pandit',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  widget.panditName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Service',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.serviceName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          if (widget.serviceDescription != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.serviceDescription!,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Amount',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '₹${widget.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Date',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedDate != null
                    ? AppColors.primary
                    : AppColors.divider,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: _selectedDate != null
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Text(
                  _selectedDate != null
                      ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                      : 'Tap to select date',
                  style: TextStyle(
                    fontSize: 16,
                    color: _selectedDate != null
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_drop_down,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSlotSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Time Slot',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_selectedDate == null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'Please select a date first',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _timeSlots.map((slot) {
              final isSelected = _selectedTimeSlot == slot;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedTimeSlot = slot;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.divider,
                    ),
                  ),
                  child: Text(
                    slot,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildAddressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Address Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _addressLine1Controller,
          decoration: const InputDecoration(
            labelText: 'Address Line 1 *',
            hintText: 'House/Flat No, Building Name',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter address line 1';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _addressLine2Controller,
          decoration: const InputDecoration(
            labelText: 'Address Line 2',
            hintText: 'Street, Area (Optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'City *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _stateController,
                decoration: const InputDecoration(
                  labelText: 'State *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _pincodeController,
          decoration: const InputDecoration(
            labelText: 'Pincode *',
            hintText: '6 digits',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          maxLength: 6,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter pincode';
            }
            if (value.length != 6) {
              return 'Please enter valid 6-digit pincode';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _landmarkController,
          decoration: const InputDecoration(
            labelText: 'Landmark (Optional)',
            hintText: 'Nearby landmark',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalRequirements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Additional Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _specialRequirementsController,
          decoration: const InputDecoration(
            labelText: 'Special Requirements (Optional)',
            hintText: 'Any specific needs or preferences',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _userNotesController,
          decoration: const InputDecoration(
            labelText: 'Notes for Pandit (Optional)',
            hintText: 'Any additional information',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
      ],
    );
  }
}
