import 'package:flutter/material.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/widgets/app_button.dart';
import 'package:n3rd_game/widgets/app_card.dart';
import 'package:n3rd_game/widgets/app_text_field.dart';
import 'package:n3rd_game/widgets/app_badge.dart';
import 'package:n3rd_game/widgets/app_chip.dart';

/// Component showcase screen demonstrating all standardized components
///
/// This screen serves as a reference for developers to see all available
/// components and their variants in action.
class ComponentShowcaseScreen extends StatefulWidget {
  const ComponentShowcaseScreen({super.key});

  @override
  State<ComponentShowcaseScreen> createState() =>
      _ComponentShowcaseScreenState();
}

class _ComponentShowcaseScreenState extends State<ComponentShowcaseScreen> {
  final _textController = TextEditingController();
  bool _chipSelected = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Component Showcase',
          style: AppTypography.headlineMedium,
        ),
        backgroundColor: colors.cardBackground,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _buildSection(
            context,
            'Typography',
            [
              _buildTypographyExamples(context),
            ],
          ),
          _buildSection(
            context,
            'Buttons',
            [
              _buildButtonExamples(context),
            ],
          ),
          _buildSection(
            context,
            'Cards',
            [
              _buildCardExamples(context),
            ],
          ),
          _buildSection(
            context,
            'Text Fields',
            [
              _buildTextFieldExamples(context),
            ],
          ),
          _buildSection(
            context,
            'Badges',
            [
              _buildBadgeExamples(context),
            ],
          ),
          _buildSection(
            context,
            'Chips',
            [
              _buildChipExamples(context),
            ],
          ),
          _buildSection(
            context,
            'Colors',
            [
              _buildColorExamples(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
      BuildContext context, String title, List<Widget> children,) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.headlineLarge.copyWith(
              color: colors.primaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTypographyExamples(BuildContext context) {
    return AppCard.elevated(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Display Large', style: AppTypography.displayLarge),
          const SizedBox(height: AppSpacing.sm),
          Text('Display Medium', style: AppTypography.displayMedium),
          const SizedBox(height: AppSpacing.sm),
          Text('Headline Large', style: AppTypography.headlineLarge),
          const SizedBox(height: AppSpacing.sm),
          Text('Headline Medium', style: AppTypography.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text('Title Large', style: AppTypography.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text('Title Medium', style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text('Title Small', style: AppTypography.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Text('Body Large', style: AppTypography.bodyLarge),
          const SizedBox(height: AppSpacing.sm),
          Text('Body Medium', style: AppTypography.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          Text('Body Small', style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Text('Label Large', style: AppTypography.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Text('Label Small', style: AppTypography.labelSmall),
        ],
      ),
    );
  }

  Widget _buildButtonExamples(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Primary Buttons',
          style: AppTypography.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            AppButton.primary(
              label: 'Small',
              size: AppButtonSize.small,
              onPressed: () {},
            ),
            AppButton.primary(
              label: 'Medium',
              size: AppButtonSize.medium,
              onPressed: () {},
            ),
            AppButton.primary(
              label: 'Large',
              size: AppButtonSize.large,
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Secondary Buttons',
          style: AppTypography.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            AppButton.secondary(
              label: 'Secondary',
              onPressed: () {},
            ),
            AppButton.tertiary(
              label: 'Tertiary',
              onPressed: () {},
            ),
            AppButton.text(
              label: 'Text Button',
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Icon Buttons',
          style: AppTypography.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            AppButton.icon(
              icon: Icons.add,
              onPressed: () {},
            ),
            AppButton.icon(
              icon: Icons.delete,
              onPressed: () {},
            ),
            AppButton.icon(
              icon: Icons.edit,
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Button States',
          style: AppTypography.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            AppButton.primary(
              label: 'Loading',
              isLoading: true,
              onPressed: () {},
            ),
            AppButton.primary(
              label: 'Disabled',
              onPressed: null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCardExamples(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard.elevated(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Elevated Card',
                style: AppTypography.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This is an elevated card with shadow.',
                style: AppTypography.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard.outlined(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Outlined Card',
                style: AppTypography.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This is an outlined card with border.',
                style: AppTypography.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard.filled(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filled Card',
                style: AppTypography.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This is a filled card with background.',
                style: AppTypography.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard.elevated(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Card tapped!')),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tappable Card',
                style: AppTypography.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tap this card to see interaction.',
                style: AppTypography.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextFieldExamples(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: 'Normal Field',
          hint: 'Enter text here',
          controller: _textController,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'With Icon',
          hint: 'Email address',
          leadingIcon: Icons.email,
          controller: TextEditingController(),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'With Error',
          hint: 'Enter password',
          errorText: 'Password is required',
          controller: TextEditingController(),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Disabled',
          hint: 'Cannot edit',
          enabled: false,
          controller: TextEditingController(),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'With Helper Text',
          hint: 'Enter your name',
          helperText: 'This will be displayed publicly',
          controller: TextEditingController(),
        ),
      ],
    );
  }

  Widget _buildBadgeExamples(BuildContext context) {
    return const Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        AppBadge(
          label: '5',
          variant: AppBadgeVariant.primary,
        ),
        AppBadge(
          label: 'Error',
          variant: AppBadgeVariant.error,
        ),
        AppBadge(
          label: 'Success',
          variant: AppBadgeVariant.success,
        ),
        AppBadge(
          label: 'Warning',
          variant: AppBadgeVariant.warning,
        ),
        AppBadge(
          label: 'Info',
          variant: AppBadgeVariant.info,
        ),
        AppBadge(
          label: 'Neutral',
          variant: AppBadgeVariant.neutral,
        ),
        SizedBox(width: AppSpacing.md),
        AppBadge(
          label: 'Small',
          variant: AppBadgeVariant.primary,
          size: AppBadgeSize.small,
        ),
        AppBadge(
          label: 'Medium',
          variant: AppBadgeVariant.primary,
          size: AppBadgeSize.medium,
        ),
        AppBadge(
          label: 'Large',
          variant: AppBadgeVariant.primary,
          size: AppBadgeSize.large,
        ),
      ],
    );
  }

  Widget _buildChipExamples(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            AppChip(
              label: 'Filter',
              variant: AppChipVariant.filter,
              onTap: () {},
            ),
            AppChip(
              label: 'Outlined',
              variant: AppChipVariant.outlined,
              onTap: () {},
            ),
            AppChip(
              label: 'Filled',
              variant: AppChipVariant.filled,
              onTap: () {},
            ),
            AppChip(
              label: 'Selected',
              selected: _chipSelected,
              onTap: () {
                setState(() {
                  _chipSelected = !_chipSelected;
                });
              },
            ),
            AppChip(
              label: 'With Delete',
              onDelete: () {},
            ),
            AppChip(
              label: 'With Icon',
              leadingIcon: Icons.tag,
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildColorExamples(BuildContext context) {
    final colors = AppColors.of(context);
    return AppCard.elevated(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildColorSwatch('Primary Text', colors.primaryText),
          _buildColorSwatch('Secondary Text', colors.secondaryText),
          _buildColorSwatch('Tertiary Text', colors.tertiaryText),
          _buildColorSwatch('Primary Button', colors.primaryButton),
          _buildColorSwatch('Accent', colors.accent),
          _buildColorSwatch('Success', colors.success),
          _buildColorSwatch('Error', colors.error),
          _buildColorSwatch('Warning', colors.warning),
          _buildColorSwatch('Info', colors.info),
        ],
      ),
    );
  }

  Widget _buildColorSwatch(String name, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              name,
              style: AppTypography.bodyMedium,
            ),
          ),
          Text(
            '#${((color.r * 255.0).round().clamp(0, 255)).toRadixString(16).padLeft(2, '0')}${((color.g * 255.0).round().clamp(0, 255)).toRadixString(16).padLeft(2, '0')}${((color.b * 255.0).round().clamp(0, 255)).toRadixString(16).padLeft(2, '0')}'
                .toUpperCase(),
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }
}
