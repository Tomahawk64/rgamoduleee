import 'package:flutter/material.dart';

/// Represents a bookable time slot for a service.
class TimeSlot {
  const TimeSlot({
    required this.id,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    this.isBooked = false,
  });

  final String id;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  /// Whether this slot is already taken on the selected date.
  final bool isBooked;

  TimeSlot copyWith({bool? isBooked}) => TimeSlot(
        id: id,
        startHour: startHour,
        startMinute: startMinute,
        endHour: endHour,
        endMinute: endMinute,
        isBooked: isBooked ?? this.isBooked,
      );

  TimeOfDay get start => TimeOfDay(hour: startHour, minute: startMinute);
  TimeOfDay get end   => TimeOfDay(hour: endHour,   minute: endMinute);

  String get label {
    String fmt(int h, int m) {
      final period = h < 12 ? 'AM' : 'PM';
      final hour   = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      final min    = m.toString().padLeft(2, '0');
      return '$hour:$min $period';
    }
    return '${fmt(startHour, startMinute)} – ${fmt(endHour, endMinute)}';
  }

  Map<String, dynamic> toJson() => {
        'id':           id,
        'start_hour':   startHour,
        'start_minute': startMinute,
        'end_hour':     endHour,
        'end_minute':   endMinute,
      };

  factory TimeSlot.fromJson(Map<String, dynamic> j) => TimeSlot(
        id:          j['id'] as String? ?? 'unknown',
        startHour:   (j['start_hour'] as num?)?.toInt() ?? 0,
        startMinute: (j['start_minute'] as num?)?.toInt() ?? 0,
        endHour:     (j['end_hour'] as num?)?.toInt() ?? 1,
        endMinute:   (j['end_minute'] as num?)?.toInt() ?? 0,
      );

  @override
  bool operator ==(Object other) => other is TimeSlot && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ── Standard daily slots ──────────────────────────────────────────────────────
/// Platform-wide time slot catalogue. Swap with a Supabase fetch if slots
/// become dynamic.
const kStandardTimeSlots = [
  TimeSlot(id: 'slot_0600', startHour: 6,  startMinute: 0,  endHour: 7,  endMinute: 0),
  TimeSlot(id: 'slot_0700', startHour: 7,  startMinute: 0,  endHour: 8,  endMinute: 0),
  TimeSlot(id: 'slot_0800', startHour: 8,  startMinute: 0,  endHour: 9,  endMinute: 0),
  TimeSlot(id: 'slot_0900', startHour: 9,  startMinute: 0,  endHour: 10, endMinute: 0),
  TimeSlot(id: 'slot_1000', startHour: 10, startMinute: 0,  endHour: 11, endMinute: 0),
  TimeSlot(id: 'slot_1100', startHour: 11, startMinute: 0,  endHour: 12, endMinute: 0),
  TimeSlot(id: 'slot_1200', startHour: 12, startMinute: 0,  endHour: 13, endMinute: 0),
  TimeSlot(id: 'slot_1500', startHour: 15, startMinute: 0,  endHour: 16, endMinute: 0),
  TimeSlot(id: 'slot_1600', startHour: 16, startMinute: 0,  endHour: 17, endMinute: 0),
  TimeSlot(id: 'slot_1700', startHour: 17, startMinute: 0,  endHour: 18, endMinute: 0),
  TimeSlot(id: 'slot_1800', startHour: 18, startMinute: 0,  endHour: 19, endMinute: 0),
];
