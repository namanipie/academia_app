import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

// IMPORTANT: Import Firebase Messaging for subscription management
import 'package:firebase_messaging/firebase_messaging.dart';


class ApiService {
  final String baseUrl = "https://microservice-console.onrender.com";

  // Cache Keys
  static const String _postsKey = "cached_posts_list";
  static const String _postsTimeKey = "posts_cache_timestamp";
  static const String _clubsKey = "cached_clubs_list";
  static const String _clubsTimeKey = "clubs_cache_timestamp";

  // Cache Durations
  static const int _postCacheDuration = 20 * 60 * 60 * 1000;  // 20 Hours
  static const int _clubCacheDuration = 20 * 60 * 60 * 1000; // 20 Hours

  // Timeout Durations for slow/cold-start backends
  static const Duration _defaultTimeout = Duration(seconds: 60); 
  static const Duration _uploadTimeout = Duration(seconds: 90);

  // =================================================
  // INTERNAL CACHE HELPERS
  // =================================================

  Future<void> _saveToCache(String key, String timeKey, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
    await prefs.setInt(timeKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<dynamic> _loadFromCache(String key, String timeKey, int durationMs, {bool ignoreExpiry = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final int? cachedTime = prefs.getInt(timeKey);
    final String? cachedData = prefs.getString(key);

    if (cachedTime == null || cachedData == null) return null;

    if (!ignoreExpiry) {
      final int currentTime = DateTime.now().millisecondsSinceEpoch;
      if (currentTime - cachedTime > durationMs) return null;
    }
    return jsonDecode(cachedData);
  }

  // =================================================
  // CLUB METHODS
  // =================================================

  Future<List<Club>> getClubs({bool forceRefresh = false}) async {
    if (forceRefresh) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_clubsKey);
      await prefs.remove(_clubsTimeKey);
    }

    final cached = await _loadFromCache(_clubsKey, _clubsTimeKey, _clubCacheDuration);
    if (cached != null) {
      return (cached as List).map((item) => Club.fromJson(item)).toList();
    }

    try {
      // Increased timeout to 60s for cold start
      final response = await http.get(Uri.parse('$baseUrl/clubs'))
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        List data = jsonDecode(response.body);
        await _saveToCache(_clubsKey, _clubsTimeKey, data);
        return data.map((item) => Club.fromJson(item)).toList();
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      final staleCache = await _loadFromCache(_clubsKey, _clubsTimeKey, _clubCacheDuration, ignoreExpiry: true);
      if (staleCache != null) {
        return (staleCache as List).map((item) => Club.fromJson(item)).toList();
      }
      rethrow; 
    }
  }

  Future<Club> getClubById(String clubId) async {
    final response = await http.get(Uri.parse('$baseUrl/clubs/$clubId'))
        .timeout(_defaultTimeout);
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      if (data.containsKey('error')) throw Exception(data['error']);
      return Club.fromJson(data);
    } else {
      throw Exception("Failed to load club details");
    }
  }


  Future<Map<String, dynamic>> toggleSubscription(String clubId, String email) async {
  if (kDebugMode) debugPrint("Toggling subscription for clubId: $clubId, email: $email");

  final response = await http.post(
    Uri.parse('$baseUrl/clubs/$clubId/subscribe'),
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: {'subscriber_email': email},
  ).timeout(_defaultTimeout);

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);

    if (kDebugMode) debugPrint("Subscription toggle response: $data");

    final String status = data['status'] ?? '';
    final String topic = "club_$clubId";

    try {
      if (status == "subscribed") {
        await FirebaseMessaging.instance.subscribeToTopic(topic);
        if (kDebugMode) debugPrint("✅ Subscribed to topic: $topic");
      } else if (status == "unsubscribed") {
        await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
        if (kDebugMode) debugPrint("❌ Unsubscribed from topic: $topic");
      } else {
        if (kDebugMode) debugPrint("⚠ Unknown subscription status: $status");
      }
    } catch (e) {
      if (kDebugMode) debugPrint("⚠ FCM topic update failed: $e");
    }

