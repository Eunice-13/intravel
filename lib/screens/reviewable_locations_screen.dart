import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/location_model.dart';
import '../services/location_service.dart';
import '../widgets/location_photo.dart';
import 'review_form_screen.dart';

/// Settings → Reviews (spec Section 7.1.2): lists every reviewable
/// location, reusing [LocationService]'s existing dataset — the same one
/// every other screen in the app draws from — rather than a second,
/// separately-maintained list. Selecting a location opens the exact same
/// [ReviewFormScreen] used by the "Leave a Review" action on the location
/// details screen, pre-scoped to that location, so both entry points
/// submit through the same data layer.
class ReviewableLocationsScreen extends StatelessWidget {
  const ReviewableLocationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final locations = LocationService().getAllLocations();

    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 25, 25, 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Text(
                      '‹',
                      style: TextStyle(
                        fontSize: 36,
                        height: 1,
                        color: colors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '— SETTINGS',
                        style: TextStyle(
                          color: colors.accent,
                          fontSize: 12,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reviews',
                        style: TextStyle(
                          fontFamily: AppTheme.serifFont,
                          fontSize: 27,
                          color: colors.ink,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Text(
                'Pick a location to leave a review for.',
                style: TextStyle(fontSize: 13, color: colors.muted),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(25, 0, 25, 24),
                itemCount: locations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 11),
                itemBuilder: (context, index) => _ReviewableLocationCard(
                  colors: colors,
                  location: locations[index],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewableLocationCard extends StatelessWidget {
  final AppColors colors;
  final LocationModel location;

  const _ReviewableLocationCard({
    required this.colors,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReviewFormScreen(location: location),
          ),
        );
      },
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: colors.forest,
          borderRadius: BorderRadius.circular(17),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 58,
              height: 72,
              child: LocationPhoto(
                imagePath: location.imageUrl,
                fallbackColor: colors.forest.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    location.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    location.note,
                    style: const TextStyle(
                      color: Color(0xFFD7E4DC),
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 14),
              child: Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
