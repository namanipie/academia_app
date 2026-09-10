import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/mess_menu_data.dart';

// --- Static Design Constants ---
const Color kPitchBlack = Color(0xFF000000);
const Color kCardBlack = Color(0xFF0D0D0D);
const Color kSurfaceGrey = Color(0xFF1A1A1A);
const Color kMutedText = Colors.white38;

class MessMenuScreen extends StatefulWidget {
  const MessMenuScreen({super.key});

  @override
  State<MessMenuScreen> createState() => _MessMenuScreenState();
}

class _MessMenuScreenState extends State<MessMenuScreen> with TickerProviderStateMixin {
  late Future<MessMenuMap?> _menuFuture;
  TabController? _dayTabController; // Make nullable to handle init state

  String? selectedBlock;
  final List<String> days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  final Map<String, Color> dayColors = {
    'mon': const Color(0xFFD2FEA0),
    'tue': const Color(0xFF8CC0FF),
    'wed': const Color(0xFFC3A6FF),
    'thu': const Color(0xFFFFB38A),
    'fri': const Color.fromARGB(255, 81, 160, 230),
    'sat': const Color(0xFFFF85A1),
    'sun': const Color(0xFF85FFD1),
  };

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // 1. Start fetching menu immediately
    _menuFuture = MessMenuService.getMessMenu();
    
    // 2. Load persistence
    final prefs = await SharedPreferences.getInstance();
    final savedBlock = prefs.getString('last_hostel');

    // 3. Calculate initial day index
    int initialIndex = days.indexOf(DateFormat('EEE').format(DateTime.now()).toLowerCase());
    if (initialIndex == -1) initialIndex = 0;

    // 4. Initialize TabController
    _dayTabController = TabController(
      length: days.length,
      vsync: this,
      initialIndex: initialIndex,
    );

    // 5. Setup Listener with safety checks to prevent Scheduler crashes
    _dayTabController!.addListener(() {
      if (!_dayTabController!.indexIsChanging && mounted) {
        setState(() {});
      }
    });

