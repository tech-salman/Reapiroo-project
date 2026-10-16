import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:reapiroo/services/storage_service.dart';

class NewTaskCard extends StatefulWidget {
  final String customerName;
  final String? requestId;
  final String location;
  final String description;
  final String serviceImageUrl;
  final List<String> mediaUrls;
  final String? sparePartImageUrl;
  final String? voiceNoteUrl;
  final String serviceName;
  final String date;
  final String time;
  final bool hasSpareParts;
  final VoidCallback onSparePartsPressed;

  const NewTaskCard({
    super.key,
    required this.customerName,
    this.requestId,
    required this.location,
    required this.description,
    required this.serviceImageUrl,
    required this.mediaUrls,
    this.sparePartImageUrl,
    this.voiceNoteUrl,
    required this.serviceName,
    required this.date,
    required this.time,
    required this.hasSpareParts,
    required this.onSparePartsPressed,
  });

  @override
  State<NewTaskCard> createState() => _NewTaskCardState();
}

class _NewTaskCardState extends State<NewTaskCard> {
  List<String> get _allMedia {
    final list = <String>[];
    if (widget.mediaUrls.isNotEmpty) {
      for (final m in widget.mediaUrls) {
        if (m.trim().isNotEmpty) list.add(m.trim());
      }
    }
    if (list.isEmpty && widget.serviceImageUrl.trim().isNotEmpty) {
      list.add(widget.serviceImageUrl.trim());
    }
    return list;
  }

  bool _isVideo(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.avi') || lower.endsWith('.m4v') || lower.endsWith('.webm') || lower.contains('video');
  }

