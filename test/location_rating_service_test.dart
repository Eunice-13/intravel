import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:intravel/models/location_model.dart';
import 'package:intravel/services/location_rating_service.dart';
import 'package:intravel/services/review_service.dart';

LocationModel _buildLocation({
  required String id,
  List<Review> reviews = const [],
}) {
  return LocationModel(
    id: id,
    name: 'Test Site $id',
    subtitle: 'Intramuros, Manila',
    description: '',
    history: '',
    imageUrl: 'assets/images/placeholder.png',
    galleryImages: const [],
    rating: 4.8,
    reviewCount: reviews.length,
    coordinates: const LatLng(14.5906, 120.9750),
    address: '',
    operatingHours: const OperatingHours(schedules: []),
    ticketInfo: const TicketInfo(adultPrice: 0, studentPrice: 0),
    reviews: reviews,
    accessibilityFeatures: const [],
    nearbyAmenities: const [],
    category: 'Landmarks',
  );
}

Review _review(double rating) {
  return Review(
    id: 'r-$rating-${DateTime.now().microsecondsSinceEpoch}',
    authorName: 'Tester',
    authorPhotoUrl: '',
    rating: rating,
    text: 'Great place',
    publishedAt: DateTime.now(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // ReviewService.instance is a process-wide singleton with its own
    // "already loaded" guard; force a clean reload for each test so one
    // test's added review doesn't leak into the next.
    await ReviewService.instance.load();
  });

  group('computeLocationRatingSummary', () {
    test('reports no ratings when a location has zero seeded and zero '
        'user reviews', () {
      final location = _buildLocation(id: 'empty-loc');
      final summary = computeLocationRatingSummary(location);

      expect(summary.hasRatings, isFalse);
      expect(summary.count, 0);
    });

    test('averages seeded reviews only when there are no user reviews', () {
      final location = _buildLocation(
        id: 'seeded-loc',
        reviews: [_review(5.0), _review(3.0)],
      );
      final summary = computeLocationRatingSummary(location);

      expect(summary.hasRatings, isTrue);
      expect(summary.count, 2);
      expect(summary.average, 4.0);
    });

    test('combines seeded reviews with user-submitted reviews for the '
        'same location id', () async {
      final location = _buildLocation(
        id: 'combined-loc',
        reviews: [_review(4.0)],
      );
      await ReviewService.instance.addReview(
        locationId: 'combined-loc',
        authorName: 'Visitor',
        rating: 2.0,
        text: 'Okay visit',
      );

      final summary = computeLocationRatingSummary(location);

      expect(summary.hasRatings, isTrue);
      expect(summary.count, 2);
      expect(summary.average, 3.0);
    });

    test('user reviews submitted for a different location id do not '
        'affect this location\'s summary', () async {
      final location = _buildLocation(id: 'isolated-loc');
      await ReviewService.instance.addReview(
        locationId: 'some-other-loc',
        authorName: 'Visitor',
        rating: 1.0,
        text: 'Not related',
      );

      final summary = computeLocationRatingSummary(location);

      expect(summary.hasRatings, isFalse);
      expect(summary.count, 0);
    });
  });
}