    return data;
  }

  throw Exception("Failed to toggle subscription");
}

  /// Auto-resubscribe to Firebase topics for clubs the user is subscribed to.
  /// Call this after app initialization, login, or when FCM token is refreshed.
  /// This ensures the user receives notifications even after app reinstall or token expiry.
  Future<void> autoResubscribeToClubs(String userEmail) async {
    if (kDebugMode) debugPrint("🔄 Starting auto-resubscription for email: $userEmail");
    
    try {
      final clubs = await getClubs(forceRefresh: true);
      
      for (var club in clubs) {
        // Check if the user is already a subscriber of this club
        if (club.subscribers.contains(userEmail)) {
          final String topic = "club_${club.id}";
          
          try {
            await FirebaseMessaging.instance.subscribeToTopic(topic);
            if (kDebugMode) debugPrint("✅ Auto-resubscribed to topic: $topic (${club.name})");
          } catch (e) {
            if (kDebugMode) debugPrint("⚠ Failed to auto-resubscribe to topic $topic: $e");
          }
        }
      }
      
      if (kDebugMode) debugPrint("✅ Auto-resubscription completed for $userEmail");
    } catch (e) {
      if (kDebugMode) debugPrint("❌ Auto-resubscription failed: $e");
      rethrow;
    }
  }

  /// Manually sync Firebase subscriptions with known subscribed clubs.
  /// Use this if you have a cached list of subscribed club IDs.
  Future<void> syncFirebaseSubscriptions(List<String> subscribedClubIds) async {
    if (kDebugMode) debugPrint("🔄 Syncing Firebase subscriptions for ${subscribedClubIds.length} club(s)");
    
    for (var clubId in subscribedClubIds) {
      final String topic = "club_$clubId";
      
      try {
        await FirebaseMessaging.instance.subscribeToTopic(topic);
        if (kDebugMode) debugPrint("✅ Synced subscription to topic: $topic");
      } catch (e) {
        if (kDebugMode) debugPrint("⚠ Failed to sync topic $topic: $e");
      }
    }
    
    if (kDebugMode) debugPrint("✅ Firebase subscription sync completed");
  }

  Future<Club> createClub({
    required String name,
    required String description,
    required List<String> coreMembers,
    required List<String> links,
    File? icon,
  }) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/clubs'));
    request.fields['name'] = name;
    request.fields['description'] = description;
    request.fields['core_members'] = coreMembers.join(',');
    request.fields['links'] = links.join(',');

    if (icon != null) {
      request.files.add(await http.MultipartFile.fromPath('icon', icon.path));
    }

    // Added 90s timeout for upload + cold start
    var streamedResponse = await request.send().timeout(_uploadTimeout);
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return Club.fromJson(jsonDecode(response.body)['club']);
    } else {
      throw Exception("Failed to create club: ${response.body}");
    }
  }

  // =================================================
  // POST METHODS
  // =================================================

  Future<Map<String, dynamic>> getPosts({int offset = 0, int limit = 20, bool forceRefresh = false}) async {
    if (forceRefresh) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_postsKey);
      await prefs.remove(_postsTimeKey);
    }

    final cachedData = await _loadFromCache(_postsKey, _postsTimeKey, _postCacheDuration);

    if (offset == 0 && cachedData != null) {
      List posts = cachedData['posts'];
      return {
        'posts': posts.map((item) => Post.fromJson(item)).toList(),
        'total': cachedData['total'],
      };
    }

    try {
      // Increased timeout to 60s
      final response = await http.get(
        Uri.parse('$baseUrl/posts?offset=$offset&limit=$limit'),
      ).timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> apiResponse = jsonDecode(response.body);
        List newPostsList = apiResponse['posts'];
        List finalPostsToCache = [];

        if (offset == 0) {
          finalPostsToCache = newPostsList;
        } else {
          List existingPosts = cachedData != null ? cachedData['posts'] : [];
          if (existingPosts.length >= 10) existingPosts.removeRange(0, 10);
          finalPostsToCache = [...existingPosts, ...newPostsList];
        }

        finalPostsToCache = await _enrichPostsWithClubData(finalPostsToCache);

        final dataToStore = {
          'posts': finalPostsToCache,
          'total': apiResponse['total'],
        };
        await _saveToCache(_postsKey, _postsTimeKey, dataToStore);

        return {
          'posts': finalPostsToCache.map((item) => Post.fromJson(item)).toList(),
          'total': apiResponse['total'],
        };
      } else {
        throw Exception("Server Error");
      }
    } catch (e) {
      final staleData = await _loadFromCache(_postsKey, _postsTimeKey, _postCacheDuration, ignoreExpiry: true);
      if (staleData != null) {
        List posts = staleData['posts'];
        return {
          'posts': posts.map((item) => Post.fromJson(item)).toList(),
          'total': staleData['total'],
        };
      }
      rethrow;
    }
  }

  Future<List<dynamic>> _enrichPostsWithClubData(List<dynamic> posts) async {
    final Set<String> clubIdsToFetch = {};
    for (var post in posts) {
      if (post['owner_individual'] == false && 
          post['id_club'] != null && 
          (post['club_name'] == null || post['club_icon_url'] == null)) {
        clubIdsToFetch.add(post['id_club']);
      }
    }

    final Map<String, Map<String, dynamic>> clubDataMap = {};
    for (var clubId in clubIdsToFetch) {
      try {
        final club = await getClubById(clubId);
        clubDataMap[clubId] = {
          'club_name': club.name,
          'club_icon_url': club.iconUrl,
        };
      } catch (e) { /* Silent fail */ }
    }

    return posts.map((post) {
      if (post['owner_individual'] == false && post['id_club'] != null) {
        final clubData = clubDataMap[post['id_club']];
        if (clubData != null) {
          post['club_name'] = clubData['club_name'];
          post['club_icon_url'] = clubData['club_icon_url'];
        }
      }
      return post;
    }).toList();
  }

  Future<List<dynamic>> getClubPosts(String clubId,
      {bool approvedOnly = false, int offset = 0, int limit = 20}) async {
    final uri = Uri.parse('$baseUrl/posts/club/$clubId?approved_only=$approvedOnly&offset=$offset&limit=$limit');
    final response = await http.get(uri).timeout(_defaultTimeout);
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data.containsKey('error')) throw Exception(data['error']);
      final List<dynamic> posts = data['posts'];
      return _enrichPostsWithClubData(posts);
    } else {
      throw Exception("Failed to load club posts");
    }
  }

  Future<Post> createPost({
    required bool ownerIndividual,
    required String content,
    String? idClub,
    String clubPass = "",
    String individualEmail = "",
    String expiryTime = "",
    List<File>? images,
    bool sendEmail = false,
    bool sendNotification = true,
  }) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/posts'));
    request.fields['owner_individual'] = ownerIndividual.toString();
    request.fields['content'] = content;
    if (idClub != null) request.fields['id_club'] = idClub;
    request.fields['club_pass'] = clubPass;
    request.fields['individual_email'] = individualEmail;
    request.fields['expiry_time'] = expiryTime;
    request.fields['send_email'] = sendEmail.toString();
    request.fields['send_notification'] = sendNotification.toString();

    if (images != null) {
      for (var file in images) {
        request.files.add(await http.MultipartFile.fromPath('images', file.path));
      }
    }

    // Added 90s timeout for image uploads + cold start
    var streamedResponse = await request.send().timeout(_uploadTimeout);
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return Post.fromJson(jsonDecode(response.body)['post']);
    } else {
      throw Exception("Failed to create post: ${response.body}");
    }
  }

  Future<Post> getPostById(String postId) async {
    final response = await http.get(Uri.parse('$baseUrl/posts/$postId')).timeout(_defaultTimeout);
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      if (data.containsKey('error')) throw Exception(data['error']);
      return Post.fromJson(data);
    } else {
      throw Exception("Failed to load post");
    }
  }

  Future<Map<String, dynamic>> toggleLike(String postId, String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/posts/$postId/like'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'user_email': email},
    ).timeout(_defaultTimeout);

    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception("Failed to toggle like");
  }

  Future<void> deletePost(String postId) async {
    final response = await http.delete(Uri.parse('$baseUrl/posts/$postId')).timeout(_defaultTimeout);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] != 'deleted') throw Exception("Delete failed");
    } else {
      throw Exception("Failed to delete post");
    }
  }

  Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_postsKey);
    await prefs.remove(_postsTimeKey);
    await prefs.remove(_clubsKey);
    await prefs.remove(_clubsTimeKey);
  }
}