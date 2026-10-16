import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:reapiroo/services/storage_service.dart';

class TaskDescriptionCard extends StatefulWidget {
  final String customerName;
  final String? requestId;
  final String location;
  final String description;
  final String serviceImageUrl;
  final String serviceName;
  final String date;
  final String time;
  final String? sparePartImageUrl;
  final String? voiceNoteUrl;
  final List<String> mediaUrls;
  final VoidCallback onChatPressed;
  final VoidCallback onOpenMapsPressed;
  final VoidCallback onViewPressed;

  const TaskDescriptionCard({
    super.key,
    required this.customerName,
    this.requestId,
    required this.location,
    required this.description,
    required this.serviceImageUrl,
    required this.serviceName,
    required this.date,
    required this.time,
    this.sparePartImageUrl,
    this.voiceNoteUrl,
    required this.mediaUrls,
    required this.onChatPressed,
    required this.onOpenMapsPressed,
    required this.onViewPressed,
  });

  @override
  State<TaskDescriptionCard> createState() => _TaskDescriptionCardState();
}

class _TaskDescriptionCardState extends State<TaskDescriptionCard> {
  void _showMediaPopup(BuildContext context, String url, bool isVideo) {
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
                        image: StorageService.getImageProvider(url),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white, size: 50),
                      ),
                    ),
                  ),
                ),
                if (isVideo)
                  Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.5),
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
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
    final hasVoiceNote = widget.voiceNoteUrl != null && widget.voiceNoteUrl!.trim().isNotEmpty;

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.fromLTRB(12, 22, 12, 10),
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
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 9.5,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GestureDetector(
                      onTap: () => _showMediaPopup(context, widget.serviceImageUrl, false),
                      child: Image(
                        image: StorageService.getImageProvider(widget.serviceImageUrl),
                        width: 86,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 86,
                          height: 72,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
                  const SizedBox(width: 8),
                  Container(
                    height: 34,
                    width: 86,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      ),
                      onPressed: widget.onViewPressed,
                      child: const Text(
                        'View',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (widget.mediaUrls.isNotEmpty)
                AspectRatio(
                  aspectRatio: 16 / 8.5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: PageView.builder(
                      itemCount: widget.mediaUrls.length,
                      itemBuilder: (context, index) {
                        final url = widget.mediaUrls[index];
                        final isVideo = url.contains('.mp4') || url.contains('.mov') || url.contains('.avi') || url.toLowerCase().contains('video');
                        
                        return GestureDetector(
                          onTap: () {
                            _showMediaPopup(context, url, isVideo);
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image(
                                image: StorageService.getImageProvider(url),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey.shade900),
                              ),
                              if (isVideo) ...[
                                Container(color: Colors.black.withValues(alpha: 0.35)),
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Video',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                                Center(
                                  child: Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2.5),
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                )
              else
                AspectRatio(
                  aspectRatio: 16 / 8.5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: GestureDetector(
                      onTap: () => _showMediaPopup(context, widget.serviceImageUrl, false),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image(
                            image: StorageService.getImageProvider(widget.serviceImageUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey.shade900),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: widget.onChatPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: const Text('Chat', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: widget.onOpenMapsPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: const Text('Open Maps', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.sparePartImageUrl != null && widget.sparePartImageUrl!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.build_circle_outlined, color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    const Text('Spare Part Image:', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: GestureDetector(
                        onTap: () => _showMediaPopup(context, widget.sparePartImageUrl!, false),
                        child: Image(
                          image: StorageService.getImageProvider(widget.sparePartImageUrl),
                          width: 28,
                          height: 28,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (hasVoiceNote) ...[
                const SizedBox(height: 8),
                _AudioPlayerWidget(voiceNoteUrl: widget.voiceNoteUrl!.trim()),
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
  bool _isPlayingVoice = false;
  VideoPlayerController? _voiceController;

  @override
  void dispose() {
    _voiceController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_AudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.voiceNoteUrl != widget.voiceNoteUrl) {
      _voiceController?.dispose();
      _voiceController = null;
      _isPlayingVoice = false;
    }
  }

  Future<void> _toggleVoicePlayback() async {
    final url = widget.voiceNoteUrl;
    if (url.trim().isNotEmpty) {
      if (_voiceController == null) {
        final cleanUrl = url.trim();
        if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://') || cleanUrl.startsWith('data:audio')) {
          _voiceController = VideoPlayerController.networkUrl(Uri.parse(cleanUrl));
        } else {
          _voiceController = VideoPlayerController.file(File(cleanUrl));
        }
        await _voiceController!.initialize();
        _voiceController!.setVolume(1.0);
        _voiceController!.addListener(() {
          if (mounted) {
            setState(() {
              _isPlayingVoice = _voiceController!.value.isPlaying;
            });
            if (_voiceController!.value.duration > Duration.zero &&
                _voiceController!.value.position >= _voiceController!.value.duration) {
              _voiceController!.seekTo(Duration.zero);
              _voiceController!.pause();
            }
          }
        });
      }

      if (_voiceController!.value.isPlaying) {
        await _voiceController!.pause();
      } else {
        await _voiceController!.play();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggleVoicePlayback,
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlayingVoice ? Icons.pause : Icons.play_arrow_rounded,
                color: Colors.black,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Voice Note',
            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                double progress = 0.0;
                if (_voiceController != null &&
                    _voiceController!.value.isInitialized &&
                    _voiceController!.value.duration.inMilliseconds > 0) {
                  progress = (_voiceController!.value.position.inMilliseconds /
                          _voiceController!.value.duration.inMilliseconds)
                      .clamp(0.0, 1.0);
                }

                final heights = const [
                  12.0, 18.0, 8.0, 15.0, 20.0, 10.0, 16.0, 6.0,
                  14.0, 18.0, 10.0, 16.0, 8.0, 15.0, 20.0, 12.0, 14.0, 8.0
                ];
                final int totalBars = heights.length;
                final int playedBarsCount =
                    (progress * totalBars).round().clamp(0, totalBars);

                return GestureDetector(
                  onTapUp: (details) {
                    if (_voiceController != null &&
                        _voiceController!.value.isInitialized &&
                        _voiceController!.value.duration.inMilliseconds > 0) {
                      final double tapRatio =
                          (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                      final int newMs =
                          (tapRatio * _voiceController!.value.duration.inMilliseconds).round();
                      _voiceController!.seekTo(Duration(milliseconds: newMs));
                    }
                  },
                  child: SizedBox(
                    height: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: List.generate(totalBars, (index) {
                        final bool isPlayed = index < playedBarsCount;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 80),
                          width: 2.5,
                          height: heights[index % heights.length],
                          decoration: BoxDecoration(
                            color: isPlayed ? const Color(0xFF10B981) : Colors.white38,
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
      ),
    );
  }
}
