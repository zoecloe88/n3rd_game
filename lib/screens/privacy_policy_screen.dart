import 'package:flutter/material.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/widgets/unified_background_widget.dart';
import 'package:n3rd_game/config/screen_animations_config.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final route = ModalRoute.of(context)?.settings.name;
    final animationPath = ScreenAnimationsConfig.getAnimationForRoute(route);

    return Scaffold(
      backgroundColor: colors.background,
      body: UnifiedBackgroundWidget(
        animationPath: animationPath,
        animationAlignment: Alignment.bottomCenter,
        animationPadding: const EdgeInsets.only(bottom: 20),
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: colors.onDarkText),
                      onPressed: () => NavigationHelper.safePop(context),
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Privacy Policy',
                      style: AppTypography.displayMedium.copyWith(
                        fontSize: 24,
                        color: colors.onDarkText,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Privacy Policy',
                          style: AppTypography.headlineLarge.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: colors.primaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Last Updated: December 18, 2024',
                          style: AppTypography.bodyMedium.copyWith(
                            fontSize: 12,
                            color: colors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 24),

                        _buildSection(
                          context,
                          '1. Introduction',
                          'N3RD Trivia ("we", "our", "us", or "the Company") operates the N3RD Trivia mobile application (the "Service"). This Privacy Policy informs you of our policies regarding the collection, use, and disclosure of personal data when you use our Service and the choices you have associated with that data.\n\n'
                              'We are committed to protecting your privacy and ensuring transparency about how we collect, use, and safeguard your information. By using our Service, you agree to the collection and use of information in accordance with this policy.',
                        ),

                        _buildSection(
                          context,
                          '2. Information We Collect',
                          'We collect several types of information for various purposes to provide and improve our Service:\n\n'
                              '**Personal Information:**\n'
                              '• Email address (required for account creation and authentication)\n'
                              '• Display name or username (optional, for personalization)\n'
                              '• Password (encrypted and stored securely)\n\n'
                              '**Game and Performance Data:**\n'
                              '• Game statistics (scores, accuracy, rounds completed)\n'
                              '• Performance metrics and achievements\n'
                              '• Game mode preferences and usage patterns\n'
                              '• Daily challenge participation and scores\n\n'
                              '**Device and Technical Information:**\n'
                              '• Device identifiers (device ID, advertising ID)\n'
                              '• Device type, model, and operating system\n'
                              '• App version and installation information\n'
                              '• IP address and general location data\n'
                              '• Crash reports and error logs\n\n'
                              '**Usage and Analytics Data:**\n'
                              '• Feature usage patterns\n'
                              '• Session duration and frequency\n'
                              '• In-app purchase history\n'
                              '• Subscription status and billing information\n\n'
                              '**Multiplayer and Social Data (Premium Users):**\n'
                              '• Room codes and multiplayer session data\n'
                              '• Friend lists and social connections\n'
                              '• Chat messages and communications (if applicable)\n'
                              '• Leaderboard rankings and competitive scores',
                        ),

                        _buildSection(
                          context,
                          '3. How We Use Your Information',
                          'We use the collected information for various purposes:\n\n'
                              '**To Provide and Maintain Our Service:**\n'
                              '• Create and manage your user account\n'
                              '• Process your transactions and manage subscriptions\n'
                              '• Deliver game content and features\n'
                              '• Enable multiplayer functionality (Premium users)\n\n'
                              '**To Improve Our Service:**\n'
                              '• Analyze usage patterns and user behavior\n'
                              '• Identify technical issues and bugs\n'
                              '• Develop new features and content\n'
                              '• Optimize game performance and user experience\n\n'
                              '**To Communicate With You:**\n'
                              '• Send technical notices and updates\n'
                              '• Respond to your inquiries and support requests\n'
                              '• Send important service-related communications\n'
                              '• Send marketing communications (with your consent)\n\n'
                              '**For Legal and Security Purposes:**\n'
                              '• Prevent fraud and abuse\n'
                              '• Enforce our terms of service\n'
                              '• Comply with legal obligations\n'
                              '• Protect our rights and safety',
                        ),

                        _buildSection(
                          context,
                          '4. Third-Party Services and Data Sharing',
                          'We use third-party services that may collect information:\n\n'
                              '**Firebase (Google):**\n'
                              '• Authentication and user management\n'
                              '• Cloud Firestore database for data storage\n'
                              '• Firebase Analytics for usage analytics\n'
                              '• Firebase Crashlytics for crash reporting\n'
                              '• Firebase Cloud Messaging for push notifications\n'
                              '• Firebase Storage for file storage\n\n'
                              '**RevenueCat:**\n'
                              '• Subscription management and billing\n'
                              '• In-app purchase processing\n'
                              '• Subscription analytics and insights\n\n'
                              'These third parties have access to your information only to perform these tasks on our behalf and are obligated not to disclose or use it for any other purpose.\n\n'
                              'We do not sell, trade, or rent your personal information to third parties for marketing purposes. We may share aggregated, non-personally identifiable information for analytics and research purposes.',
                        ),

                        _buildSection(
                          context,
                          '5. Data Storage and Security',
                          'Your data is stored on Firebase servers operated by Google Cloud Platform. These servers may be located in the United States or other countries outside your country of residence.\n\n'
                              'We implement industry-standard security measures to protect your personal information:\n\n'
                              '• Encryption of data in transit using TLS/SSL\n'
                              '• Secure password hashing (bcrypt)\n'
                              '• Authentication tokens for secure access\n'
                              '• Regular security audits and updates\n'
                              '• Access controls and authentication\n\n'
                              'However, no method of transmission over the Internet or electronic storage is 100% secure. While we strive to use commercially acceptable means to protect your personal information, we cannot guarantee absolute security.',
                        ),

                        _buildSection(
                          context,
                          '6. Data Retention',
                          'We retain your personal information for as long as your account is active or as needed to provide you services. We will retain and use your information to the extent necessary to:\n\n'
                              '• Comply with our legal obligations\n'
                              '• Resolve disputes and enforce our agreements\n'
                              '• Maintain security and prevent fraud\n'
                              '• Support business operations\n\n'
                              'If you delete your account, we will delete or anonymize your personal information within 30 days, except where we are required to retain it for legal purposes or where deletion is not immediately possible due to technical constraints.',
                        ),

                        _buildSection(
                          context,
                          '7. Your Rights and Choices',
                          'You have the following rights regarding your personal information:\n\n'
                              '**Access:** You can request access to your personal data we hold about you.\n\n'
                              '**Correction:** You can update your account information directly in the app or request corrections.\n\n'
                              '**Deletion:** You can delete your account at any time through the app settings. This will delete your personal information and game data.\n\n'
                              '**Data Portability:** You can request a copy of your data in a structured, machine-readable format.\n\n'
                              '**Opt-Out:** You can opt-out of non-essential data collection, marketing communications, and analytics where applicable.\n\n'
                              '**Account Deletion:** You can request account deletion, which will permanently delete your personal information, subject to our data retention policies.\n\n'
                              'To exercise these rights, please contact us at support@n3rdtrivia.app. We will respond to your request within 30 days.',
                        ),

                        _buildSection(
                          context,
                          '8. Children\'s Privacy',
                          'Our Service is not intended for children under 13 years of age ("Children"). We do not knowingly collect personally identifiable information from children under 13.\n\n'
                              'If you are a parent or guardian and you are aware that your child has provided us with personal information, please contact us immediately. If we become aware that we have collected personal information from children under 13 without verification of parental consent, we will take steps to delete that information from our servers.\n\n'
                              'We comply with the Children\'s Online Privacy Protection Act (COPPA) and other applicable laws regarding children\'s privacy.',
                        ),

                        _buildSection(
                          context,
                          '9. International Data Transfers',
                          'Your information may be transferred to and maintained on computers located outside of your state, province, country, or other governmental jurisdiction where data protection laws may differ from those in your jurisdiction.\n\n'
                              'If you are located outside the United States and choose to provide information to us, please note that we transfer the data to the United States and process it there.\n\n'
                              'By using our Service, you consent to the transfer of your information to our facilities and those third parties with whom we share it as described in this Privacy Policy.',
                        ),

                        _buildSection(
                          context,
                          '10. GDPR and CCPA Rights',
                          'If you are a resident of the European Economic Area (EEA) or California, you have additional rights:\n\n'
                              '**GDPR Rights (EEA Residents):**\n'
                              '• Right to be informed about data collection\n'
                              '• Right of access to your personal data\n'
                              '• Right to rectification of inaccurate data\n'
                              '• Right to erasure ("right to be forgotten")\n'
                              '• Right to restrict processing\n'
                              '• Right to data portability\n'
                              '• Right to object to processing\n'
                              '• Rights related to automated decision-making\n\n'
                              '**CCPA Rights (California Residents):**\n'
                              '• Right to know what personal information is collected\n'
                              '• Right to know if personal information is sold or disclosed\n'
                              '• Right to opt-out of sale of personal information\n'
                              '• Right to non-discrimination for exercising privacy rights\n'
                              '• Right to deletion of personal information\n\n'
                              'To exercise these rights, contact us at support@n3rdtrivia.app.',
                        ),

                        _buildSection(
                          context,
                          '11. Cookies and Tracking Technologies',
                          'We use cookies and similar tracking technologies to track activity on our Service and hold certain information. These technologies include:\n\n'
                              '• Cookies (small files stored on your device)\n'
                              '• Local Storage (browser/app storage)\n'
                              '• Analytics tags and pixels\n'
                              '• Device identifiers\n\n'
                              'You can instruct your browser or device to refuse all cookies or to indicate when a cookie is being sent. However, if you do not accept cookies, you may not be able to use some portions of our Service.',
                        ),

                        _buildSection(
                          context,
                          '12. Changes to This Privacy Policy',
                          'We may update our Privacy Policy from time to time. We will notify you of any changes by:\n\n'
                              '• Posting the new Privacy Policy on this page\n'
                              '• Updating the "Last Updated" date\n'
                              '• Sending you an email notification (for material changes)\n'
                              '• Displaying a prominent notice in the app\n\n'
                              'You are advised to review this Privacy Policy periodically for any changes. Changes to this Privacy Policy are effective when they are posted on this page.',
                        ),

                        _buildSection(
                          context,
                          '13. Contact Us',
                          'If you have any questions about this Privacy Policy, please contact us:\n\n'
                              '**Email:** support@n3rdtrivia.app\n'
                              '**Subject Line:** Privacy Policy Inquiry\n\n'
                              'We will make every effort to respond to your inquiry within 30 business days.\n\n'
                              '**Data Protection Officer (if applicable):**\n'
                              'For inquiries regarding data protection, please include "Data Protection Inquiry" in your subject line.',
                        ),

                        const SizedBox(height: 24),
                        Text(
                          'By using N3RD Trivia, you acknowledge that you have read and understood this Privacy Policy and agree to the collection and use of your information as described herein.',
                          style: AppTypography.bodyMedium.copyWith(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: colors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
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

  Widget _buildSection(BuildContext context, String title, String content) {
    final sectionColors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.headlineLarge.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: sectionColors.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 14,
              color: sectionColors.secondaryText,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
