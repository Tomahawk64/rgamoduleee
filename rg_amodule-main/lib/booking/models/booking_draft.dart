import '../../packages/models/package_model.dart';
import 'booking_model.dart';
import 'time_slot_model.dart';

/// Immutable snapshot of the in-progress booking wizard.
/// Each wizard step produces a new [BookingDraft] via [copyWith].
class BookingDraft {
  const BookingDraft({
    this.package,
    this.date,
    this.slot,
    this.location,
    this.panditOption,
    this.isAutoAssign = true,
    this.notes,
  });

  final PackageModel?    package;
  final DateTime?        date;
  final TimeSlot?        slot;
  final BookingLocation? location;
  final PanditOption?    panditOption;
  final bool             isAutoAssign;
  final String?          notes;

  // ── Validation helpers ────────────────────────────────────────────────────

  bool get step0Valid => package != null;
  bool get step1Valid => date != null;
  bool get step2Valid => slot != null;
  bool get step3Valid {
    if (package == null) return false;
    if (package!.mode == PackageMode.online) return true; // no address needed
    if (location == null || location!.isOnline) return false;
    final loc = location!;
    return (loc.addressLine1?.isNotEmpty ?? false) &&
        (loc.city?.isNotEmpty ?? false) &&
        (loc.pincode?.isNotEmpty ?? false);
  }
  bool get step4Valid => panditOption != null;
  bool get readyToConfirm =>
      step0Valid && step1Valid && step2Valid && step3Valid && step4Valid;

  BookingDraft copyWith({
    PackageModel?    package,
    DateTime?        date,
    TimeSlot?        slot,
    BookingLocation? location,
    PanditOption?    panditOption,
    bool?            isAutoAssign,
    String?          notes,
  }) =>
      BookingDraft(
        package:      package      ?? this.package,
        date:         date         ?? this.date,
        slot:         slot         ?? this.slot,
        location:     location     ?? this.location,
        panditOption: panditOption ?? this.panditOption,
        isAutoAssign: isAutoAssign ?? this.isAutoAssign,
        notes:        notes        ?? this.notes,
      );

  BookingDraft clearSlot() => BookingDraft(
        package:      package,
        date:         date,
        slot:         null,
        location:     location,
        panditOption: panditOption,
        isAutoAssign: isAutoAssign,
        notes:        notes,
      );

  BookingDraft clearDateAndSlot() => BookingDraft(
        package:      package,
        date:         null,
        slot:         null,
        location:     location,
        panditOption: panditOption,
        isAutoAssign: isAutoAssign,
        notes:        notes,
      );
}
