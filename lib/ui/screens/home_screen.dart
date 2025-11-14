import 'package:flutter/material.dart';
import '../../config/ui_config.dart';

class HomeScreen extends StatelessWidget {
  final Function(int)? onNavigate;

  const HomeScreen({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          primary: false, // Don't use PrimaryScrollController
          padding: UIConfig.paddingAllLarge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tools Section
              _buildSectionHeader(context, UIConfig.textTools),
              SizedBox(height: UIConfig.spacingMedium),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: UIConfig.spacingLarge,
                mainAxisSpacing: UIConfig.spacingLarge,
                children: [
                  _buildTile(
                    context: context,
                    icon: UIConfig.iconAI,
                    title: UIConfig.textAiAssistant,
                    subtitle: UIConfig.textChatWithAi,
                    color: UIConfig.colorTileAiAssistant,
                    onTap: () => onNavigate?.call(1),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: UIConfig.fontSizeXXL,
        fontWeight: UIConfig.fontWeightBold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: UIConfig.radiusLarge,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: UIConfig.radiusLarge,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: UIConfig.borderWidthThin,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: UIConfig.paddingAllLarge,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: UIConfig.iconSizeLarge,
                color: color,
              ),
            ),
            SizedBox(height: UIConfig.spacingMedium),
            Text(
              title,
              style: TextStyle(
                fontSize: UIConfig.fontSizeMedium,
                fontWeight: UIConfig.fontWeightBold,
              ),
            ),
            SizedBox(height: UIConfig.spacingSmall * 0.5),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: UIConfig.fontSizeSmall,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
