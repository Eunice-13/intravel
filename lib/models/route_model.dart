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
