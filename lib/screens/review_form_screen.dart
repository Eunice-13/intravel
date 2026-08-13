import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../theme/app_theme.dart';
import '../models/location_model.dart';
import '../services/review_service.dart';
import '../widgets/location_photo.dart';

/// Shared review-submission form (spec Section 7.2), scoped to a single
/// [location] and reused by both entry points: "Leave a Review" on
/// [LocationDetailsScreen] and Settings → Reviews → pick a location. Both
/// paths submit through the same [ReviewService.addReview] call, so a
/// review left from either place appears identically on that location's
/// review list — there is exactly one submission function/data layer.
class ReviewFormScreen extends StatefulWidget {
  final LocationModel location;

  const ReviewFormScreen({super.key, required this.location});

  @override
  State<ReviewFormScreen> createState() => _ReviewFormScreenState();
}

class _ReviewFormScreenState extends State<ReviewFormScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  double _rating = 5;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(
        () => _errorMessage = 'Please write a few words about your visit.',
      );
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    final authorName = _nameController.text.trim().isEmpty
        ? 'Guest'
        : _nameController.text.trim();
    await ReviewService.instance.addReview(
      locationId: widget.location.id,
      authorName: authorName,
      rating: _rating,
      text: text,
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(25, 25, 25, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '— LEAVE A REVIEW',
                          style: TextStyle(
                            color: colors.accent,
                            fontSize: 12,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.location.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTheme.serifFont,
                            fontSize: 24,
                            color: colors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // ─── Location photo (reused from the same canonical source) ──
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: LocationPhoto(
                    imagePath: widget.location.imageUrl,
                    fallbackColor: colors.forest.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Your rating',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: RatingBar.builder(
                  initialRating: _rating,
                  minRating: 1,
                  maxRating: 5,
                  itemCount: 5,
                  allowHalfRating: false,
                  itemSize: 38,
                  itemPadding: const EdgeInsets.symmetric(horizontal: 3),
                  itemBuilder: (context, _) => const Icon(
                    Icons.star_rounded,
                    color: AppTheme.starColor,
                  ),
                  onRatingUpdate: (value) => setState(() => _rating = value),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Your name (optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nameController,
                style: TextStyle(color: colors.ink, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Guest',
                  hintStyle: TextStyle(
                    color: colors.muted.withValues(alpha: 0.7),
                  ),
                  filled: true,
                  fillColor: colors.card,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.forest),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Your review',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _textController,
                maxLines: 5,
                style: TextStyle(color: colors.ink, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Share details about your visit...',
                  hintStyle: TextStyle(
                    color: colors.muted.withValues(alpha: 0.7),
                  ),
                  filled: true,
                  fillColor: colors.card,
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.forest),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
              const SizedBox(height: 26),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.forest,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _isSubmitting ? 'Submitting…' : 'Submit Review',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
