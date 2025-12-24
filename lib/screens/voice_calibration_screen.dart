import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/services/voice_calibration_service.dart';
import 'package:n3rd_game/services/voice_recognition_service.dart';
import 'package:n3rd_game/services/pronunciation_dictionary_service.dart';
import 'package:n3rd_game/widgets/unified_background_widget.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_shadows.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';

class VoiceCalibrationScreen extends StatefulWidget {
  const VoiceCalibrationScreen({super.key});

  @override
  State<VoiceCalibrationScreen> createState() => _VoiceCalibrationScreenState();
}

class _VoiceCalibrationScreenState extends State<VoiceCalibrationScreen> {
  int _currentSample = 0; // 0-2 for each word (3 samples per word)
  String? _lastRecognizedText;
  bool _isRecording = false;

  @override
  Widget build(BuildContext context) {
    // RouteGuard handles subscription checking at route level

    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      body: UnifiedBackgroundWidget(
        child: SafeArea(
          child:
              Consumer3<
                VoiceCalibrationService,
                VoiceRecognitionService,
                PronunciationDictionaryService
              >(
                builder: (context, calibrationService, voiceService, pronunciationService, _) {
                  if (!calibrationService.isCalibrating) {
                    // Start calibration
                    return Center(
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppShadows.large,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.mic,
                              size: 64,
                              color: AppColors.of(context).primaryText,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Voice Calibration',
                              style: AppTypography.headlineLarge.copyWith(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.of(context).primaryText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'We\'ll ask you to speak 3 words, 3 times each. This helps us recognize your voice better.',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodyMedium.copyWith(
                                fontSize: 14,
                                color: AppColors.of(context).secondaryText,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () async {
                                await calibrationService.startCalibration(
                                  pronunciationService: pronunciationService,
                                  recognitionService: voiceService,
                                );
                                setState(() {
                                  _currentSample = 0;
                                  _lastRecognizedText = null;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.of(
                                  context,
                                ).primaryButton,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                              ),
                              child: Text(
                                'Start Calibration',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final currentWord = calibrationService
                      .getCurrentCalibrationWord();
                  final progress = calibrationService.getCalibrationProgress();

                  if (currentWord == null) {
                    // Calibration complete
                    return Center(
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppShadows.large,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 64,
                              color: Colors.green,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Calibration Complete!',
                              style: AppTypography.headlineLarge.copyWith(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.of(context).primaryText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              calibrationService.isCalibrated
                                  ? 'Your voice profile has been created successfully.'
                                  : 'Calibration accuracy was too low. Please try again.',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodyMedium.copyWith(
                                fontSize: 14,
                                color: AppColors.of(context).secondaryText,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () {
                                NavigationHelper.safePop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.of(
                                  context,
                                ).primaryButton,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                              ),
                              child: Text(
                                'Done',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                calibrationService.cancelCalibration();
                                NavigationHelper.safePop(context);
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Voice Calibration',
                                style: AppTypography.headlineLarge.copyWith(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Progress indicator
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF00D9FF),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(progress * 100).toInt()}% Complete',
                        style: AppTypography.bodyMedium.copyWith(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),

                      const Spacer(),

                      // Current word
                      Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Say this word:',
                              style: AppTypography.bodyMedium.copyWith(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              currentWord.toUpperCase(),
                              style: AppTypography.headlineLarge.copyWith(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Sample ${_currentSample + 1} of 3',
                              style: AppTypography.bodyMedium.copyWith(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Recording button
                            GestureDetector(
                              onTapDown: (_) async {
                                if (!_isRecording && voiceService.isAvailable) {
                                  setState(() {
                                    _isRecording = true;
                                    _lastRecognizedText = null;
                                  });

                                  await voiceService.startListening(
                                    onResult: (text) {
                                      if (!mounted) return;
                                      setState(() {
                                        _lastRecognizedText = text;
                                        _isRecording = false;
                                      });

                                      // Record the sample
                                      calibrationService
                                          .recordCalibrationSample(
                                            word: currentWord,
                                            recognizedText: text,
                                            recognitionService: voiceService,
                                          );

                                      // Move to next sample
                                      setState(() {
                                        _currentSample++;
                                        if (_currentSample >= 3) {
                                          _currentSample = 0;
                                          calibrationService
                                              .completeWordCalibration(
                                                currentWord,
                                              );
                                        }
                                      });
                                    },
                                  );
                                }
                              },
                              onTapUp: (_) async {
                                if (_isRecording) {
                                  await voiceService.stop();
                                  setState(() {
                                    _isRecording = false;
                                  });
                                }
                              },
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: _isRecording
                                      ? const Color(0xFFE53935)
                                      : Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 3,
                                  ),
                                ),
                                child: Icon(
                                  _isRecording ? Icons.mic : Icons.mic_none,
                                  size: 48,
                                  color: Colors.white,
                                ),
                              ),
                            ),

                            if (_lastRecognizedText != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Heard: "$_lastRecognizedText"',
                                style: AppTypography.bodyMedium.copyWith(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Instructions
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Hold the microphone button and speak the word clearly. Release when done.',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium.copyWith(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
        ),
      ),
    );
  }
}
