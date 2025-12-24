import 'package:flutter/material.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/widgets/unified_background_widget.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: UnifiedBackgroundWidget(
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
                      'Terms of Service',
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
                          'Terms of Service',
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
                          '1. Agreement to Terms',
                          'These Terms of Service ("Terms", "Terms of Service") constitute a legally binding agreement between you ("User", "you", or "your") and N3RD Trivia ("Company", "we", "us", or "our") concerning your access to and use of the N3RD Trivia mobile application (the "Service").\n\n'
                              'By accessing or using our Service, you agree to be bound by these Terms. If you disagree with any part of these terms, you may not access the Service. These Terms apply to all visitors, users, and others who access or use the Service.',
                        ),

                        _buildSection(
                          context,
                          '2. Description of Service',
                          'N3RD Trivia is a mobile trivia game application that provides memory-based trivia challenges. The Service includes:\n\n'
                              '• Multiple game modes with varying difficulty levels\n'
                              '• Trivia questions across various categories\n'
                              '• Daily challenges and competitive leaderboards (Premium)\n'
                              '• Multiplayer functionality (Premium)\n'
                              '• Specialized editions and categories (Premium)\n'
                              '• User accounts with progress tracking\n'
                              '• Subscription-based access to premium features\n\n'
                              'We reserve the right to modify, suspend, or discontinue any part of the Service at any time, with or without notice.',
                        ),

                        _buildSection(
                          context,
                          '3. User Accounts and Registration',
                          'To access certain features of the Service, you must register for an account. When you register, you agree to:\n\n'
                              '• Provide accurate, current, and complete information\n'
                              '• Maintain and promptly update your account information\n'
                              '• Maintain the security of your password and identification\n'
                              '• Accept all responsibility for activity that occurs under your account\n'
                              '• Notify us immediately of any unauthorized use of your account\n'
                              '• Be at least 13 years of age (or the age of majority in your jurisdiction)\n\n'
                              'You are responsible for safeguarding your account credentials and for all activities that occur under your account. We are not liable for any loss or damage arising from your failure to comply with this section.',
                        ),

                        _buildSection(
                          context,
                          '4. Subscription Terms and Billing',
                          '**Subscription Tiers:**\n\n'
                              '**Free Tier:**\n'
                              '• Access to Classic game mode only\n'
                              '• 5 games per day (resets daily at midnight UTC)\n'
                              '• Regular trivia database only\n'
                              '• No access to editions or online features\n'
                              '• No multiplayer or daily challenges\n\n'
                              '**Basic Tier:**\n'
                              '• Access to all game modes\n'
                              '• Unlimited gameplay\n'
                              '• Regular trivia database only\n'
                              '• No editions or specialized categories\n'
                              '• No online features (multiplayer, daily challenges, leaderboards)\n\n'
                              '**Premium Tier:**\n'
                              '• All Basic tier features\n'
                              '• Access to all editions and specialized categories\n'
                              '• Online multiplayer functionality\n'
                              '• Daily challenges and competitive leaderboards\n'
                              '• Social features and friends system\n'
                              '• Early access to new features\n\n'
                              '**Billing and Payment:**\n'
                              '• Subscriptions are billed monthly or annually\n'
                              '• Payment is processed through the App Store or Google Play Store\n'
                              '• Subscriptions automatically renew unless cancelled\n'
                              '• Prices are subject to change with 30 days notice\n'
                              '• All fees are non-refundable except as required by law\n\n'
                              '**Cancellation and Refunds:**\n'
                              '• You may cancel your subscription at any time\n'
                              '• Cancellation takes effect at the end of the current billing period\n'
                              '• You will continue to have access to premium features until the end of your billing period\n'
                              '• Refunds are subject to App Store and Google Play Store policies\n'
                              '• We do not provide refunds for partial subscription periods',
                        ),

                        _buildSection(
                          context,
                          '5. Free Tier Limitations',
                          'Users on the free tier are subject to the following limitations:\n\n'
                              '• Maximum of 5 game overs per day\n'
                              '• Daily limit resets at midnight UTC\n'
                              '• Access restricted to Classic game mode only\n'
                              '• No access to other game modes (Classic II, Speed, Regular, Shuffle, Challenge, Random, Time Attack, Streak, Blitz, Marathon, Perfect, Survival, Precision)\n'
                              '• No access to editions or specialized trivia categories\n'
                              '• No access to online features including multiplayer, daily challenges, competitive leaderboards, or social features\n'
                              '• Limited to regular trivia database only\n\n'
                              'We reserve the right to modify these limitations at any time. Users exceeding the daily game limit must wait until the next day or upgrade to Basic or Premium tier.',
                        ),

                        _buildSection(
                          context,
                          '6. Acceptable Use and Prohibited Activities',
                          'You agree not to use the Service:\n\n'
                              '• For any illegal purpose or in violation of any laws\n'
                              '• To transmit any viruses, malware, or harmful code\n'
                              '• To gain unauthorized access to any part of the Service\n'
                              '• To interfere with or disrupt the Service or servers\n'
                              '• To reverse engineer, decompile, or disassemble the Service\n'
                              '• To use automated systems (bots, scripts) to access the Service\n'
                              '• To create multiple accounts to circumvent restrictions\n'
                              '• To share, sell, or transfer your account to others\n'
                              '• To impersonate any person or entity\n'
                              '• To collect or harvest information about other users\n'
                              '• To spam, harass, or abuse other users (Premium features)\n'
                              '• To violate any intellectual property rights\n'
                              '• To engage in any activity that degrades the user experience\n\n'
                              'Violation of these terms may result in immediate termination of your account without refund.',
                        ),

                        _buildSection(
                          context,
                          '7. Intellectual Property Rights',
                          '**Our Rights:**\n'
                              'The Service and its original content, features, functionality, design, logos, trademarks, and all intellectual property rights are owned by N3RD Trivia and are protected by international copyright, trademark, patent, trade secret, and other intellectual property laws.\n\n'
                              '**Your Rights:**\n'
                              'You retain ownership of any content you submit, post, or display through the Service. By submitting content, you grant us a worldwide, non-exclusive, royalty-free license to use, reproduce, modify, adapt, publish, and distribute such content solely for the purpose of providing and improving the Service.\n\n'
                              '**User-Generated Content:**\n'
                              'If the Service allows you to create, post, or share content, you are responsible for that content and warrant that you have all necessary rights to grant us the license described above.',
                        ),

                        _buildSection(
                          context,
                          '8. Limitation of Liability',
                          'TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, IN NO EVENT SHALL N3RD TRIVIA, ITS DIRECTORS, EMPLOYEES, PARTNERS, AGENTS, SUPPLIERS, OR AFFILIATES BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, INCLUDING WITHOUT LIMITATION:\n\n'
                              '• Loss of profits, data, use, goodwill, or other intangible losses\n'
                              '• Damages resulting from your use or inability to use the Service\n'
                              '• Damages resulting from unauthorized access to or use of our servers\n'
                              '• Damages resulting from any conduct or content of third parties\n'
                              '• Damages resulting from any bugs, viruses, or similar issues\n\n'
                              'THIS LIMITATION OF LIABILITY SHALL APPLY WHETHER THE DAMAGES ARISE FROM USE OR MISUSE OF THE SERVICE, FROM INABILITY TO USE THE SERVICE, OR FROM THE INTERRUPTION, SUSPENSION, OR TERMINATION OF THE SERVICE.\n\n'
                              'SOME JURISDICTIONS DO NOT ALLOW THE EXCLUSION OR LIMITATION OF INCIDENTAL OR CONSEQUENTIAL DAMAGES, SO THE ABOVE LIMITATION MAY NOT APPLY TO YOU.',
                        ),

                        _buildSection(
                          context,
                          '9. Disclaimer of Warranties',
                          'THE SERVICE IS PROVIDED ON AN "AS IS" AND "AS AVAILABLE" BASIS. TO THE MAXIMUM EXTENT PERMITTED BY LAW, N3RD TRIVIA EXPRESSLY DISCLAIMS ALL WARRANTIES OF ANY KIND, WHETHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO:\n\n'
                              '• IMPLIED WARRANTIES OF MERCHANTABILITY\n'
                              '• FITNESS FOR A PARTICULAR PURPOSE\n'
                              '• NON-INFRINGEMENT\n'
                              '• ACCURACY OR RELIABILITY OF RESULTS OBTAINED THROUGH THE SERVICE\n'
                              '• THAT THE SERVICE WILL MEET YOUR REQUIREMENTS\n'
                              '• THAT THE SERVICE WILL BE UNINTERRUPTED, TIMELY, SECURE, OR ERROR-FREE\n'
                              '• THAT DEFECTS WILL BE CORRECTED\n\n'
                              'WE DO NOT WARRANT THAT THE SERVICE, SERVERS, OR EMAIL SENT FROM US ARE FREE OF VIRUSES OR OTHER HARMFUL COMPONENTS. YOU EXPRESSLY AGREE THAT YOUR USE OF THE SERVICE IS AT YOUR SOLE RISK.',
                        ),

                        _buildSection(
                          context,
                          '10. Indemnification',
                          'You agree to defend, indemnify, and hold harmless N3RD Trivia and its licensee and licensors, and their employees, contractors, agents, officers and directors, from and against any and all claims, damages, obligations, losses, liabilities, costs or debt, and expenses (including but not limited to attorney\'s fees), resulting from or arising out of:\n\n'
                              '• Your use and access of the Service\n'
                              '• Your violation of any term of these Terms\n'
                              '• Your violation of any third party right, including without limitation any copyright, property, or privacy right\n'
                              '• Any claim that your content caused damage to a third party\n\n'
                              'This defense and indemnification obligation will survive these Terms and your use of the Service.',
                        ),

                        _buildSection(
                          context,
                          '11. Termination',
                          'We may terminate or suspend your account and bar access to the Service immediately, without prior notice or liability, under our sole discretion, for any reason whatsoever and without limitation, including but not limited to:\n\n'
                              '• A breach of the Terms\n'
                              '• Fraudulent, abusive, or illegal activity\n'
                              '• Request by law enforcement or government agencies\n'
                              '• Extended periods of inactivity\n'
                              '• Discontinuance or material modification of the Service\n'
                              '• Unexpected technical or security issues\n\n'
                              'Upon termination, your right to use the Service will immediately cease. If you wish to terminate your account, you may simply discontinue using the Service or delete your account through the app settings.\n\n'
                              'All provisions of the Terms which by their nature should survive termination shall survive termination, including, without limitation, ownership provisions, warranty disclaimers, indemnity, and limitations of liability.',
                        ),

                        _buildSection(
                          context,
                          '12. Changes to Terms',
                          'We reserve the right, at our sole discretion, to modify or replace these Terms at any time. If a revision is material, we will provide at least 30 days notice prior to any new terms taking effect. What constitutes a material change will be determined at our sole discretion.\n\n'
                              'By continuing to access or use our Service after any revisions become effective, you agree to be bound by the revised terms. If you do not agree to the new terms, you are no longer authorized to use the Service.',
                        ),

                        _buildSection(
                          context,
                          '13. Governing Law and Dispute Resolution',
                          '**Governing Law:**\n'
                              'These Terms shall be governed by and construed in accordance with the laws of the jurisdiction in which N3RD Trivia operates, without regard to its conflict of law provisions.\n\n'
                              '**Dispute Resolution:**\n'
                              'Any disputes arising out of or relating to these Terms or the Service shall be resolved through:\n\n'
                              '1. Good faith negotiations between the parties\n'
                              '2. If negotiations fail, through binding arbitration in accordance with applicable arbitration rules\n'
                              '3. Arbitration shall take place in the jurisdiction specified in these Terms\n'
                              '4. Judgment on the arbitration award may be entered in any court having jurisdiction\n\n'
                              'YOU AGREE THAT BY ENTERING INTO THESE TERMS, YOU AND N3RD TRIVIA ARE EACH WAIVING THE RIGHT TO A TRIAL BY JURY OR TO PARTICIPATE IN A CLASS ACTION.',
                        ),

                        _buildSection(
                          context,
                          '14. Severability',
                          'If any provision of these Terms is found to be unenforceable or invalid, that provision shall be limited or eliminated to the minimum extent necessary so that these Terms shall otherwise remain in full force and effect and enforceable.',
                        ),

                        _buildSection(
                          context,
                          '15. Entire Agreement',
                          'These Terms constitute the entire agreement between you and N3RD Trivia regarding the use of the Service, superseding any prior agreements between you and N3RD Trivia relating to your use of the Service.',
                        ),

                        _buildSection(
                          context,
                          '16. Contact Information',
                          'If you have any questions about these Terms of Service, please contact us:\n\n'
                              '**Email:** support@n3rdtrivia.app\n'
                              '**Subject Line:** Terms of Service Inquiry\n\n'
                              'We will make every effort to respond to your inquiry within 30 business days.',
                        ),

                        const SizedBox(height: 24),
                        Text(
                          'By using N3RD Trivia, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service. If you do not agree with any part of these Terms, you must not use the Service.',
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
