import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../models/location_model.dart';
import '../services/tts_service.dart';
import '../services/location_service.dart';
import '../services/saved_places_service.dart';
import 'navigation_screen.dart';

/// Location details screen. Layout (hero + facts + history + highlights +
/// visit note + related places + save button) is ported from the
/// Eunice-branch `#details` modal, while the Visitor Reviews section and the
/// "Navigation" call-to-action are kept from the native build so the
/// existing Google Maps hookup and reviews UI still work end-to-end.
class LocationDetailsScreen extends StatefulWidget {
  final LocationModel location;

  const LocationDetailsScreen({super.key, required this.location});

  @override
  State<LocationDetailsScreen> createState() => _LocationDetailsScreenState();
}

class _LocationDetailsScreenState extends State<LocationDetailsScreen> {
  final TtsService _ttsService = TtsService();
  bool get _isSaved => SavedPlacesService.instance.isSaved(widget.location.id);

  ImageProvider _resolveImage(String path) {
    return path.startsWith('http')
        ? NetworkImage(path)
        : AssetImage(path) as ImageProvider;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SavedPlacesService.instance,
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final location = widget.location;
    final colors = AppColors.of(context);
    final related = LocationService().getRelatedLocations(location);

    return Scaffold(
      backgroundColor: colors.paper,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ─── Hero ────────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 290,
                pinned: true,
                backgroundColor: colors.forest,
                leading: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: colors.forest,
                      size: 22,
                    ),
                  ),
                ),
                actions: [
                  GestureDetector(
                    onTap: () =>
                        SavedPlacesService.instance.toggle(widget.location.id),
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _isSaved
                            ? colors.forest
                            : Colors.white.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isSaved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: _isSaved ? Colors.white : colors.forest,
                        size: 22,
                      ),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image(
                        image: _resolveImage(location.imageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF264B3C), Color(0xFF0D2820)],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x0F04120C), Color(0xD2041206)],
                            stops: [0.2, 1.0],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 18,
                        left: 24,
                        right: 24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              location.type.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              location.name,
                              style: const TextStyle(
                                fontFamily: AppTheme.serifFont,
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                height: 1.04,
                                shadows: [
                                  Shadow(
                                    color: Color(0x59000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              location.subtitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Content ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Facts (Access / Area or Hours / Ticket) ───────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _FactCard(
                              colors: colors,
                              label: 'HOURS',
                              value: location.operatingHours.formattedWeekday,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: _FactCard(
                              colors: colors,
                              label: 'TICKET',
                              value: location.ticketInfo.adultPrice == 0
                                  ? (location.ticketInfo.notes ?? 'Free')
                                  : '${location.ticketInfo.formattedAdult} /\n${location.ticketInfo.formattedStudent}',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ─── History ────────────────────────────────────────
                      Text(
                        '— History',
                        style: TextStyle(
                          color: colors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The story',
                        style: TextStyle(
                          fontFamily: AppTheme.serifFont,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        location.history,
                        style: TextStyle(
                          color: colors.ink.withValues(alpha: 0.82),
                          fontSize: 14,
                          height: 1.55,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ─── Audio Guide (kept from native build) ──────────
                      if (location.hasAudioGuide)
                        _AudioGuideCard(
                          colors: colors,
                          languages: location.audioGuideLanguages,
                          ttsService: _ttsService,
                          locationName: location.name,
                          locationDescription: location.description,
                        ),
                      if (location.hasAudioGuide) const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // ─── What it offers ─────────────────────────────────────────
              if (location.highlights.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(height: 1, color: colors.line),
                        const SizedBox(height: 20),
                        Text(
                          '— Discover',
                          style: TextStyle(
                            color: colors.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'What it offers',
                          style: TextStyle(
                            fontFamily: AppTheme.serifFont,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: colors.ink,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...location.highlights.map(
                          (h) => Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Icon(
                                    Icons.circle,
                                    size: 7,
                                    color: colors.accent,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    h,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: colors.ink.withValues(alpha: 0.82),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (location.visitNote.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE9EEE9),
                              borderRadius: BorderRadius.circular(17),
                            ),
                            child: Text(
                              location.visitNote,
                              style: const TextStyle(
                                color: Color(0xFF355348),
                                fontSize: 12,
                                height: 1.45,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              // ─── Action Buttons (Save / Share / Directions) ────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          colors: colors,
                          icon: _isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          label: _isSaved ? 'Saved' : 'Save',
                          onTap: () => SavedPlacesService.instance.toggle(
                            widget.location.id,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          colors: colors,
                          icon: Icons.share_outlined,
                          label: 'Share',
                          onTap: () => Share.share(
                            'Check out ${location.name} in ${location.subtitle}! Rating: ${location.rating}/5',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          colors: colors,
                          icon: Icons.directions_outlined,
                          label: 'Directions',
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Related landmarks ──────────────────────────────────────
              if (related.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(height: 1, color: colors.line),
                        const SizedBox(height: 20),
                        Text(
                          '— Continue exploring',
                          style: TextStyle(
                            color: colors.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Related landmarks',
                          style: TextStyle(
                            fontFamily: AppTheme.serifFont,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: colors.ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...related.map(
                          (r) => _RelatedPlaceCard(colors: colors, location: r),
                        ),
                      ],
                    ),
                  ),
                ),

              // ─── Visitor Reviews (kept from native build) ──────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 1, color: colors.line),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Visitor Reviews',
                            style: TextStyle(
                              fontFamily: AppTheme.serifFont,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: colors.ink,
                            ),
                          ),
                          if (location.reviewCount > 0)
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: AppTheme.starColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${location.rating}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: colors.ink,
                                  ),
                                ),
                                Text(
                                  ' (${location.reviewCount})',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colors.muted,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (location.reviews.isEmpty)
                        Text(
                          'No reviews yet for this location.',
                          style: TextStyle(fontSize: 13, color: colors.muted),
                        )
                      else
                        ...location.reviews.map(
                          (review) =>
                              _ReviewCard(colors: colors, review: review),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ─── Navigate Now Button (kept from native build) ──────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: colors.card,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            NavigationScreen(targetLocation: location),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.forest,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on_outlined, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Navigation',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Fact Card ──────────────────────────────────────────────────────────────────

class _FactCard extends StatelessWidget {
  final AppColors colors;
  final String label;
  final String value;

  const _FactCard({
    required this.colors,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(19),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.muted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(color: colors.forest, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }
}

// ─── Action Button ──────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final AppColors colors;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.colors,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.line),
        ),
        child: Column(
          children: [
            Icon(icon, color: colors.forest, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.ink.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Audio Guide Card ───────────────────────────────────────────────────────────

class _AudioGuideCard extends StatefulWidget {
  final AppColors colors;
  final List<String> languages;
  final TtsService ttsService;
  final String locationName;
  final String locationDescription;

  const _AudioGuideCard({
    required this.colors,
    required this.languages,
    required this.ttsService,
    required this.locationName,
    required this.locationDescription,
  });

  @override
  State<_AudioGuideCard> createState() => _AudioGuideCardState();
}

class _AudioGuideCardState extends State<_AudioGuideCard> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return GestureDetector(
      onTap: () async {
        if (_isPlaying) {
          await widget.ttsService.stop();
          setState(() => _isPlaying = false);
        } else {
          setState(() => _isPlaying = true);
          await widget.ttsService.speakLocationInfo(
            widget.locationName,
            widget.locationDescription,
          );
          setState(() => _isPlaying = false);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.forest.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.forest.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.forest.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded,
                color: colors.forest,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Audio Guide Available',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Localized narration · ${widget.languages.join(' / ')}',
                    style: TextStyle(fontSize: 12, color: colors.muted),
                  ),
                ],
              ),
            ),
            Icon(
              _isPlaying ? Icons.pause_circle : Icons.play_circle_filled,
              color: colors.forest,
              size: 32,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Related Place Card ─────────────────────────────────────────────────────────

class _RelatedPlaceCard extends StatelessWidget {
  final AppColors colors;
  final LocationModel location;

  const _RelatedPlaceCard({required this.colors, required this.location});

  ImageProvider _resolveImage(String path) {
    return path.startsWith('http')
        ? NetworkImage(path)
        : AssetImage(path) as ImageProvider;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LocationDetailsScreen(location: location),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
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
              child: Image(
                image: _resolveImage(location.imageUrl),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: colors.forest.withValues(alpha: 0.5)),
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

// ─── Review Card (kept from native build) ──────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final AppColors colors;
  final Review review;

  const _ReviewCard({required this.colors, required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colors.forest.withValues(alpha: 0.12),
                child: Text(
                  review.authorName[0],
                  style: TextStyle(
                    color: colors.forest,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.authorName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.ink,
                      ),
                    ),
                    Text(
                      review.relativeTime,
                      style: TextStyle(fontSize: 12, color: colors.muted),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < review.rating.round()
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: AppTheme.starColor,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review.text,
            style: TextStyle(
              fontSize: 13,
              color: colors.ink.withValues(alpha: 0.78),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
