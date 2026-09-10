import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MaterialsCache {
  static Map<String, Map<String, dynamic>>? lastData;
  static DateTime? lastRefresh;
  static const Duration cacheDuration = Duration(hours: 48);
}

/// Fetch materials from Firestore with caching + debug diagnostics.
///
/// Returns structure: {semKey: {docId: {field: value}}}
/// where docId is typically a sanitized subject name from your CSV.
///
/// - `forceServer`: when true, use Firestore Source.server to force remote fetch (ignore cache source).
/// - `fetchAll`: when true (default) fetch all semesters; otherwise requires semKey.
/// - `sampleLimit`: how many resource docs to print per semester for debugging.
Future<Map<String, Map<String, dynamic>>> getMaterialsData({
  bool fetchAll = true,
  String? semKey,
  bool forceRefresh = false,
  bool forceServer = false,
  int sampleLimit = 5,
}) async {
  final prefs = await SharedPreferences.getInstance();

  // 1) In-memory cache check
  if (!forceRefresh &&
      MaterialsCache.lastData != null &&
      MaterialsCache.lastRefresh != null &&
      DateTime.now().difference(MaterialsCache.lastRefresh!) <
          MaterialsCache.cacheDuration) {
    if (kDebugMode) debugPrint('⚡ Using in-memory materials cache (no Firestore call)');
    if (!fetchAll && semKey != null) {
      final single = <String, Map<String, dynamic>>{};
      final entry = MaterialsCache.lastData![semKey];
      if (entry != null) single[semKey] = entry;
      return single;
    }
    return MaterialsCache.lastData!;
  }

  // 2) SharedPreferences cache check
  if (!forceRefresh) {
    final String? cachedJson = prefs.getString('materials_cache');
    final int? cachedTime = prefs.getInt('materials_cache_time');

    if (cachedJson != null && cachedTime != null) {
      final savedTime = DateTime.fromMillisecondsSinceEpoch(cachedTime);
      if (DateTime.now().difference(savedTime) < MaterialsCache.cacheDuration) {
        if (kDebugMode) debugPrint('📦 Using SharedPreferences materials cache');

        final decodedRaw = jsonDecode(cachedJson) as Map<String, dynamic>;
        final decoded = decodedRaw.map((sem, value) {
          final inner = (value as Map).map((k, v) => MapEntry(k as String, Map<String, dynamic>.from(v as Map)));
          return MapEntry(sem, inner);
        });

        MaterialsCache.lastData = decoded;
        MaterialsCache.lastRefresh = savedTime;

        if (!fetchAll && semKey != null) {
          final single = <String, Map<String, dynamic>>{};
          final entry = decoded[semKey];
          if (entry != null) single[semKey] = entry;
          return single;
        }

        return decoded;
      }
    }
  }

  // 3) Fetch from Firestore (or cache if offline)
  if (kDebugMode) debugPrint('☁ Fetching materials data from Firestore (forceServer=$forceServer)...');
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final Map<String, Map<String, dynamic>> materialsMap = {};

  try {
    final connectivity = await Connectivity().checkConnectivity();
    final bool isOffline = connectivity == ConnectivityResult.none;

    // Choose source: if forceServer => server; else serverAndCache when online, cache when offline.
    final Source source = forceServer
        ? Source.server
        : (isOffline ? Source.cache : Source.serverAndCache);

    // Debug: list top-level docs in materials
    final QuerySnapshot semSnapshot = await db.collection('materials').get(GetOptions(source: source));
    if (kDebugMode) debugPrint('DEBUG: materials collection docs count = ${semSnapshot.docs.length}');
    if (kDebugMode) debugPrint('DEBUG: detected semester keys = ${semSnapshot.docs.map((d) => d.id).toList()}');
    
    if (semSnapshot.docs.isEmpty) {
      if (kDebugMode) debugPrint(isOffline
          ? '⚠️ No cached materials found (offline).'
          : '⚠️ No materials found in Firestore.');
    }

    if (fetchAll) {
      for (final semDoc in semSnapshot.docs) {
        final String semId = semDoc.id;
        final Query resourcesQuery = db.collection('materials').doc(semId).collection('resources');
        final QuerySnapshot resourcesSnapshot = await resourcesQuery.get(GetOptions(source: source));

        if (kDebugMode) debugPrint('DEBUG: -> sem="$semId", resources count=${resourcesSnapshot.docs.length}');

        final Map<String, dynamic> resourcesMap = {};
        int printed = 0;
        for (final doc in resourcesSnapshot.docs) {
          final docData = doc.data() as Map<String, dynamic>;
          resourcesMap[doc.id] = Map<String, dynamic>.from(docData);

          // Debug print sample docs - show the subject-based doc IDs
          if (printed < sampleLimit) {
            if (kDebugMode) debugPrint('DEBUG:    resource doc id = "${doc.id}" (subject-based ID from CSV)');
            if (kDebugMode) debugPrint('DEBUG:    fields: ${docData.keys.toList()}');
            
            // Print a readable preview of the document
            final preview = <String, dynamic>{};
            docData.forEach((k, v) {
              if (preview.length < 6) {
                // Truncate long values for readability
                if (v is String && v.length > 100) {
                  preview[k] = '${v.substring(0, 100)}...';
                } else if (v is List && v.length > 3) {
                  preview[k] = '[${v.take(3).join(", ")}... (${v.length} items)]';
                } else {
                  preview[k] = v;
                }
              }
            });
            if (kDebugMode) debugPrint('DEBUG:    preview: $preview');
            printed++;
          }
        }
        materialsMap[semId] = resourcesMap;
      }
    } else {
      if (semKey == null || semKey.trim().isEmpty) {
        throw ArgumentError('semKey must be provided when fetchAll is false');
      }
      final String semId = semKey;
      final Query resourcesQuery = db.collection('materials').doc(semId).collection('resources');
      final QuerySnapshot resourcesSnapshot = await resourcesQuery.get(GetOptions(source: source));
      if (kDebugMode) debugPrint('DEBUG: -> sem="$semId", resources count=${resourcesSnapshot.docs.length}');

      int printed = 0;
      final Map<String, dynamic> resourcesMap = {};
      for (final doc in resourcesSnapshot.docs) {
        final docData = doc.data() as Map<String, dynamic>;
        resourcesMap[doc.id] = Map<String, dynamic>.from(docData);
        
        if (printed < sampleLimit) {
          if (kDebugMode) debugPrint('DEBUG:    resource doc id = "${doc.id}" (subject-based ID from CSV)');
          if (kDebugMode) debugPrint('DEBUG:    fields: ${docData.keys.toList()}');
          
          final preview = <String, dynamic>{};
          docData.forEach((k, v) {
            if (preview.length < 6) {
              if (v is String && v.length > 100) {
                preview[k] = '${v.substring(0, 100)}...';
              } else if (v is List && v.length > 3) {
                preview[k] = '[${v.take(3).join(", ")}... (${v.length} items)]';
              } else {
                preview[k] = v;
              }
            }
          });
          if (kDebugMode) debugPrint('DEBUG:    preview: $preview');
          printed++;
        }
      }
      materialsMap[semId] = resourcesMap;
    }

    if (materialsMap.isNotEmpty) {
      if (kDebugMode) debugPrint('✅ Materials data fetched from ${isOffline ? 'cache' : (forceServer ? 'server (forced)' : 'server/cache')}');
      if (kDebugMode) debugPrint('✅ Total semesters loaded: ${materialsMap.keys.length}');
      if (kDebugMode) debugPrint('✅ Documents per semester: ${materialsMap.map((k, v) => MapEntry(k, v.length))}');

      // Update in-memory cache
      MaterialsCache.lastData = materialsMap;
      MaterialsCache.lastRefresh = DateTime.now();

      // Persist to SharedPreferences
      try {
        final encoded = jsonEncode(materialsMap);
        await prefs.setString('materials_cache', encoded);
        await prefs.setInt('materials_cache_time', DateTime.now().millisecondsSinceEpoch);
        if (kDebugMode) debugPrint('💾 Materials cache persisted to SharedPreferences');
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Failed to persist materials cache: $e');
      }
    } else {
      if (kDebugMode) debugPrint(isOffline ? '⚠️ No cached materials available (offline).' : '⚠️ No materials found.');
    }
  } catch (e, st) {
    if (kDebugMode) debugPrint('❌ Error fetching Firestore materials data: $e');
    if (kDebugMode) debugPrint(st);

    // fallback to in-memory cache if available
    if (MaterialsCache.lastData != null) {
      if (kDebugMode) debugPrint('⚠ Using previous in-memory materials cache.');
      if (!fetchAll && semKey != null) {
        final single = <String, Map<String, dynamic>>{};
        final entry = MaterialsCache.lastData![semKey];
        if (entry != null) single[semKey] = entry;
        return single;
      }
      return MaterialsCache.lastData!;
    }

    // fallback to SharedPreferences cache if available
    final prefsCachedJson = prefs.getString('materials_cache');
    if (prefsCachedJson != null) {
      try {
        final decodedRaw = jsonDecode(prefsCachedJson) as Map<String, dynamic>;
        final decoded = decodedRaw.map((sem, value) {
          final inner = (value as Map).map((k, v) => MapEntry(k as String, Map<String, dynamic>.from(v as Map)));
          return MapEntry(sem, inner);
        });
        if (kDebugMode) debugPrint('⚠ Using SharedPreferences materials cache as fallback.');
        MaterialsCache.lastData = decoded;
        MaterialsCache.lastRefresh = DateTime.fromMillisecondsSinceEpoch(prefs.getInt('materials_cache_time') ?? 0);
        if (!fetchAll && semKey != null) {
          final single = <String, Map<String, dynamic>>{};
          final entry = decoded[semKey];
          if (entry != null) single[semKey] = entry;
          return single;
        }
        return decoded;
      } catch (_) {
        // ignore decode errors
      }
    }
  }

  return materialsMap;
}

/// Helper function to get all subjects for a specific semester
List<Map<String, dynamic>> getSubjectsForSemester(
  Map<String, Map<String, dynamic>> materialsData,
  String semKey,
) {
  final semesterData = materialsData[semKey];
  if (semesterData == null) return [];
  
  return semesterData.entries.map((entry) {
    final subject = Map<String, dynamic>.from(entry.value);
    subject['_docId'] = entry.key; // Include the document ID for reference
    return subject;
  }).toList();
}

/// Helper function to get a specific subject's data
Map<String, dynamic>? getSubjectData(
  Map<String, Map<String, dynamic>> materialsData,
  String semKey,
  String subjectDocId,
) {
  return materialsData[semKey]?[subjectDocId];
}

/// Helper to extract subject name from document data
/// (since your CSV might have a "Subject" or "Subject Name" column)
String? getSubjectName(Map<String, dynamic> subjectData) {
  // Check common column names for subject
  for (final key in ['Subject', 'Subject Name', 'subject', 'subject_name', 'Course', 'Paper', 'Name', 'Title']) {
    if (subjectData.containsKey(key)) {
      final value = subjectData[key];
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }
  }
  return null;
}