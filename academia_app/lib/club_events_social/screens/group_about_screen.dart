import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:academia_app/club_events_social/models/models.dart';
import 'package:academia_app/club_events_social/services/club_main_service.dart';
import 'package:academia_app/club_events_social/widgets/postcard.dart';
import 'package:url_launcher/url_launcher.dart';

class ClubDetailsScreen extends StatefulWidget {
  final Club club;
  final ApiService apiService;

  const ClubDetailsScreen({super.key, required this.club, required this.apiService});

  @override
  State<ClubDetailsScreen> createState() => _ClubDetailsScreenState();
}

class _ClubDetailsScreenState extends State<ClubDetailsScreen> {
  // Post Logic State
  final List<Post> _clubPosts = [];
  bool _isLoadingPosts = false;
  bool _hasMorePosts = true;
  int _currentOffset = 0;
  final int _limit = 10;

  // User/Club State
  String? _currentUserTruncatedEmail;
  late bool _isSubscribed;
  late int _subscriberCount;
  late int _clubPostCount;
  bool _isCoreMember = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _subscriberCount = widget.club.subscribers.length;
    _clubPostCount = widget.club.postIds.length;
    _isSubscribed = false;
    _loadUserAndStatus();
  }

  /// Refactored to use the specific club endpoint with pagination
  Future<void> _fetchClubPosts() async {
    if (_isLoadingPosts || !_hasMorePosts) return;

    setState(() => _isLoadingPosts = true);

    try {
      // Using the specific API logic you provided
      final List<dynamic> rawPosts = await widget.apiService.getClubPosts(
        widget.club.id.toString(),
        offset: _currentOffset,
        limit: _limit,
        approvedOnly: true,
      );

      // Map dynamic list to Post models
      final List<Post> newPosts = rawPosts.map((json) => Post.fromJson(json)).toList();

      if (mounted) {
        setState(() {
          _clubPosts.addAll(newPosts);
          _isLoadingPosts = false;
          _currentOffset += _limit;

          // If we fetched fewer posts than the limit, we've reached the end
          if (newPosts.length < _limit) {
            _hasMorePosts = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPosts = false);
        if (kDebugMode) debugPrint("Error fetching club posts: $e");
      }
    }
  }

  Future<void> _loadUserAndStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final fullEmail = prefs.getString('userEmail');
    if (fullEmail != null && mounted) {
      final truncated = _truncateEmail(fullEmail);
      setState(() {
        _currentUserTruncatedEmail = truncated;
        _isSubscribed = widget.club.subscribers.contains(truncated);
        _isCoreMember = widget.club.coreMembers.contains(truncated);
      });
    }
  }

  String _truncateEmail(String email) => email.contains('@') ? email.split('@')[0] : email;

  Future<void> _handleToggleSubscribe() async {
    
    if (_currentUserTruncatedEmail == null || _isProcessing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please log in to Subscribe"),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    setState(() => _isProcessing = true);
    try {
      final response = await widget.apiService.toggleSubscription(
          widget.club.id.toString(), _currentUserTruncatedEmail!);

      final bool newStatus = response['status'] == 'subscribed';
      setState(() {
        _isSubscribed = newStatus;
        _subscriberCount = newStatus ? _subscriberCount + 1 : _subscriberCount - 1;
        _isProcessing = false;
      });
      await _updateLocalCache(newStatus);
      
      // Show subscription confirmation snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus
                  ? 'You subscribed! You will receive notifications when ${widget.club.name} uploads'
                  : 'You unsubscribed from ${widget.club.name}',
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: newStatus ? Colors.green[700] : const Color(0xFF1A1A1A),
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _updateLocalCache(bool subscribed) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedString = prefs.getString('cached_clubs_list');
    if (cachedString == null) return;

    List<dynamic> clubsJson = jsonDecode(cachedString);
    for (var i = 0; i < clubsJson.length; i++) {
      if (clubsJson[i]['club_id'].toString() == widget.club.id.toString()) {
        List<dynamic> subs = List.from(clubsJson[i]['subscribers'] ?? []);
        if (subscribed) {
          if (!subs.contains(_currentUserTruncatedEmail)) subs.add(_currentUserTruncatedEmail);
        } else {
          subs.remove(_currentUserTruncatedEmail);
        }
        clubsJson[i]['subscribers'] = subs;
        break;
      }
    }
    await prefs.setString('cached_clubs_list', jsonEncode(clubsJson));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // --- 1. Header with Floating Logo ---
          _buildSliverAppBar(),

          // --- 2. Main Content ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildClubHeader(),
                  const SizedBox(height: 28),
                  _buildStatsRow(),
                  const SizedBox(height: 40),
                  _buildSectionTitle("About"),
                  Text(
                    widget.club.description,
                    style: TextStyle(color: Colors.white.withValues(alpha:0.7), fontSize: 15, height: 1.6),
                  ),
                  const SizedBox(height: 40),
                  if (widget.club.coreMembers.isNotEmpty) ...[
                    _buildSectionTitle("Core Team"),
                    _buildDynamicChips(widget.club.coreMembers, false),
                    const SizedBox(height: 40),
                  ],
                  if (widget.club.links.isNotEmpty) ...[
                    _buildSectionTitle("Links"),
                    _buildDynamicChips(widget.club.links, true),
                    const SizedBox(height: 40),
                  ],
                  _buildSectionTitle("Recent Activity"),
                ],
              ),
            ),
          ),

          // --- 3. Post Feed ---
          _clubPosts.isEmpty && _isLoadingPosts
              ? const SliverToBoxAdapter(
                  child: Center(
                      child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(color: Colors.white24, strokeWidth: 2),
                )))
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PostCard(post: _clubPosts[index]),
                      ),
                      childCount: _clubPosts.length,
                    ),
                  ),
                ),

          // --- 4. Pagination / "Show More" Button ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              child: _buildLoadMoreFooter(),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Components ---

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.black,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            widget.club.bannerUrl != null && widget.club.bannerUrl!.isNotEmpty
                ? Image.network(widget.club.bannerUrl!, fit: BoxFit.cover)
                : Container(color: Colors.grey[900]),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black],
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              left: 20,
              child: Hero(
                tag: 'club_icon_${widget.club.id}',
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                  child: CircleAvatar(
                    radius: 42,
                    backgroundColor: const Color(0xFF1A1A1A),
                    backgroundImage: widget.club.iconUrl != null ? NetworkImage(widget.club.iconUrl!) : null,
                    child: widget.club.iconUrl == null ? const Icon(Icons.groups, color: Colors.white24, size: 35) : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildClubHeader() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              widget.club.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.8,
              ),
            ),
          ),

          const SizedBox(width: 6),

          const SizedBox(
            width: 20,
            height: 20,
            child: Icon(
              Icons.verified,
              color: Colors.blueAccent,
              size: 16,
            ),
          ),
        ],
      ),

      const SizedBox(height: 4),

      Text(
        "@${widget.club.name}",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    ],
  );
}



  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatColumn("$_subscriberCount", "Subscribers"),
        _buildVerticalDivider(),
        _buildStatColumn("$_clubPostCount${_hasMorePosts ? '+' : ''}", "Posts"),
        const Spacer(),
        _buildFollowButton(),
      ],
    );
  }

  Widget _buildLoadMoreFooter() {
    if (_isLoadingPosts && _clubPosts.isNotEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.white24, strokeWidth: 2));
    }

    if (!_hasMorePosts) {
      return const Center(
        child: Text("You've reached the end", style: TextStyle(color: Colors.white24, fontSize: 12)),
      );
    }

    return Center(
      child: TextButton.icon(
        onPressed: _fetchClubPosts,
        icon: const Icon(Icons.arrow_downward_rounded, color: Colors.white70, size: 18),
        label: const Text("Show Posts", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
        style: TextButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha:0.05),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
    );
  }

  // --- Original Helpers (Unchanged) ---

  Widget _buildStatColumn(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white30, fontSize: 12)),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 25, width: 1, margin: const EdgeInsets.symmetric(horizontal: 25), color: Colors.white10);
  }

  Widget _buildFollowButton() {
    return GestureDetector(
      onTap: _handleToggleSubscribe,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        decoration: BoxDecoration(
          color: _isSubscribed ? Colors.transparent : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: _isSubscribed ? Border.all(color: Colors.white.withValues(alpha:0.3), width: 1) : null,
        ),
        child: _isProcessing
            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey))
            : Text(
                _isSubscribed ? "Following" : "Follow",
                style: TextStyle(color: _isSubscribed ? Colors.white : Colors.black, fontWeight: FontWeight.w900, fontSize: 13),
              ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white24, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2.0),
      ),
    );
  }

  Widget _buildDynamicChips(List<String> items, bool isLink) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) {
        return GestureDetector(
          onTap: isLink ? () => _launchURL(item) : null,
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withValues(alpha:0.05)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLink) ...[
                  const Icon(Icons.link, size: 16, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    item,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isLink ? const Color.fromARGB(255, 192, 196, 204) : Colors.white.withValues(alpha:0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the link')));
      }
    }
  }
}