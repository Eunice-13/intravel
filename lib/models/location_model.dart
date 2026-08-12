import 'package:latlong2/latlong.dart';

class LocationModel {
  final String id;
  final String name;
  final String subtitle;
  final String description;
  final String history;
  final String imageUrl;
  final List<String> galleryImages;
  final double rating;
  final int reviewCount;
  final LatLng coordinates;
  final String address;
  final OperatingHours operatingHours;
  final TicketInfo ticketInfo;
  final List<Review> reviews;
  final List<AccessibilityFeature> accessibilityFeatures;
  final List<NearbyAmenity> nearbyAmenities;
  final String category;
  final bool hasAudioGuide;
  final List<String> audioGuideLanguages;

  /// Short site classification shown on cards, e.g. "Fortification",
  /// "Museum", "Cathedral" — matches the Eunice-branch `type` field.
  final String type;

  /// One-line note shown under the site name on list/grid cards, e.g.
  /// "Main citadel and heritage park" — matches the branch `note` field.
  final String note;

  /// Bullet points shown under "What it offers" on the details screen.
  final List<String> highlights;

  /// Practical visiting note shown below the highlights section.
  final String visitNote;

  /// IDs of other [LocationModel]s to surface under "Related landmarks".
  final List<String> relatedPlaceIds;

  /// Realistic per-person spending range for this site (addendum spec
  /// Section 3.5): ticketed sites carry their entrance-fee range, while
  /// free sites (plazas, open landmarks, etc.) still carry a small
  /// incidental-spend range (food stalls, souvenirs, parking) rather than
  /// defaulting to ₱0 just because there's no formal entrance fee. Distinct
  /// from [ticketInfo], which reflects the official/formal admission fee
  /// only.
  final BudgetRange budgetRange;

  const LocationModel({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.history,
    required this.imageUrl,
    required this.galleryImages,
    required this.rating,
    required this.reviewCount,
    required this.coordinates,
    required this.address,
    required this.operatingHours,
    required this.ticketInfo,
    required this.reviews,
    required this.accessibilityFeatures,
    required this.nearbyAmenities,
    required this.category,
    this.hasAudioGuide = false,
    this.audioGuideLanguages = const [],
    this.type = '',
    this.note = '',
    this.highlights = const [],
    this.visitNote = '',
    this.relatedPlaceIds = const [],
    this.budgetRange = const BudgetRange(min: 0, max: 0),
  });

  bool get isOpenNow {
    final now = DateTime.now();
    final daySchedule = operatingHours.getScheduleForDay(now.weekday);
    if (daySchedule == null) return false;
    final currentMinutes = now.hour * 60 + now.minute;
    return currentMinutes >= daySchedule.openMinutes &&
        currentMinutes <= daySchedule.closeMinutes;
  }

  String get currentStatus {
    if (isOpenNow) {
      return 'Open Now';
    }
    return 'Closed';
  }
}

class OperatingHours {
  final List<DaySchedule> schedules;

  const OperatingHours({required this.schedules});

  DaySchedule? getScheduleForDay(int weekday) {
    try {
      return schedules.firstWhere((s) => s.days.contains(weekday));
    } catch (_) {
      return null;
    }
  }

  String get formattedWeekday {
    final weekdaySchedule = getScheduleForDay(DateTime.monday);
    if (weekdaySchedule == null) return 'Closed';
    return weekdaySchedule.formatted;
  }

  String get formattedWeekend {
    final weekendSchedule = getScheduleForDay(DateTime.saturday);
    if (weekendSchedule == null) return 'Closed';
    return weekendSchedule.formatted;
  }
}

class DaySchedule {
  final List<int> days;
  final int openMinutes;
  final int closeMinutes;
  final int? lastEntryMinutes;

  const DaySchedule({
    required this.days,
    required this.openMinutes,
    required this.closeMinutes,
    this.lastEntryMinutes,
  });

  String get formatted {
    final open = _formatTime(openMinutes);
    final close = _formatTime(closeMinutes);
    String result = '$open-$close';
    if (lastEntryMinutes != null) {
      result += ' (Last Entry ${_formatTime(lastEntryMinutes!)})';
    }
    return result;
  }

  String _formatTime(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final period = hours >= 12 ? 'PM' : 'AM';
    final displayHour = hours > 12 ? hours - 12 : (hours == 0 ? 12 : hours);
    if (mins == 0) return '$displayHour$period';
    return '$displayHour:${mins.toString().padLeft(2, '0')}$period';
  }
}

