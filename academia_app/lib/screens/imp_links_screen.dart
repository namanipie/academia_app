import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Import for launching URLs
import '../services/imp_links_data.dart';

// --- Constants for Standard Dark Theme ---
const Color kPrimaryAccent = Color(0xFF42A5F5); // Standard Blue Accent
const Color kBackgroundColor = Colors.black;
const Color kCardColor = Color(0xFF1F1F1F); // Dark Gray for cards
const Color kTitleColor = Colors.white;
const Color kDescColor = Color(0xFFB0B0B0); // Light Gray description text

// --- links Data ---
final List<Map<String, String>> linkData = pass_imp_links();


// Main Screen Widget
class LinksScreen extends StatelessWidget {
  const LinksScreen({super.key});

  // Placeholder for link handling function (assuming url_launcher is available)
  void _handleLinkTap(String url) async{
    final Uri uri = Uri.parse(url);
      // Using externalApplication mode to open in the user's default browser
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        // In a production app, you would show a SnackBar or AlertDialog here
        // ignore: avoid_print
        if (kDebugMode) debugPrint('Could not launch $uri'); 
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        elevation: 0,
        // Title style updated to normal white text
        title: const Text(
          "Important Links",
          style: TextStyle(
            color: kTitleColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        // Added back button for previous page navigation
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTitleColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20.0),
        itemCount: linkData.length,
        itemBuilder: (context, index) {
          final data = linkData[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            // Use the new, standard link card widget
            child: _LinkCard(
              title: data["title"]!,
              description: data["desc"]!,
              url: data["url"]!,
              official: data["official"]!, // Pass official tag here
              onTap: _handleLinkTap,
            ),

          );
        },
      ),
    );
  }
}

// Custom Standard Dark Theme Card Widget (Stateless)

class _LinkCard extends StatelessWidget {
  final String title;
  final String description;
  final String url;
  final String official; // New key for official yes/no
  final void Function(String) onTap;

  const _LinkCard({
    required this.title,
    required this.description,
    required this.url,
    required this.official, // required
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kCardColor,
      borderRadius: BorderRadius.circular(20),
      elevation: 4,
      child: InkWell(
        onTap: () => onTap(url),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Title Row with Official Tag ---
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: kTitleColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (official.toLowerCase() == "yes")
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 225, 228, 228),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "Official",
                        style: TextStyle(
                          color: Color.fromARGB(255, 23, 23, 23),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),

              // --- Description ---
              Text(
                description,
                style: const TextStyle(
                  color: kDescColor,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),

              // --- Link Action / CTA ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Access Link",
                    style: TextStyle(
                      color: kPrimaryAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.link, color: kPrimaryAccent, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// Retaining the original class name structure for compatibility with user's starting code block
class MyWidget extends StatelessWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const LinksScreen();
  }
}
