import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:academia_app/club_events_social/services/club_main_service.dart';
import 'package:academia_app/club_events_social/models/models.dart';
import 'package:academia_app/club_events_social/widgets/postcard.dart';
import 'package:academia_app/club_events_social/widgets/club_group_grid.dart';
import 'package:academia_app/club_events_social/utils/image_cache_manager.dart';
import 'package:http/http.dart' as http;

//importing create post screen
import 'package:academia_app/club_events_social/screens/create_posts.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  
  // Tab State: 'Posts' | 'Groups' | 'Bookmarks'
  String _activeTab = 'Posts';
  bool _isGroupsRefreshing = false;
  
  // Posts pagination state
  List<Post> _posts = [];
  int _currentOffset = 0;
  final int _limit = 20;
  bool _isLoadingMore = false;
  bool _hasMorePosts = true;
  bool _isInitialLoading = true;

  // Bookmarks state
  List<Post> _bookmarkedPosts = [];
  bool _isLoadingBookmarks = false;

  static bool _hasWarmedUp = false; // for server warm-up

@override
void initState() {
  super.initState();
  _scrollController.addListener(_onScroll);
  _loadInitialPosts();

  // Only ping if we haven't already this session for server warm-up
  if (!_hasWarmedUp) {
    _warmUpServer();
  }

}

//-- Server Warm-up Logic ---
Future<void> _warmUpServer() async {
  _hasWarmedUp = true;
  try {
    // We don't care about the result, just hitting the metal to wake it up
    await http.get(Uri.parse("https://microservice-console.onrender.com/health")).catchError((_){});
  } catch (e) {
    // Silent fail is fine here, we just want the server to see the request
  }
}
//////////////////////////////////





  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_activeTab != 'Posts') return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      _loadMorePosts();
    }
    
    // Pre-cache images for posts that are about to become visible
    _preloadNextPostImages();
  }

  /// Pre-load images of posts coming into view for smoother scrolling
  void _preloadNextPostImages() {
    final scrollOffset = _scrollController.offset;
    final itemHeight = 500.0; // Approximate height of each post card
    final currentIndex = (scrollOffset / itemHeight).toInt();
    
    // Pre-load next 2-3 posts' images
    for (int i = currentIndex; i < (currentIndex + 3) && i < _posts.length; i++) {
      final post = _posts[i];
      if (post.images.isNotEmpty) {
        ImageCacheManager.preCacheImages(post.images);
      }
    }
  }

  // --- Logic: Fetch Posts ---
  Future<void> _loadInitialPosts({bool forceRefresh = false}) async {
    setState(() {
      _isInitialLoading = true;
      _currentOffset = 0;
      _hasMorePosts = true;
    });

    try {
      final result = await _apiService.getPosts(
        offset: 0, 
        limit: _limit, 
        forceRefresh: forceRefresh,
      );
      
      setState(() {
        _posts = result['posts'];
        _currentOffset = _limit;
        _hasMorePosts = result['posts'].length >= _limit;
        _isInitialLoading = false;
      });
    } catch (e) {
      setState(() => _isInitialLoading = false);
      _showErrorSnackBar('Failed to load posts: $e');
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMorePosts) return;
    setState(() => _isLoadingMore = true);

    try {
      final result = await _apiService.getPosts(offset: _currentOffset, limit: _limit);
      final newPosts = result['posts'] as List<Post>;
      
      setState(() {
        _posts.addAll(newPosts);
        _currentOffset += _limit;
        _hasMorePosts = newPosts.length >= _limit;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() => _isLoadingMore = false);
      _showErrorSnackBar('Failed to load more: $e');
    }
  }

  // --- Logic: Bookmarks ---
  Future<void> _loadBookmarkedPosts() async {
    setState(() => _isLoadingBookmarks = true);
    final prefs = await SharedPreferences.getInstance();
    final List<String> bookmarkedJsonList = prefs.getStringList('user_bookmarks') ?? [];

    setState(() {
      _bookmarkedPosts = bookmarkedJsonList.map((jsonStr) {
        return Post.fromJson(jsonDecode(jsonStr));
      }).toList();
      _isLoadingBookmarks = false;
    });
  }

  /// Clear cached images to free up memory when not in use
  void _clearImageCache() {
    ImageCacheManager.clearOldCache();
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // --- UI Components ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Social Space',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
        ),
        centerTitle: false,
        backgroundColor: Colors.black,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreatePostScreen(apiService: _apiService),
                ),
              );
            },
          ),
        ],
      ),

      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

