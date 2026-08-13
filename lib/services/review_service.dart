import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location_model.dart';

/// Persists user-submitted reviews (spec Section 7), keyed by location ID.
///
/// [LocationService]'s hand-curated/seeded reviews (spec Section 5 dataset)
/// remain exactly where they are — this service only stores reviews a user
/// actually submits from either entry point (the location details screen's
/// "Leave a Review" action, or Settings → Reviews). Callers that want the
/// full list for a location should combine [reviewsForLocation] with
/// [LocationService]'s seeded list (see
/// `LocationDetailsScreen`/`LocationModel` usage), rather than treating this
/// service as the sole source of truth — this deliberately mirrors
/// [ItineraryService]/[SavedPlacesService]'s ChangeNotifier + SharedPreferences
/// persistence pattern used elsewhere in this app, so user reviews survive
/// app restarts (unlike the seeded reviews, which are just static in-memory
/// data with no persistence layer of their own).
class ReviewService extends ChangeNotifier {
  static final ReviewService instance = ReviewService._internal();
  ReviewService._internal();

  static const String _storageKey = 'intravel.user_reviews.v1';

  /// Location ID -> user-submitted reviews for that location.
  Map<String, List<Review>> _reviewsByLocationId = {};
  bool _isLoaded = false;

  Future<void> load() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_storageKey);
      if (stored != null && stored.isNotEmpty) {
        final decoded = jsonDecode(stored) as Map<String, dynamic>;
        _reviewsByLocationId = decoded.map(
          (locationId, reviewsJson) => MapEntry(
            locationId,
            (reviewsJson as List)
                .map((e) => Review.fromJson(e as Map<String, dynamic>))
                .toList(),
          ),
        );
      }
    } catch (_) {
      // Keep an empty map if persistence is unavailable or corrupted.
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(
        _reviewsByLocationId.map(
          (locationId, reviews) =>
              MapEntry(locationId, reviews.map((r) => r.toJson()).toList()),
        ),
      );
      await prefs.setString(_storageKey, encoded);
    } catch (_) {}
  }

  /// User-submitted reviews for [locationId], newest first. Does not
  /// include [LocationService]'s seeded reviews — combine both lists at
  /// the call site to render a location's full review list.
  List<Review> reviewsForLocation(String locationId) {
    return List.unmodifiable(
      (_reviewsByLocationId[locationId] ?? const []).reversed,
    );
  }

  /// Appends a new review to [locationId]'s list and persists it. Used by
  /// both submission entry points (location details "Leave a Review" and
  /// Settings → Reviews) so a review submitted from either place is stored
  /// and displayed identically.
  Future<Review> addReview({
    required String locationId,
    required String authorName,
    required double rating,
    required String text,
  }) async {
    final review = Review(
      id: 'user-review-${DateTime.now().microsecondsSinceEpoch}',
      authorName: authorName,
      authorPhotoUrl: '',
      rating: rating,
      text: text,
      publishedAt: DateTime.now(),
    );
    final existing = _reviewsByLocationId[locationId] ?? <Review>[];
    _reviewsByLocationId[locationId] = [...existing, review];
    notifyListeners();
    await _persist();
    return review;
  }
}