class TicketInfo {
  final double adultPrice;
  final double studentPrice;
  final double? childPrice;
  final double? seniorPrice;
  final String currency;
  final String? notes;

  const TicketInfo({
    required this.adultPrice,
    required this.studentPrice,
    this.childPrice,
    this.seniorPrice,
    this.currency = '₱',
    this.notes,
  });

  String get formattedAdult => '$currency${adultPrice.toInt()} adults';
  String get formattedStudent => '$currency${studentPrice.toInt()} students';
}

/// Realistic per-person spending range in PHP (addendum spec Section 3.5).
/// Used to power the Plans page budget filter and cost estimates —
/// including for sites with no formal entrance fee, which still carry a
/// small incidental-spend range rather than showing as strictly free.
class BudgetRange {
  final double min;
  final double max;

  const BudgetRange({required this.min, required this.max});

  /// Scales this range by a group-size multiplier (addendum spec 3.2):
  /// group size never filters visible sites/routes, it only scales the
  /// displayed cost estimate.
  BudgetRange scaledBy(num multiplier) {
    return BudgetRange(min: min * multiplier, max: max * multiplier);
  }

  /// Whether this range overlaps the given filter range, i.e. whether a
  /// site/route with this cost should be visible under that budget filter.
  bool overlaps(BudgetRange filter) => min <= filter.max && max >= filter.min;

  String get formatted =>
      min == max ? '₱${min.round()}' : '₱${min.round()}–₱${max.round()}';
}

class Review {
  final String id;
  final String authorName;
  final String authorPhotoUrl;
  final double rating;
  final String text;
  final DateTime publishedAt;

  const Review({
    required this.id,
    required this.authorName,
    required this.authorPhotoUrl,
    required this.rating,
    required this.text,
    required this.publishedAt,
  }) : assert(
         rating >= 1.0 && rating <= 5.0,
         'Review rating must be between 1.0 and 5.0',
       );

  Map<String, dynamic> toJson() => {
    'id': id,
    'authorName': authorName,
    'authorPhotoUrl': authorPhotoUrl,
    'rating': rating,
    'text': text,
    'publishedAt': publishedAt.toIso8601String(),
  };

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as String,
      authorName: json['authorName'] as String,
      authorPhotoUrl: json['authorPhotoUrl'] as String? ?? '',
      rating: (json['rating'] as num).toDouble(),
      text: json['text'] as String,
      publishedAt:
          DateTime.tryParse(json['publishedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Human-readable relative time (e.g. "2 weeks ago"), computed from
  /// [publishedAt] rather than stored, so it never goes stale relative to
  /// when it's actually displayed.
  String get relativeTime {
    final difference = DateTime.now().difference(publishedAt);
    if (difference.inDays >= 60) {
      final months = difference.inDays ~/ 30;
      return '$months months ago';
    }
    if (difference.inDays >= 30) return '1 month ago';
    if (difference.inDays >= 14) {
      final weeks = difference.inDays ~/ 7;
      return '$weeks weeks ago';
    }
    if (difference.inDays >= 7) return '1 week ago';
    if (difference.inDays >= 1) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    }
    if (difference.inHours >= 1) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    }
    return 'Just now';
  }
}

class AccessibilityFeature {
  final String id;
  final String name;
  final String description;
  final AccessibilityType type;
  final LatLng? location;
  final bool isActive;

  const AccessibilityFeature({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.location,
    this.isActive = true,
  });
}

enum AccessibilityType {
  ramps,
  elevators,
  brailleVoice,
  vegetarian,
  restroom,
  parking,

  /// Rest areas / seating available nearby (addendum spec Section 4.2,
  /// new mode #4 of 6).
  restAreas,

  /// Priority assistance for persons with disabilities and senior
  /// citizens (addendum spec Section 4.2, new mode #5 of 6).
  pwdSeniorPriority,

  /// Turn-by-turn directions narrated with extra descriptive detail for
  /// low-vision users (addendum spec Section 4.2, new mode #6 of 6).
  audioDescribedDirections,
}

class NearbyAmenity {
  final String name;
  final String type;
  final String distance;
  final bool isOpen;
  final LatLng coordinates;

  const NearbyAmenity({
    required this.name,
    required this.type,
    required this.distance,
    required this.isOpen,
    required this.coordinates,
  });
}
