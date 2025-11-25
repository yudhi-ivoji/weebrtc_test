import 'package:flutter/material.dart';
import 'simple_webrtc_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SUN Internet Call v1.0.2',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const VoiceCallPage(),
    );
  }
}

class VoiceCallPage extends StatefulWidget {
  const VoiceCallPage({Key? key}) : super(key: key);

  @override
  State<VoiceCallPage> createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends State<VoiceCallPage> {
  final SimpleWebRTCService _webRTCService = SimpleWebRTCService();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _serverUrlController = TextEditingController(
    text: 'https://fdc.gozila.id',
  );

  bool isConnected = false;
  bool isInCall = false;
  String? myUserId;
  String? incomingCallFrom;
  List<String> availableUsers = [];
  List<String> messages = [];

  @override
  void initState() {
    super.initState();
    _setupCallbacks();
  }

  void _setupCallbacks() {
    _webRTCService.onUsersUpdate = (users) {
      setState(() {
        availableUsers = users;
      });
      _addMessage('Online users: ${users.length}');
    };

    _webRTCService.onIncomingCall = (from) {
      setState(() {
        incomingCallFrom = from;
      });
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
      });
    };

    _webRTCService.onMessage = (message) {
      _addMessage(message);
    };
  }

  void _addMessage(String message) {
    setState(() {
      messages.insert(0, '${DateTime.now().toLocal().toString().substring(11, 19)} - $message');
      if (messages.length > 10) {
        messages.removeLast();
      }
    });
  }

  Future<void> _connect() async {
    String userId = _userIdController.text.trim();
    String serverUrl = _serverUrlController.text.trim();

    if (userId.isEmpty) {
      _showMessage('Please enter a User ID');
      return;
    }

    if (serverUrl.isEmpty) {
      _showMessage('Please enter Server URL');
      return;
    }

    try {
      await _webRTCService.connect(serverUrl, userId);
      setState(() {
        isConnected = true;
        myUserId = userId;
      });
      _showMessage('Connected as $userId');
      _addMessage('Connected to server');
    } catch (e) {
      _showMessage('Connection failed: $e');
      _addMessage('Connection failed: $e');
    }
  }

  void _makeCall(String targetUserId) {
    _webRTCService.makeCall(targetUserId);
    _showMessage('Calling $targetUserId...');
  }

  void _showIncomingCallDialog(String from) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.call, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            const Text('Incoming Call'),
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
                style: TextStyle(
                  fontSize: 32,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              from,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text('is calling you...'),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _webRTCService.endCall();
            },
            icon: const Icon(Icons.call_end, color: Colors.red),
            label: const Text('Decline'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _webRTCService.answerCall();
              _webRTCService.userGesturePlayAudio();
            },
            icon: const Icon(Icons.call),
            label: const Text('Answer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SUN Voice Call v1.0.2'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[700]!, Colors.blue[50]!],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isConnected) ...[
                const SizedBox(height: 20),
                const Icon(
                  Icons.phone_in_talk,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 24),
                const Text(
                  'SUN Voice Call',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Connect to start calling',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 40),
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _serverUrlController,
                          decoration: InputDecoration(
                            labelText: 'Server URL',
                            border: const OutlineInputBorder(),
                            hintText: 'http://localhost:3000',
                            prefixIcon: const Icon(Icons.dns),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _userIdController,
                          decoration: InputDecoration(
                            labelText: 'Your User ID',
                            border: const OutlineInputBorder(),
                            hintText: 'e.g., user1',
                            prefixIcon: const Icon(Icons.person),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _connect,
                            icon: const Icon(Icons.login),
                            label: const Text(
                              'Connect',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Card(
                  elevation: 2,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Connected as',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                myUserId!,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 8,
                                color: Colors.green,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Online',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Status messages
                if (messages.isNotEmpty) ...[
                  Card(
                    elevation: 2,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, 
                                size: 16, 
                                color: Colors.blue[700],
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Status Messages',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 60,
                            child: ListView.builder(
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    messages[index],
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                Row(
                  children: [
                    const Text(
                      'Available Users',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${availableUsers.length}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                Expanded(
                  child: availableUsers.isEmpty
                      ? Center(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No other users online',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Open another browser tab and connect with a different user ID',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: availableUsers.length,
                          itemBuilder: (context, index) {
                            String userId = availableUsers[index];
                            bool isCurrentCall = _webRTCService.currentCallWith == userId;
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 2,
                              child: ListTile(
                                leading: Stack(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.blue[100],
                                      child: Text(
                                        userId[0].toUpperCase(),
                                        style: TextStyle(
                                          color: Colors.blue[700],
                                          fontWeight: FontWeight.bold,
                                        ),
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
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                title: Text(
                                  userId,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  isCurrentCall ? 'In call' : 'Available',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isCurrentCall ? Colors.green : Colors.grey,
                                  ),
                                ),
                                trailing: isInCall
                                    ? Text(
                                        isCurrentCall ? 'Connected' : 'In call',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      )
                                    : ElevatedButton.icon(
                                        onPressed: () => _makeCall(userId),
                                        icon: const Icon(Icons.call, size: 18),
                                        label: const Text('Call'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                ),
                
                if (isInCall) ...[
                  const SizedBox(height: 16),
                  Card(
                    elevation: 4,
                    color: Colors.green[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.phone_in_talk,
                            size: 40,
                            color: Colors.green[700],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Call in Progress',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[900],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'with ${_webRTCService.currentCallWith}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green[700],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _webRTCService.endCall();
                              },
                              icon: const Icon(Icons.call_end),
                              label: const Text(
                                'End Call',
                                style: TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _webRTCService.dispose();
    _userIdController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }
}