import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  
  // Konfigurasi ICE servers (STUN/TURN)
  final Map<String, dynamic> configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ]
  };
  
  // Inisialisasi local audio stream
  Future<void> initLocalStream() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': false, // voice only
    };
    
    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
  }
  
  // Setup peer connection - UBAH NAMA METHOD
  Future<void> setupPeerConnection() async {
    // Panggil fungsi global dari flutter_webrtc package
    _peerConnection = await createPeerConnection(configuration);
    
    // Add local stream ke peer connection
    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });
    
    // Handle incoming stream
    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        // Play remote audio
        event.streams[0].getTracks().forEach((track) {
          print('Remote track: ${track.kind}');
        });
      }
    };
    
    // Handle ICE candidates
    _peerConnection?.onIceCandidate = (RTCIceCandidate? candidate) {
      // Kirim candidate ke peer melalui signaling server
      if (candidate != null) {
        print('New ICE candidate: ${candidate.candidate}');
      }
    };
  }
  
  // Cleanup
  void dispose() {
    _localStream?.dispose();
    _peerConnection?.close();
  }
}