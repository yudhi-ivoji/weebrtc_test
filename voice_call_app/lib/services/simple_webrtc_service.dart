import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:logger/logger.dart' show Logger;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:sun_internet_call_app/config/app_config.dart' show AppConfig;

class SimpleWebRTCService {
  IO.Socket? socket;
  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream; // <-- tetap MediaStream

  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  String? myUserId;
  String? currentCallWith;

  Function(List<String>)? onUsersUpdate;
  Function(String)? onIncomingCall;
  Function()? onCallConnected;
  Function()? onCallEnded;
  Function(String)? onMessage;

  Function(String)? onIceStatus;

  var logger = Logger();

  final Map<String, dynamic> configuration = {
    'iceServers': [
      {'urls': AppConfig().stunUrl},
      {'urls': AppConfig().turnUrl, 'username': AppConfig().turnUsername, 'credential': AppConfig().turnPassword},
    ],
    'sdpSemantics': 'unified-plan',
  };

  Future<void> initRenderer() async {
    await remoteRenderer.initialize();
    if (kIsWeb) remoteRenderer.muted = false;
    logger.i('✅ Renderer initialized');
  }

  Future<void> connect(String serverUrl, String userId) async {
    myUserId = userId;
    await initRenderer();

    socket = IO.io(serverUrl, {
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket!.onConnect((_) {
      logger.i('✅ Connected to signaling server');
      socket!.emit('register', userId);
      onMessage?.call('Connected to server');
    });

    socket!.on('users', (data) {
      List<String> users = List<String>.from(data);
      users.remove(myUserId);
      onUsersUpdate?.call(users);
    });

    socket!.on('call-offer', (data) async {
      currentCallWith = data['from'];
      onIncomingCall?.call(currentCallWith!);
      await _handleCallOffer(data['offer']);
    });

    socket!.on('call-answer', (data) async {
      await peerConnection?.setRemoteDescription(RTCSessionDescription(data['answer']['sdp'], data['answer']['type']));
    });

    socket!.on('ice-candidate', (data) async {
      if (peerConnection != null && data['candidate'] != null) {
        await peerConnection!.addCandidate(
          RTCIceCandidate(
            data['candidate']['candidate'],
            data['candidate']['sdpMid'],
            data['candidate']['sdpMLineIndex'],
          ),
        );
      }
    });

    socket!.on('call-ended', (_) => endCall());
  }

  Future<bool> initLocalStream() async {
    if (localStream != null) return true;

    try {
      localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {'echoCancellation': true, 'noiseSuppression': true, 'autoGainControl': true},
        'video': false,
      });
      localStream!.getAudioTracks().forEach((t) => t.enabled = true);
      return true;
    } catch (e) {
      onMessage?.call('❌ Failed to access mic: $e');
      return false;
    }
  }

  Future<void> makeCall(String targetUserId) async {
    currentCallWith = targetUserId;
    if (!await initLocalStream()) return;

    peerConnection = await createPeerConnection(configuration);
    _setupPeerConnection(targetUserId);

    final offer = await peerConnection!.createOffer({'offerToReceiveAudio': true, 'offerToReceiveVideo': false});
    await peerConnection!.setLocalDescription(offer);

    socket!.emit('call-offer', {
      'to': targetUserId,
      'from': myUserId,
      'offer': {'sdp': offer.sdp, 'type': offer.type},
    });

    onMessage?.call('📤 Offer sent to $targetUserId');
  }

  Future<void> _handleCallOffer(Map offer) async {
    if (!await initLocalStream()) return;

    peerConnection = await createPeerConnection(configuration);
    _setupPeerConnection(currentCallWith!);

    await peerConnection!.setRemoteDescription(RTCSessionDescription(offer['sdp'], offer['type']));
  }

  Future<void> answerCall() async {
    if (peerConnection == null) return;

    final answer = await peerConnection!.createAnswer({'offerToReceiveAudio': true, 'offerToReceiveVideo': false});
    await peerConnection!.setLocalDescription(answer);

    socket!.emit('call-answer', {
      'to': currentCallWith,
      'from': myUserId,
      'answer': {'sdp': answer.sdp, 'type': answer.type},
    });

    onCallConnected?.call();
    onMessage?.call('Call answered');
  }

  /// Penting: harus dipanggil saat user klik tombol Answer
  void userGesturePlayAudio() {
    if (kIsWeb && remoteStream != null) {
      remoteStream!.getAudioTracks().forEach((track) => track.enabled = true);
      logger.i('✅ Audio unmuted via user gesture');
    }
  }

  void endCall() {
    if (currentCallWith != null) {
      socket?.emit('end-call', {'to': currentCallWith, 'from': myUserId});
    }

    localStream?.getTracks().forEach((t) => t.stop());
    remoteStream?.getAudioTracks().forEach((t) => t.enabled = false);
    peerConnection?.close();

    localStream = null;
    remoteStream = null;
    peerConnection = null;

    onCallEnded?.call();
  }

  void dispose() {
    endCall();
    remoteRenderer.dispose();
    socket?.disconnect();
  }

  void _setupPeerConnection(String targetUserId) {
    if (localStream == null) return;

    localStream!.getTracks().forEach((track) {
      peerConnection!.addTrack(track, localStream!);
    });

    peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        socket!.emit('ice-candidate', {
          'to': targetUserId,
          'from': myUserId,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        });

        // ICE candidate generated → bisa jadi indikasi server berhasil digunakan
        onIceStatus?.call('ICE candidate from: ${candidate.candidate}');
      }
    };

    peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams.first;
        remoteRenderer.srcObject = remoteStream;
        logger.i('✅ Remote stream attached');
      }
    };

    peerConnection!.onIceConnectionState = (state) {
      logger.i('ICE Connection State: $state');
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
          onIceStatus?.call('✅ ICE connected successfully');
          break;
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          onIceStatus?.call('❌ ICE failed. Possible STUN/TURN issue');
          break;
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          onIceStatus?.call('⚠️ ICE disconnected');
          break;
        default:
          onIceStatus?.call('ICE state: $state');
      }
    };
  }
}