  void _showImagePopup(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                InteractiveViewer(
                  panEnabled: true,
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image(
                        image: StorageService.getImageProvider(imageUrl),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 50),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 20,
                  right: 20,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaList = _allMedia;
    final hasVoiceNote = widget.voiceNoteUrl != null && widget.voiceNoteUrl!.trim().isNotEmpty;

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.fromLTRB(12, 22, 12, 14),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.customerName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              widget.requestId != null
                                  ? 'ID # ${widget.requestId!.length > 6 ? widget.requestId!.substring(0, 6).toUpperCase() : widget.requestId}'
                                  : '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, color: Colors.white70, size: 13),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                widget.location,
                                style: const TextStyle(color: Colors.white70, fontSize: 10),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          widget.description,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 9.5,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (mediaList.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _isVideo(mediaList.first)
                          ? Container(
                              width: 86,
                              height: 72,
                              color: Colors.grey.shade900,
                              child: const Icon(Icons.videocam, color: Colors.white54, size: 30),
                            )
                          : Image(
                              image: StorageService.getImageProvider(mediaList.first),
                              width: 86,
                              height: 72,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 86,
                                height: 72,
                                color: Colors.grey.shade800,
                              ),
                            ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 12, color: Colors.black),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              widget.date,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.access_time_filled, size: 12, color: Colors.black),
                          const SizedBox(width: 3),
                          Text(
                            widget.time,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.hasSpareParts) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: widget.onSparePartsPressed,
                      child: Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Spare Parts',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (mediaList.isNotEmpty) ...[
                const SizedBox(height: 10),
                mediaList.length == 1
                    ? _buildSingleMediaWidget(mediaList.first)
                    : SizedBox(
                        height: 170,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: mediaList.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: EdgeInsets.only(right: index < mediaList.length - 1 ? 10.0 : 0.0),
                              child: SizedBox(
                                width: 220,
                                child: _buildSingleMediaWidget(mediaList[index]),
                              ),
                            );
                          },
                        ),
                      ),
              ],
              if (hasVoiceNote) ...[
                const SizedBox(height: 10),
                _AudioPlayerWidget(voiceNoteUrl: widget.voiceNoteUrl!),
              ],
            ],
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 5),
            decoration: const BoxDecoration(
              color: Color(0xFFE5E5EA),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
            ),
            child: const Text(
              'New',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 5),
            decoration: const BoxDecoration(
              color: Color(0xFFE5E5EA),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
                bottomLeft: Radius.circular(10),
              ),
            ),
            child: Text(
              widget.serviceName,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleMediaWidget(String url) {
    if (_isVideo(url)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 170,
          child: _VideoPlayerWidget(videoUrl: url),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showImagePopup(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 170,
          child: Image(
            image: StorageService.getImageProvider(url),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey.shade900,
              child: const Icon(Icons.broken_image, color: Colors.white54),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// ISOLATED AUDIO PLAYER WIDGET (PREVENTS PARENT CARD / IMAGE BLINKING)
// ==========================================
class _AudioPlayerWidget extends StatefulWidget {
  final String voiceNoteUrl;
  const _AudioPlayerWidget({required this.voiceNoteUrl});

  @override
  State<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  bool _isPlayingAudio = false;
  VideoPlayerController? _audioController;

  final List<double> _waveHeights = const [
    8, 14, 20, 10, 24, 18, 30, 12, 26, 32, 16, 28, 22, 34, 14,
    26, 20, 32, 18, 28, 12, 22, 16, 24, 10, 20, 14, 26, 18, 24, 12, 16
  ];

  @override
  void dispose() {
    _audioController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_AudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.voiceNoteUrl != widget.voiceNoteUrl) {
      _audioController?.dispose();
      _audioController = null;
      _isPlayingAudio = false;
    }
  }

  Future<void> _toggleAudioPlayback() async {
    final url = widget.voiceNoteUrl;
    if (url.trim().isNotEmpty) {
      if (_audioController == null) {
        final cleanUrl = url.trim();
        if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://') || cleanUrl.startsWith('data:audio')) {
          _audioController = VideoPlayerController.networkUrl(Uri.parse(cleanUrl));
        } else {
          _audioController = VideoPlayerController.file(File(cleanUrl));
        }
        await _audioController!.initialize();
        _audioController!.setVolume(1.0);
        _audioController!.addListener(() {
          if (mounted) {
            setState(() {
              _isPlayingAudio = _audioController!.value.isPlaying;
            });
            if (_audioController!.value.duration > Duration.zero &&
                _audioController!.value.position >= _audioController!.value.duration) {
              _audioController!.seekTo(Duration.zero);
              _audioController!.pause();
            }
          }
        });
      }

      if (_audioController!.value.isPlaying) {
        await _audioController!.pause();
      } else {
        await _audioController!.play();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: _toggleAudioPlayback,
          child: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPlayingAudio ? Icons.pause : Icons.play_arrow_rounded,
              color: Colors.black,
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              double progress = 0.0;
              if (_audioController != null &&
                  _audioController!.value.isInitialized &&
                  _audioController!.value.duration.inMilliseconds > 0) {
                progress = (_audioController!.value.position.inMilliseconds /
                        _audioController!.value.duration.inMilliseconds)
                    .clamp(0.0, 1.0);
              }

              final int playedBarsCount =
                  (progress * _waveHeights.length).round().clamp(0, _waveHeights.length);

              return GestureDetector(
                onTapUp: (details) {
                  if (_audioController != null &&
                      _audioController!.value.isInitialized &&
                      _audioController!.value.duration.inMilliseconds > 0) {
                    final double tapRatio =
                        (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                    final int newMs =
                        (tapRatio * _audioController!.value.duration.inMilliseconds).round();
                    _audioController!.seekTo(Duration(milliseconds: newMs));
                  }
                },
                child: SizedBox(
                  height: 32,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(_waveHeights.length, (index) {
                      final bool isPlayed = index < playedBarsCount;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 80),
                        width: 2.5,
                        height: _waveHeights[index],
                        decoration: BoxDecoration(
                          color: isPlayed ? Colors.white : Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  const _VideoPlayerWidget({required this.videoUrl});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      if (widget.videoUrl.startsWith('http') || widget.videoUrl.startsWith('https')) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      } else {
        _controller = VideoPlayerController.file(File(widget.videoUrl));
      }
      await _controller.initialize();
      _controller.setVolume(1.0); // with audio
      setState(() {
        _isInitialized = true;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int errorPlaceholder = 0;
    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
      );
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: _controller.value.aspectRatio > 0 ? _controller.value.aspectRatio : 16 / 9,
          child: VideoPlayer(_controller),
        ),
        Container(
          color: Colors.black.withValues(alpha: 0.2),
        ),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black54,
            ),
            child: Icon(
              _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 28,
            ),
          ),
          onPressed: () {
            setState(() {
              if (_controller.value.isPlaying) {
                _controller.pause();
              } else {
                _controller.play();
              }
            });
          },
        ),
      ],
    );
  }
}
