import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:nearby_connections/nearby_connections.dart';


/// Data model for chat messages including metadata
class ChatMessage {
  final String senderName;
  final String message;
  final bool isMine;
  final DateTime timestamp;

  ChatMessage({
    required this.senderName,
    required this.message,
    required this.isMine,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Converts the object to a Map for JSON encoding
  Map<String, dynamic> toMap() => {
    'senderName': senderName,
    'message': message,
    'isMine': isMine,
    'timestamp': timestamp.toIso8601String(),
  };

  /// Creates an object from a Map (received via JSON)
  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
    senderName: map['senderName'],
    message: map['message'],
    isMine: map['isMine'],
    timestamp: DateTime.parse(map['timestamp']),
  );
}

class NearbyChatService {
  final Strategy strategy = Strategy.P2P_STAR;
  late String userName;
  
  // State management
  final Map<String, String> connectedUsers = {};
  final Map<String, DateTime> lastHeartbeat = {};
  bool _isAdvertising = false;
  bool _isDiscovering = false;
  
  // Streams and Timers
  final StreamController<ChatMessage> _messages = StreamController.broadcast();
  Stream<ChatMessage> get messagesStream => _messages.stream;
  Timer? _healthCheckTimer;
  Timer? _reconnectTimer;

  // Callbacks for UI updates
  Function(List<String>)? onNodesChanged;
  Function(bool isHealthy)? onServiceStateChanged;

  NearbyChatService(String name) {
    userName = name;
    _startHealthMonitoring();
  }

  // --- SERVICE LIFECYCLE ---

  Future<void> startAdvertising() async {
    try {
      await Nearby().startAdvertising(
        userName,
        strategy,
        onConnectionInitiated: _onConnInit,
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            lastHeartbeat[id] = DateTime.now();
            onNodesChanged?.call(connectedUsers.values.toList());
          }
        },
        onDisconnected: (id) {
          _handleDisconnect(id);
        },
      );
      _isAdvertising = true;
      if (kDebugMode) debugPrint("Advertising started.");
    } catch (e) {
      if (kDebugMode) debugPrint("Advertising Error: $e");
      _isAdvertising = false;
      _scheduleReconnect();
    }
  }

  Future<void> startDiscovery() async {
    try {
      await Nearby().startDiscovery(
        userName,
        strategy,
        onEndpointFound: (id, name, serviceId) {
          Nearby().requestConnection(
            userName, 
            id, 
            onConnectionInitiated: _onConnInit,
            onConnectionResult: (eid, status) {
              if (status == Status.CONNECTED) {
                lastHeartbeat[eid] = DateTime.now();
                onNodesChanged?.call(connectedUsers.values.toList());
              }
            },
            onDisconnected: (id) => _handleDisconnect(id),
          );
        },
        onEndpointLost: (id) {
          if (id != null) _handleDisconnect(id);
        },
      );
      _isDiscovering = true;
      if (kDebugMode) debugPrint("Discovery started.");
    } catch (e) {
      if (kDebugMode) debugPrint("Discovery Error: $e");
      _isDiscovering = false;
      _scheduleReconnect();
    }
  }

  // --- DATA TRANSMISSION ---

  void _onConnInit(String id, ConnectionInfo info) {
    connectedUsers[id] = info.endpointName;
    lastHeartbeat[id] = DateTime.now();
    
    Nearby().acceptConnection(
      id, 
      onPayLoadRecieved: (endpointId, payload) {
        if (payload.type == PayloadType.BYTES && payload.bytes != null) {
          _processIncomingPayload(endpointId, payload.bytes!);
        }
      },
    );
  }

  void _processIncomingPayload(String endpointId, Uint8List bytes) {
    try {
      String rawContent = utf8.decode(bytes);
      
      // Handle simple heartbeat strings
      if (rawContent == "__HEARTBEAT__") {
        lastHeartbeat[endpointId] = DateTime.now();
        return;
      }
      
      // Decode complex JSON message
      Map<String, dynamic> data = json.decode(rawContent);
      ChatMessage receivedMsg = ChatMessage.fromMap(data);

      // We reconstruct it to ensure 'isMine' is false for the local UI
      final displayMsg = ChatMessage(
        senderName: receivedMsg.senderName,
        message: receivedMsg.message,
        isMine: false,
        timestamp: receivedMsg.timestamp, // Preserves the original sender's time
      );
      
      lastHeartbeat[endpointId] = DateTime.now();
      _messages.add(displayMsg);
    } catch (e) {
      if (kDebugMode) debugPrint("Error decoding payload: $e");
    }
  }

  void sendMessage(String msg) {
    if (connectedUsers.isEmpty) return;
    
    // 1. Create message object (captures current time)
    final chatMsg = ChatMessage(
      senderName: userName,
      message: msg,
      isMine: true,
    );

    try {
      // 2. Serialize to JSON bytes
      final jsonString = json.encode(chatMsg.toMap());
      final bytes = Uint8List.fromList(utf8.encode(jsonString));
      
      // 3. Broadcast to all peers
      for (final id in connectedUsers.keys) {
        Nearby().sendBytesPayload(id, bytes);
      }
      
      // 4. Update local UI
      _messages.add(chatMsg);
    } catch (e) {
      if (kDebugMode) debugPrint("Error sending message: $e");
    }
  }

  // --- HEALTH & MAINTENANCE ---

  void _startHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final now = DateTime.now();
      bool changed = false;
      
      lastHeartbeat.removeWhere((id, time) {
        if (now.difference(time).inSeconds > 30) {
          connectedUsers.remove(id);
          changed = true;
          return true;
        }
        return false;
      });
      
      if (changed) onNodesChanged?.call(connectedUsers.values.toList());
      if (!_isAdvertising || !_isDiscovering) restartServices();
    });
  }

  void _handleDisconnect(String id) {
    connectedUsers.remove(id);
    lastHeartbeat.remove(id);
    onNodesChanged?.call(connectedUsers.values.toList());
  }

  Future<void> restartServices() async {
    await stopAll();
    await Future.delayed(const Duration(milliseconds: 500));
    await startAdvertising();
    await startDiscovery();
    onServiceStateChanged?.call(true);
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () => restartServices());
  }

  Future<void> stopAll() async {
    _healthCheckTimer?.cancel();
    _reconnectTimer?.cancel();
    await Nearby().stopDiscovery();
    await Nearby().stopAdvertising();
    await Nearby().stopAllEndpoints();
    connectedUsers.clear();
    lastHeartbeat.clear();
    _isAdvertising = false;
    _isDiscovering = false;
  }

  void dispose() {
    stopAll();
    _messages.close();
  }
}