    // 6. Final UI refresh once setup is complete
    if (mounted) {
      setState(() {
        if (savedBlock != null) {
          selectedBlock = savedBlock;
        }
      });
    }
  }

  Future<void> _saveHostelSelection(String block) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_hostel', block);
  }

  @override
  void dispose() {
    _dayTabController?.dispose();
    super.dispose();
  }

  Color _getActiveColor() {
    if (_dayTabController == null) return dayColors['mon']!;
    return dayColors[days[_dayTabController!.index]]!;
  }

  String _getCurrentMealType() {
    final now = DateTime.now();
    final hour = now.hour;
    if (hour >= 4 && hour < 10) return 'breakfast';
    if (hour >= 10 && hour < 15) return 'lunch';
    if (hour >= 15 && hour < 18) return 'snacks';
    return 'dinner';
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _getActiveColor();

    return Scaffold(
      backgroundColor: kPitchBlack,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
        title: const Text("Mess Menu", 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _dayTabController == null 
        ? Center(child: CircularProgressIndicator(color: activeColor, strokeWidth: 1))
        : FutureBuilder<MessMenuMap?>(
            future: _menuFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: activeColor, strokeWidth: 1));
              }

              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyState(activeColor, "Service unreachable");
              }

              final availableBlocks = snapshot.data!.keys.toList();
              
              if (selectedBlock == null || !availableBlocks.contains(selectedBlock)) {
                selectedBlock = availableBlocks.first;
              }

              final selectedDay = days[_dayTabController!.index];
              final currentMenu = snapshot.data![selectedBlock]?[selectedDay] ?? {};

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBlockSelector(availableBlocks, activeColor),
                  const SizedBox(height: 24),
                  _buildContinuousDaySelector(activeColor),
                  Expanded(
                    child: currentMenu.isEmpty 
                        ? _buildEmptyState(activeColor, "No menu for $selectedDay")
                        : _buildMealContent(currentMenu, activeColor),
                  ),
                ],
              );
            },
          ),
    );
  }

  Widget _buildEmptyState(Color activeColor, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_rounded, size: 64, color: activeColor.withValues(alpha:0.2)),
          const SizedBox(height: 16),
          Text(
            "NO DATA AVAILABLE",
            style: TextStyle(color: activeColor, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(message, style: const TextStyle(color: kMutedText, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildBlockSelector(List<String> blocks, Color activeColor) {
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: blocks.length,
        itemBuilder: (context, index) {
          final block = blocks[index];
          bool isSelected = selectedBlock == block;
          return GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              setState(() => selectedBlock = block);
              _saveHostelSelection(block);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : kSurfaceGrey,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Text(
                  block.toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white54,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

Widget _buildContinuousDaySelector(Color activeColor) {
  return Container(
    height: 54, // Fixed height for a sleeker profile
    margin: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: const Color.fromARGB(255, 0, 0, 0).withValues(alpha:0.5), // Subtle glass effect
      borderRadius: BorderRadius.circular(16), // Softer corners
    ),
    child: TabBar(
      controller: _dayTabController,
      isScrollable: true,
      physics: const BouncingScrollPhysics(),
      
      // Modern "Pill" Indicator
      indicator: BoxDecoration(
        color: activeColor.withValues(alpha:0.15), // Very soft tinted background
        borderRadius: BorderRadius.circular(24),

      ),
      
      // Text Styling
      labelColor: activeColor,
      unselectedLabelColor: Colors.white24, // Muted unselected tabs
      labelStyle: const TextStyle(
        fontSize: 12, 
        fontWeight: FontWeight.w800, 
        letterSpacing: 0.8,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 11, 
        fontWeight: FontWeight.w600,
      ),
      
      // Cleanup Standard TabBar artifacts
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      overlayColor: WidgetStateProperty.all(Colors.transparent), // Remove splash highlight
      
      padding: const EdgeInsets.all(6),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4), // Tighter spacing
      
      tabs: days.map((day) => Tab(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(day.toUpperCase()),
        ),
      )).toList(),
    ),
  );
}

  Widget _buildMealContent(Map<String, dynamic> menu, Color activeColor) {
    final mealTypes = ['breakfast', 'lunch', 'snacks', 'dinner'];
    final currentMeal = _getCurrentMealType();

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: mealTypes.length,
      itemBuilder: (context, index) {
        final type = mealTypes[index];
        final items = menu[type] as List?;
        if (items == null || items.isEmpty) return const SizedBox.shrink();

        bool isLive = type.toLowerCase() == currentMeal;

        return _buildModernMealCard(
          type.toUpperCase(),
          items,
          _getMealIcon(type),
          isLive,
          activeColor,
        );
      },
    );
  }

  Widget _buildModernMealCard(String title, List items, IconData icon, bool isLive, Color activeColor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBlack,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isLive ? activeColor.withValues(alpha:0.4) : const Color.fromARGB(244, 0, 0, 0).withValues(alpha:0.05),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: isLive ? activeColor : kMutedText, size: 18),
                  const SizedBox(width: 12),
                  Text(title,
                      style: TextStyle(
                          color: isLive ? Colors.white : kMutedText,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1)),
                ],
              ),
              if (isLive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text("LIVE",
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 9)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: items.map((item) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isLive ? activeColor.withValues(alpha:0.08) : kSurfaceGrey,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isLive ? activeColor.withValues(alpha:0.15) : Colors.transparent
                ),
              ),
              child: Text(
                item.toString(),
                style: TextStyle(
                  color: isLive ? Colors.white : Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  IconData _getMealIcon(String type) {
    switch (type.toLowerCase()) {
      case 'breakfast': return Icons.wb_twilight_rounded;
      case 'lunch': return Icons.wb_sunny_rounded;
      case 'snacks': return Icons.coffee_rounded;
      default: return Icons.nightlight_round;
    }
  }
}