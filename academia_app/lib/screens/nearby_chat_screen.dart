import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/nearby_chat_data.dart'; 

// --- UI CONSTANTS ---
const Color kPitchBlack = Color(0xFF000000);
const Color kSurfaceGrey = Color(0xFF121212); 
const Color kCardGrey = Color(0xFF1E1E1E);
const Color kMutedText = Colors.white38;
const Color kAccentBlue = Color(0xFF8CC0FF); 
const Color kWarningRed = Color(0xFFFF5252);
const Color kSystemGreen = Color(0xFF34C759);

class NearbyChatScreen extends StatefulWidget {
  const NearbyChatScreen({super.key});

  @override
  _NearbyChatScreenState createState() => _NearbyChatScreenState();
}

class _NearbyChatScreenState extends State<NearbyChatScreen> with WidgetsBindingObserver {
  late NearbyChatService chatService;
  List<ChatMessage> messages = [];
  List<String> visibleDevices = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool isLoading = true;
  bool isServiceHealthy = true;
  bool isAuthenticated = false; // Guard variable

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAuthAndInit();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (isAuthenticated) {
      chatService.stopAll();
      chatService.dispose();
    }
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- AUTH & INITIALIZATION LOGIC ---

  Future<void> _checkAuthAndInit() async {
    final prefs = await SharedPreferences.getInstance();
    final String? email = prefs.getString('userEmail');

    // Validate email presence and format
    if (email == null || email.isEmpty || !email.contains('@')) {
      if (mounted) {
        setState(() {
          isAuthenticated = false;
          isLoading = false;
        });
      }
      return;
    }

    // Extract characters before @ (e.g., as0711@srmist.edu.in -> as0711)
    String userId = email.split('@')[0];

    // Initialize Service with parsed ID
    chatService = NearbyChatService(userId);
    
    if (mounted) {
      setState(() {
        isAuthenticated = true;
      });
    }

    // Setup listeners
    chatService.onNodesChanged = (nodes) {
      if (mounted) setState(() => visibleDevices = nodes);
    };

    chatService.onServiceStateChanged = (healthy) {
      if (mounted) setState(() => isServiceHealthy = healthy);
    };

    await _initApp();
  }

  Future<void> _initApp() async {
    await _loadHistory();
    bool success = await _startNearby();
    if (success) {
      chatService.messagesStream.listen((chat) {
        if (mounted) {
          setState(() => messages.add(chat));
          _saveHistory();
          _scrollToBottom();
        }
      });
    }
  }

  Future<bool> _startNearby() async {
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.location,
        Permission.nearbyWifiDevices,
      ].request();
      
