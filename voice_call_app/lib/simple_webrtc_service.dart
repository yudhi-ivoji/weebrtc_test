import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:html' as html; // hanya akan dipakai jika kIsWeb

class SimpleWebRTCService {
  IO.Socket? socket;
  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;

  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer(); // mobile/video

  String? myUserId;
  String? currentCallWith;

  Function(List<String>)? onUsersUpdate;
  Function(String)? onIncomingCall;
  Function()? onCallConnected;
  Function()? onCallEnded;
  Function(String)? onMessage;

  final Map<String, dynamic> configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {
        'urls': 'turn:pefindo.gozila.id:3478?transport=udp',
        'username': 'admin',
        'credential': 'password123',
      }
    ]
  };

  Future<void> initRenderer() async {
    await remoteRenderer.initialize();
  }

  // =================== CONNECT ===================
  Future<void> connect(String serverUrl, String userId) async {
    myUserId = userId;
    await initRenderer();

    socket = IO.io(serverUrl, {
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket!.onConnect((_) {
      print("✅ Connected to signaling server");
      socket!.emit("register", userId);
    });

    socket!.on("users", (data) {
      List<String> users = List<String>.from(data);
      users.remove(myUserId);
      onUsersUpdate?.call(users);
    });

    socket!.on("call-offer", (data) async {
      currentCallWith = data["from"];
      onIncomingCall?.call(currentCallWith!);
      await _handleCallOffer(data["offer"]);
    });

    socket!.on("call-answer", (data) async {
      await peerConnection?.setRemoteDescription(
        RTCSessionDescription(data["answer"]["sdp"], data["answer"]["type"]),
      );
      onCallConnected?.call();
    });

    socket!.on("ice-candidate", (data) async {
      try {
        await peerConnection?.addCandidate(
          RTCIceCandidate(
            data["candidate"]["candidate"],
            data["candidate"]["sdpMid"],
            data["candidate"]["sdpMLineIndex"],
          ),
        );
      } catch (e) {
        print("❌ addCandidate error: $e");
      }
    });

    socket!.on("call-ended", (_) => endCall());
  }

  // =================== LOCAL STREAM ===================
  Future<bool> initLocalStream() async {
    try {
      localStream = await navigator.mediaDevices.getUserMedia({
        "audio": true,
        "video": false,
      });

      if (localStream!.getAudioTracks().isEmpty) {
        onMessage?.call("❌ Mic tidak aktif");
        return false;
      }

      print("🎤 Local mic OK");
      return true;
    } catch (e) {
      onMessage?.call("❌ Mic tidak bisa diakses: $e");
      return false;
    }
  }

  // =================== MAKE CALL ===================
  Future<void> makeCall(String targetUserId) async {
    currentCallWith = targetUserId;
    if (!await initLocalStream()) return;

    peerConnection = await createPeerConnection(configuration);
    _setupPeerConnection(targetUserId);

    final offer = await peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });

    await peerConnection!.setLocalDescription(offer);

    socket!.emit("call-offer", {
      "to": targetUserId,
      "from": myUserId,
      "offer": {"sdp": offer.sdp, "type": offer.type},
    });
  }

  // =================== HANDLE INCOMING OFFER ===================
  Future<void> _handleCallOffer(Map offer) async {
    if (!await initLocalStream()) return;

    peerConnection = await createPeerConnection(configuration);
    _setupPeerConnection(currentCallWith!);

    await peerConnection!.setRemoteDescription(
      RTCSessionDescription(offer["sdp"], offer["type"]),
    );
  }

  // =================== ANSWER CALL ===================
  Future<void> answerCall() async {
    if (peerConnection == null) return;

    final answer = await peerConnection!.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });

    await peerConnection!.setLocalDescription(answer);

    socket!.emit("call-answer", {
      "to": currentCallWith,
      "from": myUserId,
      "answer": {"sdp": answer.sdp, "type": answer.type},
    });

    onCallConnected?.call();
  }

  // =================== END CALL ===================
  void endCall() {
    remoteRenderer.srcObject = null;

    localStream?.getTracks().forEach((t) => t.stop());
    remoteStream?.getTracks().forEach((t) => t.stop());

    peerConnection?.close();

    localStream = null;
    remoteStream = null;
    peerConnection = null;

    if (currentCallWith != null) {
      socket?.emit("end-call", {"to": currentCallWith, "from": myUserId});
    }

    currentCallWith = null;
    onCallEnded?.call();
  }

  void dispose() {
    endCall();
    remoteRenderer.dispose();
    socket?.disconnect();
  }

  // =================== PRIVATE HELPERS ===================
  void _setupPeerConnection(String targetUserId) {
    // Add local tracks
    localStream!.getTracks().forEach((track) {
      peerConnection!.addTrack(track, localStream!);
    });

    // ICE candidate
    peerConnection!.onIceCandidate = (c) {
      if (c != null) {
        print("📡 ICE Candidate → ${c.candidate}");
        socket!.emit("ice-candidate", {
          "to": targetUserId,
          "from": myUserId,
          "candidate": {
            "candidate": c.candidate,
            "sdpMid": c.sdpMid,
            "sdpMLineIndex": c.sdpMLineIndex,
          }
        });
      }
    };

    // ICE state logging
    peerConnection!.onIceConnectionState = (state) {
      print("🔍 ICE State → $state");
    };

    // Remote track handling
    peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams.first;

        // Mobile / Video
        remoteRenderer.srcObject = remoteStream;

        // Web Audio
        if (kIsWeb) {
          try {
            final audio = html.AudioElement()
              ..autoplay = true
              ..controls = false
              ..srcObject = remoteStream as dynamic;
            html.document.body!.append(audio);
          } catch (_) {
            // skip
          }
        }

        print("🔊 Remote audio attached and playing");
      }
    };
  }
}
