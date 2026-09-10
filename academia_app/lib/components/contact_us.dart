import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/theme_controller.dart';

class ContactUs extends StatelessWidget {
  const ContactUs({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = ThemeController.instance;
        return _buildContactSupport(context, theme);
      }
    );
  }

  Widget _buildContactSupport(BuildContext context, ThemeController theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Divider(color: theme.textSecondary.withValues(alpha: 0.1)),
          const SizedBox(height: 20),

          // Contact button
          InkWell(
            onTap: () {
              _launchUrl('https://console-x-academia.vercel.app/contactus');
            },
            borderRadius: BorderRadius.circular(15),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
              decoration: BoxDecoration(
                color: theme.primaryAccent.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: theme.primaryAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.support_agent_rounded, color: theme.primaryAccent, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    'HAVE QUERIES? CONTACT US',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Version
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final versionStr = snapshot.hasData 
                  ? 'Version ${snapshot.data!.version} • Built by Team Console'
                  : 'Built by Team Console';
              return Text(
                versionStr,
                style: TextStyle(
                  color: theme.textSecondary.withValues(alpha: 0.5),
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              );
            },
          ),
        ],
      ),
    );
  }



  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(
      uri,
      mode: LaunchMode.externalApplication, //Force open in browser
    )) {

      if (kDebugMode) debugPrint('Could not launch $url');
    }
  }
}
