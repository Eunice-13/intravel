import '../models/location_model.dart';
import 'review_service.dart';

/// A location's aggregate rating computed from its actual review list —
/// the hand-curated/seeded reviews baked into [LocationModel.reviews] plus
/// any reviews the user has submitted via [ReviewService] — rather than
/// [LocationModel.rating]'s own baked-in ~4.8 default for zero-review
/// locations (see `LocationService._buildLocation`). That default remains
/// useful elsewhere (e.g. cost/priority sorting that shouldn't be skewed
/// by missing data), but a Ratings-focused UI should be honest about
/// which locations actually have no reviews at all instead of quietly
/// reusing that placeholder — see [hasRatings].
class LocationRatingSummary {
  /// The average rating across all combined reviews, rounded to one
  /// decimal place. Meaningless (and not intended to be read) when
  /// [hasRatings] is `false` — callers should show "No ratings yet"
  /// instead of this value in that case.
  final double average;

  /// Total number of combined reviews (seeded + user-submitted) backing
  /// [average].
  final int count;

  const LocationRatingSummary({required this.average, required this.count});

  /// Whether this location has at least one real review to base a rating
  /// on. When `false`, UI should show "No ratings yet" rather than
  /// [average] (which is `0.0` in that case, not a meaningful score).
  bool get hasRatings => count > 0;
}

/// Computes [location]'s aggregate [LocationRatingSummary] by combining
/// its seeded reviews ([LocationModel.reviews]) with any the user has
/// submitted for it via [ReviewService] — the same merge
/// [LocationDetailsScreen] already performs for its own display, factored
/// out here so any other screen (e.g. a Ratings list) can compute the same
/// number consistently instead of re-deriving its own version.
LocationRatingSummary computeLocationRatingSummary(LocationModel location) {
  final userReviews = ReviewService.instance.reviewsForLocation(location.id);
  final allReviews = [...userReviews, ...location.reviews];
  if (allReviews.isEmpty) {
    return const LocationRatingSummary(average: 0.0, count: 0);
  }
  final average =
      allReviews.map((r) => r.rating).reduce((a, b) => a + b) /
      allReviews.length;
  return LocationRatingSummary(
    average: double.parse(average.toStringAsFixed(1)),
    count: allReviews.length,
  );
}
