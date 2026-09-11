import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../services/announcement_data.dart';

// -------------------------------------------------------------------
// ANNOUNCEMENT SCREEN (Stateful)
// -------------------------------------------------------------------

// Define the data type for consistency
typedef AnnouncementMap = Map<String, dynamic>;

class AnnouncementScreen extends StatefulWidget {
  const AnnouncementScreen({super.key});

  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen> {
  // Future to hold the result of the data fetch (Map of ID -> AnnouncementData)
  late Future<Map<String, AnnouncementMap>> _announcementsFuture;

  @override
  void initState() {
    super.initState();
    // Initialize the future by calling the service function
    _announcementsFuture = getEventsData();
  }

  // Helper function to launch URLs
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(
      uri,
      mode: LaunchMode.externalApplication, //Force open in browser
    )) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the link')),
        );
      }
      if (kDebugMode) debugPrint('Could not launch $url');
    }
  }


  // Helper function to parse and format the date
  String _formatDate(String dateString) {
    try {
      final parts = dateString.split('_');
      // Date format is MM_DD_YYYY
      final dateTime = DateTime(
          int.parse(parts[2]), int.parse(parts[0]), int.parse(parts[1]));
      // Format to a more readable string, e.g., 'Oct 12, 2025'
      return DateFormat('MMM dd, yyyy').format(dateTime);
    } catch (e) {
      // Return the original string if parsing fails
      return dateString.replaceAll('_', '/');
    }
  }

  // Helper function to sort announcements (Latest to Oldest)
  List<AnnouncementMap> _sortAnnouncements(List<AnnouncementMap> list) {
    list.sort((a, b) {
      // Safely access and cast the date strings
      final dateAString = a['date'] as String?;
      final dateBString = b['date'] as String?;

      if (dateAString == null || dateBString == null) return 0;

      try {
        final dateA = dateAString.split('_');
        final dateB = dateBString.split('_');

        // Create DateTime objects: DateTime(year, month, day)
        final DateTime timeA = DateTime(
            int.parse(dateA[2]), int.parse(dateA[0]), int.parse(dateA[1]));
        final DateTime timeB = DateTime(
            int.parse(dateB[2]), int.parse(dateB[0]), int.parse(dateB[1]));

        // timeB.compareTo(timeA) ensures descending order (Latest to Oldest)
        return timeB.compareTo(timeA);
      } catch (e) {
        // ignore: avoid_print
        if (kDebugMode) debugPrint('Error parsing date for sorting: $e');
        return 0;
      }
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          "Announcements",
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // Use FutureBuilder to handle loading and error states
      body: FutureBuilder<Map<String, AnnouncementMap>>(
        future: _announcementsFuture,
        builder: (context, snapshot) {
          // 1. Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          // 2. Error State
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'Error loading announcements: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                ),
              ),
            );
          }

          // 3. Data Loaded State
          final rawAnnouncementsMap = snapshot.data ?? {};
          if (rawAnnouncementsMap.isEmpty) {
            return const Center(
              child: Text(
                'No announcements found.',
                style: TextStyle(color: Colors.white54, fontSize: 18),
              ),
            );
          }

          // Convert the Map<String, AnnouncementMap> to a List<AnnouncementMap> for sorting
          final rawAnnouncementsList = rawAnnouncementsMap.values.toList();
          
          // Sort the data before building the list
          final sortedAnnouncements = _sortAnnouncements(rawAnnouncementsList);

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedAnnouncements.length,
            itemBuilder: (context, index) {
              // Access data as AnnouncementMap (Map<String, dynamic>)
              final announcement = sortedAnnouncements[index];
              final bool isAdmin = announcement["type"] == "admin";

              // Define colors based on the announcement type
              final Color cardColor = isAdmin ? Colors.black : Colors.white;
              final Color titleColor = isAdmin ? Colors.white : Colors.black87;
              final Color paraColor = isAdmin ? Colors.white70 : Colors.black54;
              final Color descColor = isAdmin ? Colors.white60 : Colors.black45;
              final Color linkColor = isAdmin ? Colors.lightBlueAccent : Colors.blue;
              final Color dateColor = isAdmin ? Colors.white54 : Colors.black38;
              final Color dividerColor = isAdmin ? Colors.white38 : Colors.black12;

              // Null-safe access and casting for string fields
              final String? date = announcement["date"] as String?;
              final String? title = announcement["title"] as String?;
              final String? para = announcement["para"] as String?;
              final String? desc = announcement["desc"] as String?;
              final String? img = announcement["img"] as String?;
              final String? link = announcement["link"] as String?;

              return Card(
                color: cardColor,
                margin: const EdgeInsets.only(bottom: 20),
                elevation: isAdmin ? 8 : 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: isAdmin
                      ? const BorderSide(color: Colors.white24, width: 1.0)
                      : BorderSide.none,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date
                      if (date != null)
                        Text(
                          _formatDate(date),
                          style: TextStyle(
                            color: dateColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                      // Title
                      if (title != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            title,
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                      // Paragraph/Subtitle
                      if (para != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            para,
                            style: TextStyle(
                              color: paraColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                      // Separator line
                      if (desc != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Divider(color: dividerColor, height: 1),
                        ),

                      // Description
                      if (desc != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            desc,
                            style: TextStyle(
                              color: descColor,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),

                      // Image
                      if (img != null && img.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              img,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 150,
                            ),
                          ),
                        ),

                      // Link
                      if (link != null && link.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: GestureDetector(
                            onTap: () => _launchUrl(link),
                            child: Text(
                              "Read More",
                              style: TextStyle(
                                color: linkColor,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                                decorationColor: linkColor,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}