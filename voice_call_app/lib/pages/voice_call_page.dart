import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/simple_webrtc_service.dart';

class VoiceCallPage extends StatefulWidget {
  const VoiceCallPage({super.key});

  @override
  State<VoiceCallPage> createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends State<VoiceCallPage> {
  final SimpleWebRTCService _webRTCService = SimpleWebRTCService();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _serverUrlController = TextEditingController(text: AppConfig().serverUrl);

  bool isConnected = false;
  bool isInCall = false;
  String? myUserId;
  String? incomingCallFrom;
  List<String> availableUsers = [];
  List<String> messages = [];

  @override
  void initState() {
    super.initState();
    _initCallbacks();
  }

  // ---------------------------------------------------------------------------
  // CALLBACK SETUP
  // ---------------------------------------------------------------------------
  void _initCallbacks() {
    _webRTCService.onUsersUpdate = (users) {
      setState(() => availableUsers = users);
      _addMessage("Online users: ${users.length}");
    };

    _webRTCService.onIncomingCall = (from) {
      setState(() => incomingCallFrom = from);
      _showIncomingCallDialog(from);
    };

    _webRTCService.onCallConnected = () {
      setState(() {
        isInCall = true;
        incomingCallFrom = null;
      });
    };

    _webRTCService.onCallEnded = () {
      setState(() {
        isInCall = false;
        incomingCallFrom = null;
        _webRTCService.currentCallWith = null;
      });
    };

    _webRTCService.onMessage = (msg) => _addMessage(msg);

    // ✨ ICE status callback
    _webRTCService.onIceStatus = (status) => _addMessage(status);
  }

  // ---------------------------------------------------------------------------
  // MESSAGE LOGGER
  // ---------------------------------------------------------------------------
  void _addMessage(String msg) {
    setState(() {
      messages.insert(0, "${DateTime.now().toLocal().toString().substring(11, 19)} - $msg");

      if (messages.length > 10) messages.removeLast();
    });
  }

  // ---------------------------------------------------------------------------
  // CONNECT ACTION
  // ---------------------------------------------------------------------------
  Future<void> _connect() async {
    final userId = _userIdController.text.trim();
    final serverUrl = _serverUrlController.text.trim();

    if (userId.isEmpty) {
      _showSnack("Please enter a User ID");
      return;
    }
    if (serverUrl.isEmpty) {
      _showSnack("Please enter a Server URL");
      return;
    }

    try {
      await _webRTCService.connect(serverUrl, userId);

      setState(() {
        isConnected = true;
        myUserId = userId;
      });

      _addMessage("Connected as $userId");
    } catch (e) {
      _addMessage("Connection failed: $e");
      _showSnack("Connection failed: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // CALL USER
  // ---------------------------------------------------------------------------
  void _callUser(String target) {
    _webRTCService.makeCall(target);

    setState(() {
      isInCall = true;
      _webRTCService.currentCallWith = target;
    });

    _showSnack("Calling $target...");
  }

  // ---------------------------------------------------------------------------
  // INCOMING CALL UI
  // ---------------------------------------------------------------------------
  void _showIncomingCallDialog(String from) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.call, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text("Incoming Call"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.blue[100],
              child: Text(
                from[0].toUpperCase(),
                style: TextStyle(fontSize: 32, color: Colors.blue[700], fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Text(from, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("is calling you..."),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _webRTCService.endCall();
            },
            icon: const Icon(Icons.call_end, color: Colors.red),
            label: const Text("Decline"),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _webRTCService.answerCall();
              _webRTCService.userGesturePlayAudio();
            },
            icon: const Icon(Icons.call),
            label: const Text("Answer"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SNACK HELPER
  // ---------------------------------------------------------------------------
  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(duration: const Duration(seconds: 2), content: Text(text)));
  }

  // ---------------------------------------------------------------------------
  // MAIN UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppConfig().appTitle),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[700]!, Colors.blue[50]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: isConnected ? _buildConnectedUI() : _buildConnectForm(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CONNECT FORM (BEFORE CONNECTED)
  // ---------------------------------------------------------------------------
  Widget _buildConnectForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.phone_in_talk, size: 80, color: Colors.white),
        const SizedBox(height: 24),
        const Text("SUN Voice Call", style: TextStyle(fontSize: 26, color: Colors.white)),
        const SizedBox(height: 12),
        const Text("Connect to start calling", style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 40),

        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildTextField(controller: _serverUrlController, label: "Server URL", icon: Icons.dns),
                const SizedBox(height: 16),
                _buildTextField(controller: _userIdController, label: "Your User ID", icon: Icons.person),
                const SizedBox(height: 24),
                _buildButton("Connect", Icons.login, _connect),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // UI AFTER CONNECTING
  // ---------------------------------------------------------------------------
  Widget _buildConnectedUI() {
    return Column(
      children: [
        _buildProfileHeader(),
        const SizedBox(height: 16),

        if (messages.isNotEmpty) _buildStatusMessages(),
        const SizedBox(height: 12),

        _buildUsersHeader(),
        const SizedBox(height: 8),
        Expanded(child: _buildUsersList()),

        if (isInCall) ...[const SizedBox(height: 16), _buildCallPanel()],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // REUSABLE WIDGETS
  // ---------------------------------------------------------------------------
  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.grey[100],
      ),
    );
  }

  Widget _buildButton(String text, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(text, style: const TextStyle(fontSize: 16)),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: _circleIcon(Icons.person),
        title: Text(myUserId ?? ""),
        subtitle: const Text("Connected"),
        trailing: _onlineChip(),
      ),
    );
  }

  Widget _onlineChip() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(12)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(Icons.circle, size: 10, color: Colors.green),
        SizedBox(width: 4),
        Text(
          "Online",
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  Widget _circleIcon(IconData icon) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.blue[100], shape: BoxShape.circle),
    child: Icon(icon, color: Colors.blue[700]),
  );

  Widget _buildStatusMessages() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 180,
          child: ListView(
            children: messages.map((m) => Text(m, style: TextStyle(color: Colors.grey[700], fontSize: 11))).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildUsersHeader() {
    return Row(
      children: [
        const Text("Available Users", style: TextStyle(fontSize: 18, color: Colors.white)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Text(
            "${availableUsers.length}",
            style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildUsersList() {
    if (availableUsers.isEmpty) {
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.people_outline, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text("No other users online"),
                SizedBox(height: 4),
                Text(
                  "Open another browser tab with another User ID",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: availableUsers.length,
      itemBuilder: (_, i) {
        final user = availableUsers[i];
        final isCurrentCall = _webRTCService.currentCallWith == user;

        return Card(
          child: ListTile(
            leading: Stack(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    user[0].toUpperCase(),
                    style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.bold),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            title: Text(user),
            subtitle: Text(
              isCurrentCall ? "In call" : "Available",
              style: TextStyle(color: isCurrentCall ? Colors.green : Colors.grey),
            ),
            trailing: isInCall
                ? Text(isCurrentCall ? "Connected" : "Busy", style: TextStyle(color: Colors.grey[600]))
                : ElevatedButton.icon(
                    onPressed: () => _callUser(user),
                    icon: const Icon(Icons.call),
                    label: const Text("Call"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildCallPanel() {
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.phone_in_talk, size: 40, color: Colors.green[700]),
            const SizedBox(height: 8),
            const Text("Call in Progress", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text("with ${_webRTCService.currentCallWith}", style: TextStyle(color: Colors.green[700])),
            const SizedBox(height: 16),
            _buildButton("End Call", Icons.call_end, () {
              _webRTCService.endCall();
            }),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CLEANUP
  // ---------------------------------------------------------------------------
  @override
  void dispose() {
    _webRTCService.dispose();
    _userIdController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }
}
