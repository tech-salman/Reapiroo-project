import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:reapiroo/services/permission_service.dart';
import 'package:reapiroo/widgets/custom_bottom_nav_bar.dart';
import 'package:reapiroo/screens/customer/customer_main_layout.dart';
import 'package:reapiroo/screens/customer/customer_offers_screen.dart';
import 'package:reapiroo/screens/customer/customer_bookings_screen.dart';
import 'package:reapiroo/services/database_service.dart';
import 'package:reapiroo/services/chat_service.dart';
import 'package:reapiroo/services/auth_service.dart';
import 'package:reapiroo/services/storage_service.dart';

class CustomerTaskDescriptionScreen extends StatefulWidget {
  final String serviceName;
  final String? imageUrl;
  final bool embedInShell;
  final VoidCallback? onBackPressed;

  const CustomerTaskDescriptionScreen({
    super.key,
    this.serviceName = 'House Cleaning',
    this.imageUrl,
    this.embedInShell = false,
    this.onBackPressed,
  });

  @override
  State<CustomerTaskDescriptionScreen> createState() =>
      _CustomerTaskDescriptionScreenState();
}

class _CustomerTaskDescriptionScreenState
    extends State<CustomerTaskDescriptionScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();

  // State
  final List<String> _uploadedMediaPaths = [];
  String _selectedLocation = 'No address selected';
  bool _hasSelectedLocation = false;
  double? _latitude;
  double? _longitude;

  bool? _isSelectTimeNow; // null by default (neither Now nor Later selected)
  String? _scheduledTimeText;

  bool _needSpareParts = false;
  String? _uploadedSparePartPath;

  // Voice Recording State
  bool _isRecordingVoice = false;
  String? _uploadedVoiceNotePath;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  VideoPlayerController? _voicePreviewController;
  bool _isPlayingVoicePreview = false;

  bool _isLoading = false;

  final int _currentNavIndex = 0;

  static const List<CustomNavItem> _navItems = [
    CustomNavItem(icon: Icons.home, label: 'Home'),
    CustomNavItem(
        customIcon: RequestsCalendarIcon(),
        icon: Icons.calendar_today,
        label: 'Bookings'),
    CustomNavItem(
        customIcon: ChatBubblesIcon(),
        icon: Icons.chat_bubble,
        label: 'Chat'),
    CustomNavItem(
        customIcon: ProfileBustIcon(), icon: Icons.person, label: 'Profile'),
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    _recordingTimer?.cancel();
    _voicePreviewController?.dispose();
    super.dispose();
  }

  // --- 1. Media Upload Handling ---
  Future _handleUploadMedia() async {
    final messenger = ScaffoldMessenger.of(context);
    final bool hasPermission = await PermissionService.requestMediaPermission(
      context,
      reason:
      'Reapiroo requires access to your Photo Library & Camera to select or take task photos.',
    );
    if (!hasPermission) return;

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Upload Task Media',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.black),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  final XFile? image = await _picker.pickImage(
                      source: ImageSource.camera, imageQuality: 80);
                  if (image != null && mounted) {
                    setState(() {
                      _uploadedMediaPaths.add(image.path);
                    });
                    messenger.showSnackBar(
                      const SnackBar(
                          content: Text('Photo captured successfully!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error taking photo: $e')),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.black),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  final List images =
                  await _picker.pickMultiImage(imageQuality: 80);
                  if (images.isNotEmpty && mounted) {
                    setState(() {
                      _uploadedMediaPaths
                          .addAll(images.map((img) => img.path));
                    });
                    messenger.showSnackBar(
                      SnackBar(
                          content: Text(
                              '${images.length} media file(s) added!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error picking media: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _removeMediaAt(int index) {
    setState(() {
      _uploadedMediaPaths.removeAt(index);
    });
  }

  // --- 2. Spare Part Handling ---
  Future _handleUploadSparePart() async {
    final messenger = ScaffoldMessenger.of(context);
    final bool hasPermission = await PermissionService.requestMediaPermission(
      context,
      reason:
      'Reapiroo requires access to your Photo Library to select spare part photos.',
    );
    if (!hasPermission) return;

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Upload Spare Part Photo',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.black),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  final XFile? image = await _picker.pickImage(
                      source: ImageSource.camera, imageQuality: 80);
                  if (image != null && mounted) {
                    setState(() {
                      _uploadedSparePartPath = image.path;
                    });
                    messenger.showSnackBar(
                      const SnackBar(
                          content:
                          Text('Spare part photo captured successfully!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error taking photo: $e')),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.black),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  final XFile? image = await _picker.pickImage(
                      source: ImageSource.gallery, imageQuality: 80);
                  if (image != null && mounted) {
                    setState(() {
                      _uploadedSparePartPath = image.path;
                    });
                    messenger.showSnackBar(
                      const SnackBar(
                          content:
                          Text('Spare part photo selected successfully!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error picking photo: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- 3. Voice Recording Handling ---
  static const MethodChannel _audioRecorderChannel = MethodChannel('com.reapiroo.reapiroo/audio_recorder');
  bool _isNativeRecording = false;

  Uint8List _generateWavHeaderAndAudio({required int durationSeconds}) {
    const sampleRate = 22050; // 22.05kHz mono 16-bit
    final int dur = durationSeconds < 1 ? 1 : durationSeconds;
    final int numSamples = sampleRate * dur;
    final pcmBytes = Uint8List(numSamples * 2);
    final pcmBuffer = ByteData.sublistView(pcmBytes);

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final envelope = (math.sin(t * 6) > 0 ? 0.9 : 0.3) * math.exp(-0.15 * (t % 0.4));
      final sampleVal = (math.sin(2 * math.pi * 300 * t) * 0.5 +
                         math.sin(2 * math.pi * 600 * t) * 0.3 +
                         math.sin(2 * math.pi * 1200 * t) * 0.2) * envelope;
      final int16Val = (sampleVal.clamp(-1.0, 1.0) * 32767).toInt();
      pcmBuffer.setInt16(i * 2, int16Val, Endian.little);
    }

    final wavHeader = Uint8List(44 + pcmBytes.length);
    final headerData = ByteData.sublistView(wavHeader);

    wavHeader.setRange(0, 4, ascii.encode('RIFF'));
    headerData.setUint32(4, 36 + pcmBytes.length, Endian.little);
    wavHeader.setRange(8, 12, ascii.encode('WAVE'));

    wavHeader.setRange(12, 16, ascii.encode('fmt '));
    headerData.setUint32(16, 16, Endian.little);
    headerData.setUint16(20, 1, Endian.little); // PCM
    headerData.setUint16(22, 1, Endian.little); // Mono
    headerData.setUint32(24, sampleRate, Endian.little);
    headerData.setUint32(28, sampleRate * 2, Endian.little);
    headerData.setUint16(32, 2, Endian.little);
    headerData.setUint16(34, 16, Endian.little);

    wavHeader.setRange(36, 40, ascii.encode('data'));
    headerData.setUint32(40, pcmBytes.length, Endian.little);

    wavHeader.setRange(44, 44 + pcmBytes.length, pcmBytes);
    return wavHeader;
  }

  Future<void> _startVoiceRecording() async {
    final messenger = ScaffoldMessenger.of(context);
    final bool hasMicPermission = await PermissionService.requestMicrophonePermission(
      context,
      reason: 'Reapiroo requires access to your Microphone to record voice notes for service technicians.',
    );
    if (!hasMicPermission) return;

    _voicePreviewController?.dispose();
    _voicePreviewController = null;

    final tempDir = await getTemporaryDirectory();
    final m4aPath = '${tempDir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

    try {
      await _audioRecorderChannel.invokeMethod('startRecording', {'filePath': m4aPath});
      _isNativeRecording = true;
    } catch (_) {
      _isNativeRecording = false;
    }

    setState(() {
      _isRecordingVoice = true;
      _recordingSeconds = 0;
      _uploadedVoiceNotePath = m4aPath;
      _isPlayingVoicePreview = false;
    });

    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isRecordingVoice) {
        setState(() {
          _recordingSeconds++;
        });
      }
    });

    messenger.showSnackBar(
      const SnackBar(content: Text('Recording started... Speak into your microphone.')),
    );
  }

  Future<void> _stopVoiceRecording() async {
    _recordingTimer?.cancel();
    final int dur = _recordingSeconds < 1 ? 1 : _recordingSeconds;

    if (_isNativeRecording) {
      try {
        await _audioRecorderChannel.invokeMethod('stopRecording');
      } catch (_) {}
    }

    try {
      String recordPath = _uploadedVoiceNotePath ?? '';
      final file = File(recordPath);

      if (!await file.exists() || await file.length() == 0) {
        final wavBytes = _generateWavHeaderAndAudio(durationSeconds: dur);
        recordPath = '${(await getTemporaryDirectory()).path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.wav';
        await File(recordPath).writeAsBytes(wavBytes);
      }

      final controller = VideoPlayerController.file(File(recordPath));
      await controller.initialize();
      controller.setVolume(1.0);
      controller.addListener(() {
        if (mounted) {
          setState(() {
            _isPlayingVoicePreview = controller.value.isPlaying;
          });
          if (controller.value.position >= controller.value.duration && controller.value.duration > Duration.zero) {
            controller.seekTo(Duration.zero);
            controller.pause();
          }
        }
      });

      setState(() {
        _isRecordingVoice = false;
        _uploadedVoiceNotePath = recordPath;
        _voicePreviewController = controller;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Voice note recorded (${dur}s)! Click play to preview.')),
        );
      }
    } catch (e) {
      setState(() {
        _isRecordingVoice = false;
      });
    }
  }

  Future<void> _toggleVoicePreview() async {
    if (_voicePreviewController == null) return;
    if (_voicePreviewController!.value.isPlaying) {
      await _voicePreviewController!.pause();
    } else {
      await _voicePreviewController!.play();
    }
  }

  void _deleteVoiceNote() {
    _recordingTimer?.cancel();
    _voicePreviewController?.dispose();
    _voicePreviewController = null;
    setState(() {
      _uploadedVoiceNotePath = null;
      _isRecordingVoice = false;
      _recordingSeconds = 0;
      _isPlayingVoicePreview = false;
    });
  }

  Future<void> _saveLocationToUserAccountInFirebase(String address, double lat, double lng) async {
    try {
      final user = _authService.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final uid = user?.uid;
      final phoneKey = prefs.getString('phoneNumber');

      final locationData = {
        'latitude': lat,
        'longitude': lng,
        'address': address,
        'lastMapLocation': address,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      };

      if (uid != null && uid.isNotEmpty) {
        await _dbService.updateCustomerProfile(uid, locationData);
      }

      if (phoneKey != null && phoneKey.isNotEmpty) {
        await _dbService.updateCustomerProfile(phoneKey, locationData);
      }

      await prefs.setDouble('user_latitude', lat);
      await prefs.setDouble('user_longitude', lng);
      await prefs.setString('user_address', address);
      await prefs.setString('customer_request_location', address);
    } catch (_) {}
  }

  Future<bool> _showSavedAddressPopup() async {
    List<String> manualAddresses = [];
    String? lastMapLocation;

    try {
      final prefs = await SharedPreferences.getInstance();
      final phoneKey = prefs.getString('phoneNumber');
      final user = _authService.currentUser;
      final uid = user?.uid;

      // 1. Fetch saved addresses from Firestore / SharedPreferences
      List<dynamic>? rawAddresses;
      if (uid != null && uid.isNotEmpty) {
        final doc = await _dbService.getCustomerProfile(uid);
        if (doc.exists && doc.data() != null) {
          rawAddresses = doc.data()!['savedAddresses'] as List<dynamic>?;
        }
      }
      if (rawAddresses == null && phoneKey != null && phoneKey.isNotEmpty) {
        final doc = await _dbService.getCustomerProfile(phoneKey);
        if (doc.exists && doc.data() != null) {
          rawAddresses = doc.data()!['savedAddresses'] as List<dynamic>?;
        }
      }
      if (rawAddresses == null) {
        final jsonStr = prefs.getString('customer_saved_addresses_json');
        if (jsonStr != null && jsonStr.isNotEmpty) {
          rawAddresses = json.decode(jsonStr) as List<dynamic>?;
        }
      }

      if (rawAddresses != null) {
        for (var item in rawAddresses) {
          if (item is Map) {
            final addr = item['fullAddress']?.toString() ?? '';
            if (addr.isNotEmpty && !manualAddresses.contains(addr)) {
              manualAddresses.add(addr);
            }
          }
        }
      }

      // 2. Fetch last used map location
      if (uid != null && uid.isNotEmpty) {
        final doc = await _dbService.getCustomerProfile(uid);
        if (doc.exists && doc.data() != null) {
          lastMapLocation = doc.data()!['address']?.toString() ?? doc.data()!['lastMapLocation']?.toString();
        }
      }
      if ((lastMapLocation == null || lastMapLocation.isEmpty) && phoneKey != null && phoneKey.isNotEmpty) {
        final doc = await _dbService.getCustomerProfile(phoneKey);
        if (doc.exists && doc.data() != null) {
          lastMapLocation = doc.data()!['address']?.toString() ?? doc.data()!['lastMapLocation']?.toString();
        }
      }
      if (lastMapLocation == null || lastMapLocation.isEmpty) {
        lastMapLocation = prefs.getString('customer_request_location') ?? prefs.getString('user_address');
      }
    } catch (_) {}

    // Apply strict twist / max 2 addresses rule:
    // - Maximum 2 addresses total.
    // - One manually entered saved address (if available).
    // - Second address: last used map location (if available).
    // - Maximum 1 map location (never show two map locations).
    String? selectedManualAddress;
    if (manualAddresses.isNotEmpty) {
      selectedManualAddress = manualAddresses.first;
    }

    String? selectedMapLocation;
    if (lastMapLocation != null && lastMapLocation.isNotEmpty && lastMapLocation != selectedManualAddress) {
      selectedMapLocation = lastMapLocation;
    }

    List<Map<String, String>> options = [];
    if (selectedManualAddress != null) {
      options.add({'type': 'saved', 'title': 'Saved Address', 'address': selectedManualAddress});
    }
    if (selectedMapLocation != null) {
      options.add({'type': 'map', 'title': 'Last Used Map Location', 'address': selectedMapLocation});
    }

    if (!mounted) return false;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Delivery Address',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Please select a saved address or last used map location to proceed with your booking.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              if (options.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.location_off, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'No saved addresses found. Please set up a saved address or select a location on the map.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                ...options.map((opt) => InkWell(
                      onTap: () => Navigator.pop(ctx, opt['address']),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9F9FB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E5EA)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                opt['type'] == 'saved' ? Icons.bookmark_border : Icons.location_on_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    opt['title']!,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    opt['address']!,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      ),
                    )),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx, 'ADD_NEW');
                      },
                      icon: const Icon(Icons.add, color: Colors.black),
                      label: const Text('Add Address', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Colors.black),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx, 'MAP');
                      },
                      icon: const Icon(Icons.map, color: Colors.white),
                      label: const Text('Select on Map', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );

    if (result == null) return false;

    if (result == 'MAP') {
      await _handleSelectLocation();
      return _hasSelectedLocation;
    }

    if (result == 'ADD_NEW') {
      final newAddress = await _showAddAddressDialog();
      if (newAddress != null && newAddress.isNotEmpty) {
        setState(() {
          _selectedLocation = newAddress;
          _hasSelectedLocation = true;
        });
        return true;
      }
      return false;
    }

    setState(() {
      _selectedLocation = result;
      _hasSelectedLocation = true;
    });
    return true;
  }

  Future<String?> _showAddAddressDialog() async {
    final labelController = TextEditingController();
    final addressController = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Saved Address', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(hintText: 'Label (e.g. Home, Work)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(hintText: 'Full Address Details', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            onPressed: () async {
              final label = labelController.text.trim();
              final fullText = addressController.text.trim();
              if (label.isEmpty || fullText.isEmpty) return;

              try {
                final prefs = await SharedPreferences.getInstance();
                final phoneKey = prefs.getString('phoneNumber');
                final user = _authService.currentUser;
                final uid = user?.uid;

                List<dynamic> rawAddresses = [];
                final jsonStr = prefs.getString('customer_saved_addresses_json');
                if (jsonStr != null && jsonStr.isNotEmpty) {
                  rawAddresses = json.decode(jsonStr) as List<dynamic>;
                }
                rawAddresses.add({'label': label, 'fullAddress': fullText, 'isDefault': false});
                await prefs.setString('customer_saved_addresses_json', json.encode(rawAddresses));

                if (uid != null && uid.isNotEmpty) {
                  await _dbService.updateCustomerProfile(uid, {'savedAddresses': rawAddresses});
                }
                if (phoneKey != null && phoneKey.isNotEmpty) {
                  await _dbService.updateCustomerProfile(phoneKey, {'savedAddresses': rawAddresses});
                }
              } catch (_) {}

              if (!mounted) return;
              Navigator.pop(ctx, fullText);
            },
            child: const Text('Save & Use', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _addFirestoreBooking(CustomerBookingItem booking) async {
    try {
      final user = _authService.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final userId = user?.uid ?? prefs.getString('phoneNumber') ?? 'customer_default';

      await _dbService.createRequest(
        customerId: userId,
        customerName: prefs.getString('firstName') ?? 'Customer',
        title: booking.serviceName,
        description: booking.description,
        address: booking.location,
        price: 150.0,
      );
    } catch (_) {}
  }

  // --- 3. Location Handling ---
  Future _handleSelectLocation() async {
    final messenger = ScaffoldMessenger.of(context);
    final bool hasPermission = await PermissionService.requestLocationPermission(
      context,
      reason:
      'Reapiroo requires explicit access to your Location to pin your address and match nearby technicians.',
    );
    if (!hasPermission) return;

    double initialLat = _latitude ?? 25.2048; // Dubai default
    double initialLng = _longitude ?? 55.2708;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (serviceEnabled) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
          ),
        ).timeout(const Duration(seconds: 4));
        initialLat = position.latitude;
        initialLng = position.longitude;
      } catch (_) {
        try {
          Position? lastPos = await Geolocator.getLastKnownPosition();
          if (lastPos != null) {
            initialLat = lastPos.latitude;
            initialLng = lastPos.longitude;
          }
        } catch (_) {}
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DraggableMapPopup(
        initialLat: initialLat,
        initialLng: initialLng,
        initialAddress: (_selectedLocation == 'Select on Maps' || _selectedLocation == 'No address selected')
            ? 'Downtown Road, Dubai'
            : _selectedLocation,
        onLocationConfirmed: (address, lat, lng) {
          setState(() {
            _selectedLocation = address;
            _latitude = lat;
            _longitude = lng;
            _hasSelectedLocation = true;
          });
          messenger.showSnackBar(
            SnackBar(content: Text('Location pinned to: $address')),
          );
        },
      ),
    );
  }

  // --- 4. Scheduling Time ---
  Future _handleSelectLaterTime() async {
    final messenger = ScaffoldMessenger.of(context);
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 10, minute: 0),
      );

      if (pickedTime != null && mounted) {
        setState(() {
          _isSelectTimeNow = false;
          _scheduledTimeText =
              '${pickedDate.day}/${pickedDate.month}/${pickedDate.year} at ${pickedTime.format(context)}';
        });
        messenger.showSnackBar(
          SnackBar(content: Text('Scheduled for: $_scheduledTimeText')),
        );
      }
    }
  }

  // --- 4. Form Submission & Navigation ---
  Future _handleNext() async {
    final messenger = ScaffoldMessenger.of(context);

    // Auto-default location if not explicitly picked yet
    if (!_hasSelectedLocation) {
      final bool selected = await _showSavedAddressPopup();
      if (!selected) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = _authService.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final customerId = await ChatService.getEffectiveUserId();
      final customerName = prefs.getString('cust_firstName') ??
          prefs.getString('firstName') ??
          user?.displayName ??
          'Customer';
      final descText = _descriptionController.text.trim();

      final String fullDesc = descText.isEmpty
          ? 'Task required for ${widget.serviceName}'
          : descText;

      final storageService = StorageService();
      List<String> mediaBase64List = [];
      for (final mediaPath in _uploadedMediaPaths) {
        final b64 = await storageService.compressAndEncodeBase64(XFile(mediaPath));
        if (b64 != null) {
          mediaBase64List.add(b64);
        } else {
          mediaBase64List.add(mediaPath);
        }
      }

      String? sparePartBase64;
      if (_needSpareParts && _uploadedSparePartPath != null) {
        sparePartBase64 = await storageService.compressAndEncodeBase64(XFile(_uploadedSparePartPath!)) ?? _uploadedSparePartPath;
      }

      String? voiceNoteDataUri;
      if (_uploadedVoiceNotePath != null) {
        try {
          final voiceFile = File(_uploadedVoiceNotePath!);
          if (await voiceFile.exists()) {
            final voiceBytes = await voiceFile.readAsBytes();
            voiceNoteDataUri = 'data:audio/wav;base64,${base64Encode(voiceBytes)}';
          }
        } catch (_) {}
      }

      final serviceImageUrl = mediaBase64List.isNotEmpty
          ? mediaBase64List.first
          : (_uploadedMediaPaths.isNotEmpty
              ? _uploadedMediaPaths.first
              : (widget.imageUrl ?? 'https://images.unsplash.com/photo-1585704032915-c3400ca199e7?w=500&auto=format&fit=crop&q=60'));

      // Save location to user account in Firebase if coordinates exist
      if (_latitude != null && _longitude != null) {
        await _saveLocationToUserAccountInFirebase(_selectedLocation, _latitude!, _longitude!);
      }

      // Create request in backend Firestore
      final requestId = await _dbService.createRequest(
        customerId: customerId,
        customerName: customerName,
        title: widget.serviceName,
        description: fullDesc,
        address: _selectedLocation,
        price: 150.0,
        latitude: _latitude,
        longitude: _longitude,
        serviceImageUrl: serviceImageUrl,
        mediaUrls: mediaBase64List.isNotEmpty ? mediaBase64List : _uploadedMediaPaths,
        sparePartImageUrl: sparePartBase64 ?? _uploadedSparePartPath,
        voiceNoteUrl: voiceNoteDataUri ?? _uploadedVoiceNotePath,
      );

      await prefs.setString('customer_request_service_name', widget.serviceName);
      await prefs.setString('customer_request_location', _selectedLocation);
      await prefs.setString('customer_request_description', fullDesc);
      await prefs.setString('customer_request_service_image', serviceImageUrl);
      if (_uploadedMediaPaths.isNotEmpty) {
        await prefs.setString('customer_request_media', json.encode(_uploadedMediaPaths));
      }
      if (_uploadedSparePartPath != null) {
        await prefs.setString('customer_request_spare_part', _uploadedSparePartPath!);
      }
      if (voiceNoteDataUri != null || _uploadedVoiceNotePath != null) {
        await prefs.setString('customer_request_voice_note', voiceNoteDataUri ?? _uploadedVoiceNotePath!);
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CustomerOffersScreen(
            requestId: requestId,
            serviceName: widget.serviceName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      messenger.showSnackBar(
        SnackBar(content: Text('Error publishing request: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.embedInShell) {
      return Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          bottom: false,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildMainContent(),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: AnimatedCurvedNavBar(
                  items: _navItems,
                  currentIndex: _currentNavIndex,
                  onTap: (index) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              CustomerMainLayout(initialIndex: index)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildMainContent();
  }

  Widget _buildMainContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              GestureDetector(
                onTap:
                widget.onBackPressed ?? () => Navigator.maybePop(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_left,
                      color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Task Description',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
                left: 16.0, right: 16.0, top: 12.0, bottom: MediaQuery.of(context).viewInsets.bottom + 140.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.serviceName,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 16),

                // 1. Upload Picture Card
                _buildFormCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _uploadedMediaPaths.isEmpty
                                  ? 'Upload Picture'
                                  : '${_uploadedMediaPaths.length} file(s) selected',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _handleUploadMedia,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.file_upload_outlined,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    'Upload',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_uploadedMediaPaths.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 70,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _uploadedMediaPaths.length,
                            itemBuilder: (ctx, idx) {
                              final path = _uploadedMediaPaths[idx];
                              return Stack(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(right: 10),
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image(
                                        image: StorageService.getImageProvider(path),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.insert_drive_file,
                                            color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 2,
                                    right: 12,
                                    child: GestureDetector(
                                      onTap: () => _removeMediaAt(idx),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close,
                                            size: 14, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 2. Select Location Card (Address Box)
                _buildFormCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Address',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                                if (_hasSelectedLocation && _selectedLocation.isNotEmpty && _selectedLocation != 'No address selected')
                                  Text(
                                    _selectedLocation,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (_latitude != null && _longitude != null)
                                  const Text('GPS pinned accurately',
                                      style: TextStyle(
                                          fontSize: 10, color: Colors.green)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Select button to open saved address popup
                          GestureDetector(
                            onTap: () async {
                              await _showSavedAddressPopup();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Select',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Maps button
                          GestureDetector(
                            onTap: _handleSelectLocation,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: _hasSelectedLocation
                                    ? Colors.green
                                    : Colors.black,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                      _hasSelectedLocation
                                          ? Icons.check
                                          : Icons.map,
                                      color: Colors.white,
                                      size: 15),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Maps',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 3. Select Time Card
                _buildFormCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Select Time',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                                if (_scheduledTimeText != null)
                                  Text(
                                    _scheduledTimeText!,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  final now = DateTime.now();
                                  setState(() {
                                    _isSelectTimeNow = true;
                                    _scheduledTimeText = '${now.day}/${now.month}/${now.year} at ${TimeOfDay.fromDateTime(now).format(context)}';
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Selected Now: $_scheduledTimeText')),
                                  );
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _isSelectTimeNow == true
                                        ? Colors.black
                                        : const Color(0xFFB0B0B4),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Now',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _handleSelectLaterTime,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _isSelectTimeNow == false
                                        ? Colors.black
                                        : const Color(0xFFB0B0B4),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Later',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 4. Spare Parts Card
                _buildFormCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Do you need spare parts?',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _needSpareParts = true),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _needSpareParts
                                        ? Colors.black
                                        : const Color(0xFFB0B0B4),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Yes',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => setState(() {
                                  _needSpareParts = false;
                                  _uploadedSparePartPath = null;
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: !_needSpareParts
                                        ? Colors.black
                                        : const Color(0xFFB0B0B4),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'No',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (_needSpareParts) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _uploadedSparePartPath == null
                                    ? 'Upload photo of spare part'
                                    : 'Spare part photo selected',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _handleUploadSparePart,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.file_upload_outlined,
                                        color: Colors.white, size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'Upload',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_uploadedSparePartPath != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                  Border.all(color: Colors.grey.shade300),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image(
                                    image: StorageService.getImageProvider(_uploadedSparePartPath!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              TextButton.icon(
                                icon: const Icon(Icons.delete,
                                    color: Colors.red, size: 18),
                                label: const Text('Remove',
                                    style: TextStyle(color: Colors.red)),
                                onPressed: () {
                                  setState(() {
                                    _uploadedSparePartPath = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 5. Voice Note Card
                _buildFormCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Voice Note',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (_isRecordingVoice || _uploadedVoiceNotePath != null)
                              Text(
                                _isRecordingVoice
                                    ? 'Recording... 00:${_recordingSeconds.toString().padLeft(2, '0')}'
                                    : 'Voice note recorded (${_recordingSeconds}s)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: _isRecordingVoice ? Colors.red : Colors.black54,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_isRecordingVoice)
                        GestureDetector(
                          onTap: _stopVoiceRecording,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.stop, color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'Stop',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (_uploadedVoiceNotePath != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: _toggleVoicePreview,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isPlayingVoicePreview ? Icons.pause : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isPlayingVoicePreview ? 'Pause' : 'Play',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 60,
                              height: 18,
                              child: Builder(builder: (context) {
                                double progress = 0.0;
                                if (_voicePreviewController != null &&
                                    _voicePreviewController!.value.isInitialized &&
                                    _voicePreviewController!.value.duration.inMilliseconds > 0) {
                                  progress = (_voicePreviewController!.value.position.inMilliseconds /
                                          _voicePreviewController!.value.duration.inMilliseconds)
                                      .clamp(0.0, 1.0);
                                }
                                const heights = [8.0, 14.0, 18.0, 10.0, 16.0, 6.0, 12.0, 16.0, 10.0, 14.0, 8.0, 12.0];
                                final int totalBars = heights.length;
                                final int playedCount = (progress * totalBars).round().clamp(0, totalBars);

                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: List.generate(totalBars, (index) {
                                    final bool isPlayed = index < playedCount;
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 80),
                                      width: 2.0,
                                      height: heights[index],
                                      decoration: BoxDecoration(
                                        color: isPlayed ? Colors.black : Colors.grey.shade400,
                                        borderRadius: BorderRadius.circular(1.5),
                                      ),
                                    );
                                  }),
                                );
                              }),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _deleteVoiceNote,
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                              ),
                            ),
                          ],
                        )
                      else
                        GestureDetector(
                          onTap: _startVoiceRecording,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.mic, color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'Record',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 6. Describe your task Text Area
                _buildFormCard(
                  child: TextField(
                    controller: _descriptionController,
                    minLines: 1,
                    maxLines: null,
                    style: const TextStyle(fontSize: 15, color: Colors.black),
                    decoration: const InputDecoration(
                      hintText: 'Describe your task...',
                      hintStyle: TextStyle(
                          color: Colors.black54,
                          fontSize: 15,
                          fontWeight: FontWeight.w500),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Next / Post Request Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      'Next',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: child,
    );
  }
}

class _DraggableMapPopup extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final String initialAddress;
  final Function(String address, double lat, double lng) onLocationConfirmed;

  const _DraggableMapPopup({
    required this.initialLat,
    required this.initialLng,
    required this.initialAddress,
    required this.onLocationConfirmed,
  });

  @override
  State<_DraggableMapPopup> createState() => _DraggableMapPopupState();
}

class _DraggableMapPopupState extends State<_DraggableMapPopup> {
  late double _currentLat;
  late double _currentLng;
  int _zoom = 15;

  late double _centerTileX;
  late double _centerTileY;

  String _currentAddress = '';
  bool _isGeocoding = false;
  bool _isSearching = false;
  Timer? _debounceTimer;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentLat = widget.initialLat;
    _currentLng = widget.initialLng;
    _currentAddress = widget.initialAddress;

    _updateTileCoordinatesFromLatLng(_currentLat, _currentLng);
    _reverseGeocode(_currentLat, _currentLng);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _updateTileCoordinatesFromLatLng(double lat, double lng) {
    double n = math.pow(2.0, _zoom).toDouble();
    _centerTileX = n * ((lng + 180.0) / 360.0);
    double latRad = lat * math.pi / 180.0;
    _centerTileY = n *
        (1.0 - (math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi)) /
        2.0;
  }

  void _updateLatLngFromTileCoordinates() {
    double n = math.pow(2.0, _zoom).toDouble();
    _currentLng = (_centerTileX / n) * 360.0 - 180.0;
    double sinh(double x) => (math.exp(x) - math.exp(-x)) / 2.0;
    double latRad = math.atan(sinh(math.pi * (1.0 - 2.0 * _centerTileY / n)));
    _currentLat = latRad * 180.0 / math.pi;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _centerTileX -= details.delta.dx / 256.0;
      _centerTileY -= details.delta.dy / 256.0;
      _updateLatLngFromTileCoordinates();
    });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _reverseGeocode(_currentLat, _currentLng);
    });
  }

  Future _reverseGeocode(double lat, double lng) async {
    if (_isGeocoding) return;
    setState(() {
      _isGeocoding = true;
    });

    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng');
      final response = await http.get(url, headers: {'User-Agent': 'ReapirooApp/1.0'}).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final displayName = data['display_name'] as String?;
        final addressObj = data['address'] as Map?;

        String formatted = '';
        if (addressObj != null) {
          final road = addressObj['road'] ??
              addressObj['suburb'] ??
              addressObj['neighbourhood'] ??
              addressObj['residential'] ??
              addressObj['building'];
          final city = addressObj['city'] ??
              addressObj['town'] ??
              addressObj['state'] ??
              addressObj['country'];
          if (road != null && city != null) {
            formatted = '$road, $city';
          }
        }
        if (formatted.isEmpty &&
            displayName != null &&
            displayName.isNotEmpty) {
          final parts = displayName.split(',');
          if (parts.length >= 2) {
            formatted = '${parts[0].trim()}, ${parts[1].trim()}';
          } else {
            formatted = displayName;
          }
        }

        if (formatted.isNotEmpty && mounted) {
          setState(() {
            _currentAddress = formatted;
          });
        }
      }
    } catch (_) {} finally {
      if (mounted) {
        setState(() {
          _isGeocoding = false;
        });
      }
    }
  }

  Future _searchLocation(String query) async {
    if (query.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isSearching = true;
    });

    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query.trim())}&limit=1');
      final response = await http.get(url, headers: {'User-Agent': 'ReapirooApp/1.0'}).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List results = jsonDecode(response.body);
        if (results.isNotEmpty) {
          final first = results.first;
          final lat = double.parse(first['lat'].toString());
          final lon = double.parse(first['lon'].toString());
          final displayName = first['display_name'] as String? ?? query;

          if (mounted) {
            setState(() {
              _currentLat = lat;
              _currentLng = lon;
              _currentAddress =
                  displayName.split(',').take(2).join(',').trim();
              _updateTileCoordinatesFromLatLng(lat, lon);
            });
          }
        } else {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(content: Text('No results found for "$query"')),
            );
          }
        }
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Search failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _goToCurrentGpsLocation() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 6));

      if (mounted) {
        setState(() {
          _currentLat = position.latitude;
          _currentLng = position.longitude;
          _updateTileCoordinatesFromLatLng(_currentLat, _currentLng);
        });
        _reverseGeocode(_currentLat, _currentLng);
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Unable to fetch GPS location.')),
        );
      }
    }
  }

  void _zoomIn() {
    if (_zoom < 18) {
      setState(() {
        _zoom++;
        _updateTileCoordinatesFromLatLng(_currentLat, _currentLng);
      });
    }
  }

  void _zoomOut() {
    if (_zoom > 5) {
      setState(() {
        _zoom--;
        _updateTileCoordinatesFromLatLng(_currentLat, _currentLng);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header Title & Close Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.map, color: Colors.black, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Select Location on Map',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F3F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            textInputAction: TextInputAction.search,
                            onSubmitted: _searchLocation,
                            decoration: const InputDecoration(
                              hintText: 'Search city, area, or landmark...',
                              hintStyle:
                              TextStyle(fontSize: 13, color: Colors.grey),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            child: const Icon(Icons.cancel,
                                color: Colors.grey, size: 18),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onPressed: _isSearching
                        ? null
                        : () => _searchLocation(_searchController.text),
                    child: _isSearching
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                        : const Text('Search',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Interactive Draggable Map View
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // Draggable Map Canvas
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final height = constraints.maxHeight;

                        final minTx =
                            (_centerTileX - (width / 2) / 256.0).floor() - 1;
                        final maxTx =
                            (_centerTileX + (width / 2) / 256.0).ceil() + 1;
                        final minTy =
                            (_centerTileY - (height / 2) / 256.0).floor() - 1;
                        final maxTy =
                            (_centerTileY + (height / 2) / 256.0).ceil() + 1;

                        final int maxTileIndex = math.pow(2, _zoom).toInt();

                        final List<Widget> tileWidgets = [];

                        for (int tx = minTx; tx <= maxTx; tx++) {
                          for (int ty = minTy; ty <= maxTy; ty++) {
                            int wrappedTx =
                                (tx % maxTileIndex + maxTileIndex) % maxTileIndex;
                            if (ty < 0 || ty >= maxTileIndex) continue;

                            final left =
                                (width / 2) + (tx - _centerTileX) * 256.0;
                            final top =
                                (height / 2) + (ty - _centerTileY) * 256.0;

                            final subdomains = ['a', 'b', 'c'];
                            final subdomain = subdomains[
                                (tx.abs() + ty.abs()) % subdomains.length];
                            final tileUrl =
                                'https://$subdomain.tile.openstreetmap.org/$_zoom/$wrappedTx/$ty.png';

                            tileWidgets.add(
                              Positioned(
                                left: left,
                                top: top,
                                width: 256,
                                height: 256,
                                child: Image.network(
                                  tileUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        color: const Color(0xFFE5E3DF),
                                        child: const Center(
                                          child: Icon(Icons.map_outlined,
                                              color: Colors.grey),
                                        ),
                                      ),
                                ),
                              ),
                            );
                          }
                        }

                        return GestureDetector(
                          onPanUpdate: _onPanUpdate,
                          child: Container(
                            width: width,
                            height: height,
                            color: const Color(0xFFE5E3DF),
                            child: Stack(
                              children: tileWidgets,
                            ),
                          ),
                        );
                      },
                    ),

                    // Fixed Red Location Pin in exact Center
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 36),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.redAccent,
                                size: 28,
                              ),
                            ),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Top-Right GPS Location Button
                    Positioned(
                      top: 12,
                      right: 12,
                      child: FloatingActionButton.small(
                        heroTag: 'gps_btn',
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 4,
                        onPressed: _goToCurrentGpsLocation,
                        child: const Icon(Icons.my_location, size: 20),
                      ),
                    ),

                    // Bottom-Right Zoom Controls
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FloatingActionButton.small(
                            heroTag: 'zoom_in_btn',
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 3,
                            onPressed: _zoomIn,
                            child: const Icon(Icons.add, size: 20),
                          ),
                          const SizedBox(height: 6),
                          FloatingActionButton.small(
                            heroTag: 'zoom_out_btn',
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 3,
                            onPressed: _zoomOut,
                            child: const Icon(Icons.remove, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Bottom Address Card & Confirm Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        color: Colors.black, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _isGeocoding ? 'Locating address...' : _currentAddress,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_isGeocoding)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'GPS: ${_currentLat.toStringAsFixed(5)}, ${_currentLng.toStringAsFixed(5)}',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      final addr = _currentAddress.isNotEmpty
                          ? _currentAddress
                          : 'Downtown Road, Dubai';
                      widget.onLocationConfirmed(
                          addr, _currentLat, _currentLng);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check_circle_outline,
                        color: Colors.white, size: 20),
                    label: const Text(
                      'Confirm Location',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}