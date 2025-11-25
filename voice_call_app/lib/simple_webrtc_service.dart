import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SimpleWebRTCService {
  IO.Socket? socket;
  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;

  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer(); // <-- untuk audios

  String? myUserId;
  String? currentCallWith;

  Function(List<String>)? onUsersUpdate;
  Function(String)? onIncomingCall;
  Function()? onCallConnected;
  Function()? onCallEnded;
  Function(String)? onMessage;

  // ICE config
  final Map<String, dynamic> configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
  };

  // Initialize renderer for audio output
  Future<void> initRenderer() async {
    await remoteRenderer.initialize();
  }

  // =======================================================================
  // CONNECT
  // =======================================================================

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

  // =======================================================================
  // LOCAL STREAM
  // =======================================================================

  Future<bool> initLocalStream() async {
    try {
      localStream = await navigator.mediaDevices.getUserMedia({
        "audio": true,
        "video": false,
      });

      print("🎤 Local mic OK");
      return true;
    } catch (e) {
      onMessage?.call("Mic tidak bisa diakses: $e");
      return false;
    }
  }

  // =======================================================================
  // MAKE CALL
  // =======================================================================

  Future<void> makeCall(String targetUserId) async {
    currentCallWith = targetUserId;

    if (!await initLocalStream()) return;

    peerConnection = await createPeerConnection(configuration);

    for (var track in localStream!.getTracks()) {
      peerConnection!.addTrack(track, localStream!);
    }

    peerConnection!.onIceCandidate = (c) {
      if (c != null) {
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

    peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams.first;

        // Play audio using RTCVideoRenderer
        remoteRenderer.srcObject = remoteStream;

        print("🔊 Remote audio attached to renderer");
      }
    };

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

  // =======================================================================
  // HANDLE INCOMING OFFER
  // =======================================================================

  Future<void> _handleCallOffer(Map offer) async {
    if (!await initLocalStream()) return;

    peerConnection = await createPeerConnection(configuration);

    localStream!.getTracks().forEach((track) {
      peerConnection!.addTrack(track, localStream!);
    });

    peerConnection!.onIceCandidate = (c) {
      if (c != null) {
        socket!.emit("ice-candidate", {
          "to": currentCallWith,
          "from": myUserId,
          "candidate": {
            "candidate": c.candidate,
            "sdpMid": c.sdpMid,
            "sdpMLineIndex": c.sdpMLineIndex,
          },
        });
      }
    };

    peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams.first;
        remoteRenderer.srcObject = remoteStream;
      }
    };

    await peerConnection!.setRemoteDescription(
      RTCSessionDescription(offer["sdp"], offer["type"]),
    );
  }

  // =======================================================================
  // ANSWER CALL
  // =======================================================================

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

  // =======================================================================
  // END CALL
  // =======================================================================

  void endCall() {
    remoteRenderer.srcObject = null;

    localStream?.getTracks().forEach((t) => t.stop());
    remoteStream?.getTracks().forEach((t) => t.stop());

    peerConnection?.close();

    localStream = null;
    remoteStream = null;
    peerConnection = null;

    socket?.emit("end-call", {
      "to": currentCallWith,
      "from": myUserId,
    });

    currentCallWith = null;
    onCallEnded?.call();
  }

  void dispose() {
    endCall();
    remoteRenderer.dispose();
    socket?.disconnect();
  }
}
