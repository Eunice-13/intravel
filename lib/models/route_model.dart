class CuratedRoute {
  final String id;
  final String name;
  final String emoji;
  final String groupSize;
  final String priceRange;
  final String duration;
  final String category;

  /// Amount added to the running budget total when this route is tapped,
  /// mirroring the `data-price` attribute on the branch's `.route` buttons.
  final int addToBudget;
  final List<String> locationIds;

  /// Site categories (matching [LocationModel.category] values) used to
  /// pull qualifying sites when generating plan options for this route
  /// (addendum spec 3.4). Distinct from [category], which is only used for
  /// the Plans page's own category-chip filter.
  final List<String> qualifyingCategories;

  /// Estimated total duration in hours for a generated plan built from
  /// this route, e.g. 4.0 for "~4 hrs".
  final double hours;

  /// Optional cap on a qualifying site's per-person budget max, used by
  /// routes like "Student's Budget Tour" that should only pull
  /// lower-cost sites regardless of category.
  final double? maxPerPersonBudget;

  const CuratedRoute({
    required this.id,
    required this.name,
    required this.emoji,
    required this.groupSize,
    required this.priceRange,
    required this.duration,
    required this.category,
    this.addToBudget = 0,
    this.locationIds = const [],
    this.qualifyingCategories = const [],
    this.hours = 2,
    this.maxPerPersonBudget,
  });
}

class TransportOption {
  final String id;
  final String name;
  final String emoji;
  final String pricing;
  final String? discountNote;
  final String? legalNote;

  const TransportOption({
    required this.id,
    required this.name,
    required this.emoji,
    required this.pricing,
    this.discountNote,
    this.legalNote,
  });
}