      if (!statuses.values.every((s) => s.isGranted || s.isLimited)) {
        if (mounted) setState(() => isLoading = false);
        return false;
      }
      await chatService.startAdvertising();
      await chatService.startDiscovery();
      if (mounted) setState(() => isLoading = false);
      return true;
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      return false;
    }
  }

  // --- DATA PERSISTENCE ---

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('nearby_history');
    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      if (mounted) {
        setState(() => messages = decoded.map((m) => ChatMessage.fromMap(m)).toList());
      }
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nearby_history', jsonEncode(messages.map((m) => m.toMap()).toList()));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCirc,
        );
      }
    });
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    // If we've checked and no email is found, show Access Denied
    if (!isLoading && !isAuthenticated) {
      return _buildAccessDenied();
    }

    return Scaffold(
      backgroundColor: kPitchBlack,
      appBar: _buildModernAppBar(),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator(color: kAccentBlue, strokeWidth: 1))
          : Column(
              children: [
                _buildRadarAndActionSection(),
                Expanded(
                  child: messages.isEmpty 
                      ? _buildEmptyState()
                      : _buildChatList(),
                ),
                _buildMessageInput(),
              ],
            ),
    );
  }

  Widget _buildAccessDenied() {
    return Scaffold(
      backgroundColor: kPitchBlack,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 80, color: kWarningRed),
              const SizedBox(height: 24),
              const Text("ACCESS DENIED", 
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 3)),
              const SizedBox(height: 16),
              const Text(
                "A valid email is required to broadcast on this frequency. Please log in first.",
                textAlign: TextAlign.center,
                style: TextStyle(color: kMutedText, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kAccentBlue, foregroundColor: Colors.black),
                onPressed: () => Navigator.pop(context),
                child: const Text("RETURN TO LOGIN", style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Nearby Chat", 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(width: 10),
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: isServiceHealthy ? kSystemGreen : kWarningRed,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isServiceHealthy ? kSystemGreen : kWarningRed).withValues(alpha:0.5),
                  blurRadius: 6,
                  spreadRadius: 2,
                )
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline_rounded, color: kAccentBlue, size: 22),
          onPressed: () => _showGuidelines(),
        ),
        IconButton(
          icon: const Icon(Icons.sync_rounded, color: kAccentBlue, size: 22),
          onPressed: () async {
            HapticFeedback.mediumImpact();
            await chatService.restartServices();
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildRadarAndActionSection() {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: kSurfaceGrey.withValues(alpha:0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.heavyImpact();
              setState(() => messages.clear());
              _saveHistory();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete, color: Color.fromARGB(255, 181, 178, 178), size: 18),
                  Text("Clear", style: TextStyle(color: Color.fromARGB(255, 240, 228, 228), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 24, color: Colors.white10),
          Expanded(
            child: visibleDevices.isEmpty 
              ? const Center(child: Text("SCANNING FOR SIGNALS...", style: TextStyle(color: kMutedText, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: visibleDevices.length,
                  itemBuilder: (context, index) => _buildNodeChip(visibleDevices[index]),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeChip(String name) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: kCardGrey,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kAccentBlue.withValues(alpha:0.1)),
        ),
        child: Text(name.toUpperCase(), 
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: messages.length,
      itemBuilder: (context, i) => _buildEnhancedBubble(messages[i]),
    );
  }

  Widget _buildEnhancedBubble(ChatMessage m) {
    bool isMine = m.isMine;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isMine ? kAccentBlue : kCardGrey,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(isMine ? 22 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 22),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(m.senderName.toUpperCase(), 
                  style: const TextStyle(color: kAccentBlue, fontWeight: FontWeight.w900, fontSize: 8, letterSpacing: 0.5)),
              ),
            Text(
              m.message,
              style: TextStyle(
                color: isMine ? Colors.black : Colors.white, 
                fontSize: 15, 
                height: 1.3
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(DateFormat('HH:mm').format(m.timestamp), 
                style: TextStyle(color: isMine ? Colors.black45 : kMutedText, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5))
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(color: kCardGrey, borderRadius: BorderRadius.circular(28)),
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: "TRANSMIT SIGNAL...",
                  hintStyle: TextStyle(color: kMutedText, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              if (_controller.text.trim().isNotEmpty) {
                chatService.sendMessage(_controller.text.trim());
                _controller.clear();
                HapticFeedback.lightImpact();
              }
            },
            child: const CircleAvatar(
              backgroundColor: kAccentBlue,
              radius: 26,
              child: Icon(Icons.arrow_upward_rounded, color: Colors.black, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_channel_rounded, size: 64, color: kAccentBlue.withValues(alpha:0.05)),
          const SizedBox(height: 16),
          const Text("SILENCE ON ALL FREQUENCIES", 
            style: TextStyle(color: kMutedText, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 11)),
        ],
      ),
    );
  }

  void _showGuidelines() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: kCardGrey,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            const Text("COMMUNITY GUIDELINES", 
              style: TextStyle(color: kAccentBlue, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2)),
            const SizedBox(height: 16),
            const Text(
              "This is a local peer-to-peer network. By using this service, you agree to:\n\n"
              "• Not transmit harmful, offensive, or illegal content.\n"
              "• Sometimes it may not work as expected,waiting for sometime may resolve the issue.\n"
              "• Your Email ID is used solely for identification\n",
              style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: kWarningRed.withValues(alpha:0.1), borderRadius: BorderRadius.circular(12)),
              child: const Row(
                children: [
                  Icon(Icons.shield_rounded, color: kWarningRed, size: 18),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text("VIOLATIONS RESULT IN LOCAL NODE BLOCKING", 
                      style: TextStyle(color: kWarningRed, fontWeight: FontWeight.w900, fontSize: 10)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}