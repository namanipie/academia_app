import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // For smooth iOS-style transitions
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:academia_app/club_events_social/models/models.dart';
import 'package:academia_app/club_events_social/services/club_main_service.dart';
import 'package:academia_app/club_events_social/screens/group_about_screen.dart';

class ClubGroupGrid extends StatefulWidget {
  final ApiService apiService;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  const ClubGroupGrid({
    super.key,
    required this.apiService,
    required this.isRefreshing,
    required this.onRefresh,
  });

  @override
  State<ClubGroupGrid> createState() => _ClubGroupGridState();
}

class _ClubGroupGridState extends State<ClubGroupGrid> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- Search Bar Section ---
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: "Search groups...",
              hintStyle: const TextStyle(color: Colors.white24),
              prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
              filled: true,
              fillColor: const Color(0xFF0D0D0D),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withValues(alpha:0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withValues(alpha:0.08)),
              ),
            ),
          ),
        ),

        // --- Grid Section ---
        Expanded(
          child: RefreshIndicator(
            backgroundColor: const Color(0xFF1A1A1A),
            color: Colors.white,
            onRefresh: () async => widget.onRefresh(),
            child: FutureBuilder<List<Club>>(
              future: widget.apiService.getClubs(forceRefresh: widget.isRefreshing),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !widget.isRefreshing) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }

                if (snapshot.hasError) return _buildErrorState(context, snapshot.error.toString());

                final clubs = (snapshot.data ?? []).where((c) => 
                  c.name.toLowerCase().contains(_searchQuery)).toList();

                if (clubs.isEmpty) return _buildEmptyState();

                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: clubs.length,
                  itemBuilder: (context, index) => _ModernClubCard(
                    club: clubs[index],
                    apiService: widget.apiService,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
          const SizedBox(height: 12),
          Text('Error: $error', style: const TextStyle(color: Colors.white60)),
          TextButton(onPressed: widget.onRefresh, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        _searchQuery.isEmpty ? 'No groups found' : 'No matches for "$_searchQuery"',
        style: const TextStyle(color: Colors.white38, fontSize: 14),
      ),
    );
  }
}

class _ModernClubCard extends StatefulWidget {
  final Club club;
  final ApiService apiService;

  const _ModernClubCard({required this.club, required this.apiService});

  @override
  State<_ModernClubCard> createState() => _ModernClubCardState();
}

class _ModernClubCardState extends State<_ModernClubCard> {
  String? _currentUserTruncatedEmail;
  late bool _isSubscribed;
  late int _subscriberCount;
  bool _isCoreMember = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _subscriberCount = widget.club.subscribers.length;
    _isSubscribed = false; 
    _loadUserAndStatus();
  }

  Future<void> _loadUserAndStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final fullEmail = prefs.getString('userEmail');
    if (fullEmail != null && mounted) {
      final truncated = _truncateEmail(fullEmail);
      setState(() {
        _currentUserTruncatedEmail = truncated;
        _isSubscribed = widget.club.subscribers.contains(truncated);
        // Check if user is a leader/admin of this club
        _isCoreMember = widget.club.coreMembers.contains(truncated);
      });
    }
  }

  String _truncateEmail(String email) => email.contains('@') ? email.split('@')[0] : email;

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
        widget.club.id.toString(), 
        _currentUserTruncatedEmail!
      );

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

 @override
Widget build(BuildContext context) {
  return GestureDetector(
    onTap: () => Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => ClubDetailsScreen(
          club: widget.club,
          apiService: widget.apiService,
        ),
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          if (widget.club.bannerUrl != null &&
              widget.club.bannerUrl!.isNotEmpty)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: widget.club.bannerUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: const Color(0xFF0D0D0D)),
                errorWidget: (_, __, ___) =>
                    Container(color: const Color(0xFF0D0D0D)),
                cacheKey: 'club_banner_${widget.club.id}',
              ),
            )
          else
            Container(color: const Color(0xFF0D0D0D)),

          // Dark overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha:0.3),
                    Colors.black.withValues(alpha:0.8),
                  ],
                ),
              ),
            ),
          ),

          // Content
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha:0.08),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildAvatar(),
                const SizedBox(height: 12),

                Text(
                  widget.club.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 4),

                Text(
                  '$_subscriberCount Subscribers',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                ),

                const SizedBox(height: 12),
                _buildSubscribeButton(),
              ],
            ),
          ),

          // Core badge
          if (_isCoreMember)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha:0.3),
                    width: 0.5,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      color: Colors.amber,
                      size: 10,
                    ),
                    SizedBox(width: 4),
                    Text(
                      "CORE",
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

  Widget _buildAvatar() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white12, width: 1),
      ),
      child: Hero(
        tag: 'club_icon_${widget.club.id}',
        child: widget.club.iconUrl != null
            ? CircleAvatar(
                radius: 32,
                backgroundColor: const Color(0xFF1A1A1A),
                backgroundImage: CachedNetworkImageProvider(
                  widget.club.iconUrl!,
                  cacheKey: 'club_icon_${widget.club.id}',
                ),
              )
            : CircleAvatar(
                radius: 32,
                backgroundColor: const Color(0xFF1A1A1A),
                child: const Icon(Icons.groups_rounded, color: Colors.white54, size: 28),
              ),
      ),
    );
  }

  Widget _buildSubscribeButton() {
    return SizedBox(
      height: 32,
      width: 100,
      child: TextButton(
        onPressed: _handleToggleSubscribe,
        style: TextButton.styleFrom(
          backgroundColor: _isSubscribed ? Colors.transparent : Colors.white,
          foregroundColor: _isSubscribed ? Colors.white : Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: _isSubscribed 
                ? BorderSide(color: Colors.white.withValues(alpha:0.3), width: 1)
                : BorderSide.none,
          ),
          padding: EdgeInsets.zero,
        ),
        child: _isProcessing
            ? const SizedBox(
                height: 12, width: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
              )
            : Text(
                _isSubscribed ? 'Following' : 'Join',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}