import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:academia_app/club_events_social/models/models.dart';
import 'package:academia_app/club_events_social/services/club_main_service.dart';
import 'package:academia_app/club_events_social/screens/group_about_screen.dart';

//for link redirects and @mentions
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';



class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback? onLikeToggled;
  final VoidCallback? onDeleted;

  const PostCard({
    super.key,
    required this.post,
    this.onLikeToggled,
    this.onDeleted,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ApiService _api = ApiService();
  final PageController _pageController = PageController();
  
  late AnimationController _heartAnimationController;
  late Animation<double> _heartScale;

  late List<String> _likes;
  bool _isLiking = false;
  bool _isBookmarked = false;
  bool _isPressed = false;
  bool _isNavigating = false; // Prevents multiple API calls for navigation
  int _currentPage = 0;
  String? _currentUserTruncatedEmail;
  Club? _clubData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _likes = List.from(widget.post.likes);
    _loadInitialState();
    
    _heartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _heartAnimationController, curve: Curves.easeInOut));

    if (!widget.post.ownerIndividual && widget.post.clubName != null) {
      _clubData = Club(
        id: widget.post.idClub ?? '',
        name: widget.post.clubName ?? '',
        description: '',
        iconUrl: widget.post.clubIconUrl,
        bannerUrl: null,
        coreMembers: [],
        links: [],
        subscribers: [],
        postIds: []
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadLikesFromCache();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartAnimationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialState() async {
    final prefs = await SharedPreferences.getInstance();
    final fullEmail = prefs.getString('userEmail');
    if (fullEmail != null) {
      setState(() => _currentUserTruncatedEmail = _truncateEmail(fullEmail));
    }

    final List<String> bookmarkedJsonList = prefs.getStringList('user_bookmarks') ?? [];
    bool exists = bookmarkedJsonList.any((jsonStr) {
      final Map<String, dynamic> map = jsonDecode(jsonStr);
      return map['post_id'] == widget.post.postId;
    });

    // Load likes from local cache
    await _loadLikesFromCache();

    setState(() => _isBookmarked = exists);
  }

  Future<void> _loadLikesFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedString = prefs.getString('cached_posts_list');
    if (cachedString == null) return;

    try {
      Map<String, dynamic> cachedData = jsonDecode(cachedString);
      List<dynamic> posts = cachedData['posts'] ?? [];

      // Find the post and load its likes
      for (var post in posts) {
        if (post['post_id'] == widget.post.postId) {
          final List<String> cachedLikes = List<String>.from(post['likes'] ?? []);
          if (mounted) {
            setState(() => _likes = cachedLikes);
          }
          return;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error loading likes from cache: $e");
    }
  }

  String _truncateEmail(String email) => email.contains('@') ? email.split('@')[0] : email;
  bool _isLikedByUser() => _currentUserTruncatedEmail != null && _likes.contains(_currentUserTruncatedEmail);

  Future<void> _handleDoubleTap() async {
    if (!_isLikedByUser()) {
      _toggleLike();
    }
    _heartAnimationController.forward().then((value) => _heartAnimationController.reverse());
  }

  Future<void> _toggleBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> bookmarkedJsonList = prefs.getStringList('user_bookmarks') ?? [];

    if (_isBookmarked) {
      bookmarkedJsonList.removeWhere((jsonStr) => jsonDecode(jsonStr)['post_id'] == widget.post.postId);
      _showSnackbar("Removed from bookmarks");
    } else {
      bookmarkedJsonList.add(jsonEncode(widget.post.toJson()));
      _showSnackbar("Saved to bookmarks");
    }

    await prefs.setStringList('user_bookmarks', bookmarkedJsonList);
    setState(() => _isBookmarked = !_isBookmarked);
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF1A1A1A),
      ),
    );
  }

  Future<void> _updatePostInLocalCache(bool isLiked) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedString = prefs.getString('cached_posts_list');
    if (cachedString == null) return;

    try {
      Map<String, dynamic> cachedData = jsonDecode(cachedString);
      List<dynamic> posts = cachedData['posts'] ?? [];

      // Find and update the post
      for (var i = 0; i < posts.length; i++) {
        if (posts[i]['post_id'] == widget.post.postId) {
          List<String> likes = List<String>.from(posts[i]['likes'] ?? []);
          if (isLiked) {
            if (!likes.contains(_currentUserTruncatedEmail)) {
              likes.add(_currentUserTruncatedEmail!);
            }
          } else {
            likes.remove(_currentUserTruncatedEmail);
          }
          posts[i]['likes'] = likes;
          break;
        }
      }

      cachedData['posts'] = posts;
      await prefs.setString('cached_posts_list', jsonEncode(cachedData));
    } catch (e) {
      if (kDebugMode) debugPrint("Error updating post in local cache: $e");
    }
  }

  Future<void> _toggleLike() async {
    if (_isLiking || _currentUserTruncatedEmail == null){

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please log in to Like posts"),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() => _isLiking = true);
    try {
      final response = await _api.toggleLike(widget.post.postId, _currentUserTruncatedEmail!);
      if (mounted) {
        final bool isNowLiked = response['status'] == 'liked';
        setState(() {
          if (isNowLiked) {
            _likes.add(_currentUserTruncatedEmail!);
          } else {
            _likes.remove(_currentUserTruncatedEmail!);
          }
        });
        // Update local storage with the new like status
        await _updatePostInLocalCache(isNowLiked);
        widget.onLikeToggled?.call();
      }
    } catch (e) {
      _showSnackbar("Failed to like post.", isError: true);
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  // UPDATED: Navigation with lock and loading indicator
  Future<void> _navigateToClubDetails() async {
    if (_isNavigating || _clubData == null || widget.post.idClub == null) return;
    
    setState(() => _isNavigating = true); // Start loading & lock the button

    try {
      final fullClubData = await _api.getClubById(widget.post.idClub!);
      if (mounted) {
        // Cupertino Page Transition
        await Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => ClubDetailsScreen(
              club: fullClubData,
              apiService: _api,
            ),
          ),
        );
      }
    } catch (e) {
      _showSnackbar("Failed to load club details.", isError: true);
    } finally {
      if (mounted) setState(() => _isNavigating = false); // Release lock
    }
  }

  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Delete Post', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _api.deletePost(widget.post.postId);
        widget.onDeleted?.call();
      } catch (e) {
        if (mounted) _showSnackbar("Error deleting post", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.post.images.isNotEmpty)
            GestureDetector(
              onDoubleTap: _handleDoubleTap,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 500, minHeight: 300),
                        width: double.infinity,
                        color: const Color(0xFF0A0A0A),
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) => setState(() => _currentPage = index),
                          itemCount: widget.post.images.length,
                          itemBuilder: (context, index) => CachedNetworkImage(
                            imageUrl: widget.post.images[index],
                            fit: BoxFit.contain,
                            placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white10)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ScaleTransition(
                    scale: _heartScale,
                    child: const Icon(Icons.favorite, color: Colors.white, size: 80),
                  ),
                  if (widget.post.images.length > 1)
                    Positioned(
                      bottom: 12,
                      child: Row(
                        children: List.generate(widget.post.images.length, (index) => _buildDot(index)),
                      ),
                    ),
                ],
              ),
            ),
            
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              children: [
                _buildAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTapDown: (_) => setState(() => _isPressed = true),
                    onTapUp: (_) => setState(() => _isPressed = false),
                    onTapCancel: () => setState(() => _isPressed = false),
                    onTap: !widget.post.ownerIndividual && _clubData != null ? _navigateToClubDetails : null,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 100),
                      opacity: (_isPressed || _isNavigating) ? 0.5 : 1.0, 
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.post.ownerIndividual
                                      ? _truncateEmail(widget.post.individualEmail ?? "User")
                                      : ((_clubData?.name ?? "").length > 10
                                          ? "${(_clubData?.name ?? "").substring(0, 10)}..."
                                          : (_clubData?.name ?? "Loading...")),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),

                              ),
                              if (!widget.post.ownerIndividual) ...[
                                const SizedBox(width: 4),
                                if (_isNavigating)
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CupertinoActivityIndicator(radius: 6, color: Colors.white70),
                                  )
                                else
                                  const Icon(Icons.verified, color: Colors.blueAccent, size: 16),
                              ],
                            ],
                          ),
                          Text(_formatTimestamp(widget.post.timestamp), style: const TextStyle(fontSize: 11, color: Colors.white38)),
                        ],
                      ),
                    ),
                  ),
                ),
                
                _buildLikeButton(),

                IconButton(
                  onPressed: _toggleBookmark,
                  icon: Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_border, color: Colors.white, size: 24),
                ),
                if (_currentUserTruncatedEmail == _truncateEmail(widget.post.individualEmail ?? ""))
                  IconButton(
                    onPressed: _deletePost,
                    icon: const Icon(Icons.delete_outline, color: Colors.white70, size: 22),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_likes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('${_likes.length} likes', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3),
                      children: [
                        TextSpan(
                          text: "${widget.post.ownerIndividual ? _truncateEmail(widget.post.individualEmail ?? 'user') : (_clubData?.name ?? 'Club')} ",
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        ..._getParsedContent(widget.post.content), 
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      height: 6,
      width: _currentPage == index ? 18 : 6,
      decoration: BoxDecoration(
        color: _currentPage == index ? Colors.white : Colors.white24,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildLikeButton() {
    return SizedBox(
      width: 48,
      height: 48,
      child: _isLiking 
        ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2)))
        : IconButton(
            onPressed: _toggleLike,
            icon: Icon(
              _isLikedByUser() ? Icons.favorite : Icons.favorite_border,
              color: _isLikedByUser() ? Colors.redAccent : Colors.white,
              size: 24,
            ),
          ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
      child: widget.post.ownerIndividual
          ? const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF2C2C2C),
              child: Icon(Icons.person, size: 18, color: Colors.white70),
            )
          : CircleAvatar(
              radius: 16,
              backgroundImage: (_clubData?.iconUrl != null) ? NetworkImage(_clubData!.iconUrl!) : null,
              backgroundColor: const Color(0xFF2C2C2C),
              child: (_isNavigating)
                ? const CupertinoActivityIndicator(radius: 8, color: Colors.white70)
                : (_clubData?.iconUrl == null ? const Icon(Icons.groups, size: 16, color: Colors.white70) : null),
            ),
    );
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 7) return '${date.day}/${date.month}';
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'just now';
  }







