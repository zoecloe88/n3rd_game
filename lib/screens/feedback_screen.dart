import 'package:flutter/material.dart';
import 'package:n3rd_game/utils/unawaited_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:n3rd_game/services/feedback_service.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/utils/error_helper.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'dart:io' as io;

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _controller = TextEditingController();
  final _feedbackService = FeedbackService();
  final _picker = ImagePicker();
  String _selectedType = 'bug';
  final List<File> _selectedImages = [];
  bool _isSubmitting = false;
  String? _aiSuggestion;
  bool _isLoadingSuggestion = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() {
          _selectedImages.add(File(image.path));
        });
        if (_controller.text.isNotEmpty) {
          unawaited(_getAISuggestion());
        }
      }
    } catch (e) {
      LoggerService.warning(
        'Failed to pick image from gallery in FeedbackScreen',
        error: e,
      );
      if (mounted) {
        ErrorHelper.showErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() {
          _selectedImages.add(File(image.path));
        });
        if (_controller.text.isNotEmpty) {
          unawaited(_getAISuggestion());
        }
      }
    } catch (e) {
      LoggerService.warning(
        'Failed to take photo in FeedbackScreen',
        error: e,
      );
      if (mounted) {
        ErrorHelper.showErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _getAISuggestion() async {
    if (_controller.text.isEmpty) return;

    setState(() {
      _isLoadingSuggestion = true;
      _aiSuggestion = null;
    });

    try {
      final suggestion = await _feedbackService.getTroubleshootingSuggestion(
        _controller.text,
      );
      if (mounted) {
        setState(() {
          _aiSuggestion = suggestion;
          _isLoadingSuggestion = false;
        });
      }
    } catch (e) {
      LoggerService.warning(
        'Failed to get AI suggestion in FeedbackScreen',
        error: e,
      );
      if (mounted) {
        setState(() {
          _isLoadingSuggestion = false;
          _aiSuggestion = 'Unable to generate suggestion. Please try again.';
        });
      }
    }
  }

  Future<void> _submitFeedback() async {
    if (_controller.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please describe your issue or suggestion'),
          ),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Get device info
      final deviceInfo = {
        'platform': io.Platform.operatingSystem,
        'platformVersion': io.Platform.operatingSystemVersion,
      };

      await _feedbackService.submitFeedback(
        type: _selectedType,
        message: _controller.text.trim(),
        images: _selectedImages.isNotEmpty ? _selectedImages : null,
        deviceInfo: deviceInfo,
      );

      if (mounted) {
        NavigationHelper.safePop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your feedback has been submitted.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      LoggerService.warning(
        'Failed to submit feedback in FeedbackScreen',
        error: e,
      );
      if (mounted) {
        ErrorHelper.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedbackColors = AppColors.of(context);
    return Dialog(
      backgroundColor: feedbackColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: feedbackColors.borderLight),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Submit Feedback',
                    style: AppTypography.headlineLarge.copyWith(
                      color: feedbackColors.primaryText,
                    ),
                  ),
                  const Spacer(),
                  Semantics(
                    label: AppLocalizations.of(context)?.close ?? 'Close',
                    button: true,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => NavigationHelper.safePop(context),
                      color: feedbackColors.secondaryText,
                      tooltip: AppLocalizations.of(context)?.close ?? 'Close',
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Feedback type
                    Text('Type:', style: AppTypography.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['bug', 'feature', 'error', 'question'].map((
                        type,
                      ) {
                        return Semantics(
                          label: 'Select feedback type: $type',
                          selected: _selectedType == type,
                          child: ChoiceChip(
                            label: Text(type),
                            selected: _selectedType == type,
                            onSelected: (selected) {
                              setState(() => _selectedType = type);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Description
                    Semantics(
                      label: 'Feedback description',
                      hint: 'Describe your issue or suggestion',
                      textField: true,
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          labelText: 'Describe your issue or suggestion',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: feedbackColors.cardBackgroundAlt,
                        ),
                        maxLines: 5,
                        onChanged: (_) => _getAISuggestion(),
                      ),
                    ),

                    // AI Suggestion
                    if (_isLoadingSuggestion)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            Semantics(
                              label: 'Analyzing feedback',
                              child: const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Analyzing...',
                              style: AppTypography.labelSmall,
                            ),
                          ],
                        ),
                      )
                    else if (_aiSuggestion != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.info.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.lightbulb_outline,
                                color: AppColors.info,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _aiSuggestion!,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: feedbackColors.primaryText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Image upload
                    Text(
                      'Attach Screenshots:',
                      style: AppTypography.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Gallery'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _takePhoto,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Camera'),
                          ),
                        ),
                      ],
                    ),

                    // Preview images
                    if (_selectedImages.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedImages.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      _selectedImages[index],
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedImages.removeAt(index);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.6,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: feedbackColors.borderLight),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => NavigationHelper.safePop(context),
                    child: Text('Cancel', style: AppTypography.labelLarge),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitFeedback,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: feedbackColors.primaryButton,
                      foregroundColor: feedbackColors.buttonText,
                    ),
                    child: _isSubmitting
                        ? Semantics(
                            label: 'Submitting feedback',
                            child: const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                          )
                        : Text('Submit', style: AppTypography.labelLarge),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}