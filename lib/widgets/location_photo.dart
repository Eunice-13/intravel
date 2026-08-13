import 'package:flutter/material.dart';

/// Resolves a location's single canonical photo path (`LocationModel
/// .imageUrl`, i.e. `site.photo` in `LocationService`) into an
/// [ImageProvider] — a network image if it's an absolute URL, otherwise a
/// bundled asset. This is the same resolution rule already used privately
/// in `location_details_screen.dart` (`_resolveImage` on both
/// `_LocationDetailsScreenState` and `_RelatedPlaceCard`), extracted here
/// so every other place that needs to show a location's photo (navigation
/// map pin popups, the reviews section) reuses the exact same source
/// instead of re-deriving it.
ImageProvider resolveLocationImage(String path) {
  return path.startsWith('http')
      ? NetworkImage(path)
      : AssetImage(path) as ImageProvider;
}

/// Renders a location's photo with the same fallback treatment used
/// throughout the app when the asset fails to load or is missing: a plain
/// colored/gradient box instead of a broken-image icon.
///
/// [fallbackColor] lets callers match their own surrounding surface (e.g.
/// `colors.forest` at reduced opacity, as `_RelatedPlaceCard` already
/// does); if omitted, a gradient close to the hero image's fallback in
/// `location_details_screen.dart` is used instead.
class LocationPhoto extends StatelessWidget {
  final String imagePath;
  final BoxFit fit;
  final Color? fallbackColor;

  const LocationPhoto({
    super.key,
    required this.imagePath,
    this.fit = BoxFit.cover,
    this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    return Image(
      image: resolveLocationImage(imagePath),
      fit: fit,
      errorBuilder: (_, __, ___) => fallbackColor != null
          ? Container(color: fallbackColor)
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF264B3C), Color(0xFF0D2820)],
                ),
              ),
            ),
    );
  }
}