Widget _buildFilterBar() {
    return Container(
      width: double.infinity,
      // Ensures the scrollable content starts exactly from the left edge
      alignment: Alignment.centerLeft, 
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // BouncingScrollPhysics gives it that premium "iOS-style" elastic feel
        physics: const BouncingScrollPhysics(), 
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _filterBubble('Posts'),
            const SizedBox(width: 10),
            _filterBubble('Groups'),
            const SizedBox(width: 10),
            _filterBubble('Bookmarks'),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }

  Widget _filterBubble(String label) {
    bool isSelected = _activeTab == label;
    
    return GestureDetector(
      onTap: () {
        setState(() => _activeTab = label);
        if (label == 'Posts' && _posts.isEmpty) _loadInitialPosts();
        if (label == 'Bookmarks') _loadBookmarkedPosts();
        // Clear cache when switching away from Posts to free memory
        if (label != 'Posts') _clearImageCache();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          // Using a subtle gradient or solid white for the active state
          color: isSelected ? Colors.white : const Color(0xFF121212), 
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha:0.1),
            width: 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.white.withValues(alpha:0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ] : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            fontSize: 14,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_activeTab) {
      case 'Groups':
        return _buildGroupGrid();
      case 'Bookmarks':
        return _buildBookmarkList();
      default:
        return _buildPostList();
    }
  }

  Widget _buildPostList() {
    if (_isInitialLoading) return const Center(child: CircularProgressIndicator(color: Colors.white));

    if (_posts.isEmpty) {
      return _buildEmptyState('No posts available', onRefresh: () => _loadInitialPosts(forceRefresh: true));
    }

    return RefreshIndicator(
      backgroundColor: const Color(0xFF1A1A1A),
      color: Colors.white,
      onRefresh: () => _loadInitialPosts(forceRefresh: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _posts.length + (_hasMorePosts ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _posts.length) {
            return _isLoadingMore ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())) : const SizedBox.shrink();
          }
          return PostCard(
            post: _posts[index],
            onDeleted: () => setState(() => _posts.removeAt(index)),
          );
        },
      ),
    );
  }

  Widget _buildBookmarkList() {
    if (_isLoadingBookmarks) return const Center(child: CircularProgressIndicator(color: Colors.white));

    if (_bookmarkedPosts.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bookmark_border, size: 80, color: Colors.white24),
              SizedBox(height: 16),
              Text(
                'No bookmarks added yet',
                style: TextStyle(color: Colors.white38),
              ),
            ],
          ),
        ),
      );

    }

    return RefreshIndicator(
      backgroundColor: const Color(0xFF1A1A1A),
      color: Colors.white,
      onRefresh: _loadBookmarkedPosts,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _bookmarkedPosts.length,
        itemBuilder: (context, index) {
          return PostCard(
            post: _bookmarkedPosts[index],
            // On bookmarks, we refresh list if user un-bookmarks (optional UI choice)
            onLikeToggled: _loadBookmarkedPosts, 
          );
        },
      ),
    );
  }

  Widget _buildGroupGrid() {
    return ClubGroupGrid(
      apiService: _apiService,
      isRefreshing: _isGroupsRefreshing,
      onRefresh: () async {
        setState(() => _isGroupsRefreshing = true);
        await Future.delayed(const Duration(milliseconds: 100));
        setState(() => _isGroupsRefreshing = false);
      },
    );
  }

  Widget _buildEmptyState(String message, {required VoidCallback onRefresh}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRefresh, child: const Text('Refresh')),
        ],
      ),
    );
  }
}