//for handling link redirects and @mentions
// the URL launcher helper
Future<void> _handleLinkClick(String url) async {
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

// 3. Add the parser method
List<InlineSpan> _getParsedContent(String text) {
  final List<InlineSpan> spans = [];
  
  // RegEx for URLs and @mentions
  final RegExp combinedRegex = RegExp(
    r"(https?:\/\/[^\s]+)|(@\w+)",
    caseSensitive: false,
  );

  int lastMatchEnd = 0;
  final Iterable<RegExpMatch> matches = combinedRegex.allMatches(text);

  for (final RegExpMatch match in matches) {
    // Add plain text before the match
    if (match.start > lastMatchEnd) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd, match.start),
        style: const TextStyle(color: Colors.white70),
      ));
    }

    final String matchText = match.group(0)!;

    if (matchText.startsWith('http')) {
      // Style and Action for Links
      spans.add(TextSpan(
        text: matchText,
        style: const TextStyle(
          color: Colors.blueAccent,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => _handleLinkClick(matchText),
      ));
    } else {
      // Style for Mentions
      spans.add(TextSpan(
        text: matchText,
        style: const TextStyle(
          color: Colors.blueAccent,
          fontWeight: FontWeight.bold,
        ),
        // Add a recognizer here too if you want mentions to be clickable!
      ));
    }
    lastMatchEnd = match.end;
  }

  // Add remaining plain text
  if (lastMatchEnd < text.length) {
    spans.add(TextSpan(
      text: text.substring(lastMatchEnd),
      style: const TextStyle(color: Colors.white70),
    ));
  }

  return spans;
}
}