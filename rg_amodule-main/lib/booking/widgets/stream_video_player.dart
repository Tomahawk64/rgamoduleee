import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// A stream-only video player loaded from a network URL.
///
/// Intentionally provides NO download affordances.
/// Supports play/pause, seek, mute, and optional fullscreen push.
class StreamVideoPlayer extends StatefulWidget {
  const StreamVideoPlayer({
    super.key,
    required this.videoUrl,
    this.aspectRatio = 16 / 9,
    this.autoPlay = false,
    this.showFullscreenButton = true,
  });

  final String videoUrl;

  /// Default aspect ratio for the player container.
  final double aspectRatio;

  /// Whether to start playback immediately after initialisation.
  final bool autoPlay;

  final bool showFullscreenButton;

  @override
  State<StreamVideoPlayer> createState() => _StreamVideoPlayerState();
}

class _StreamVideoPlayerState extends State<StreamVideoPlayer> {
  late VideoPlayerController _ctrl;
  bool _initialised = false;
  bool _error = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    _ctrl = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
      // httpHeaders: {'Cache-Control': 'no-store'},  // uncomment for strict stream
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );

    _ctrl.addListener(_onControllerUpdate);

    try {
      await _ctrl.initialize();
      if (mounted) {
        setState(() => _initialised = true);
        if (widget.autoPlay) _ctrl.play();
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onControllerUpdate);
    _ctrl.dispose();
    super.dispose();
  }

  // ── Toggle play/pause ──────────────────────────────────────────────────────

  void _togglePlay() {
    _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play();
    _flashControls();
  }

  void _flashControls() {
    setState(() => _showControls = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _ctrl.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  // ── Seek ───────────────────────────────────────────────────────────────────

  void _seekTo(double fraction) {
    final dur = _ctrl.value.duration;
    _ctrl.seekTo(dur * fraction);
  }

  // ── Open fullscreen ────────────────────────────────────────────────────────

  Future<void> _openFullscreen() async {
    final wasPlaying = _ctrl.value.isPlaying;
    if (wasPlaying) _ctrl.pause();

    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _FullscreenPlayer(
        controller: _ctrl,
        autoPlay: wasPlaying,
      ),
    ));

    if (wasPlaying) _ctrl.play();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_error) return _ErrorPlaceholder(url: widget.videoUrl);
    if (!_initialised) return _LoadingPlaceholder(ratio: widget.aspectRatio);

    final value = _ctrl.value;
    final total = value.duration.inMilliseconds.toDouble().clamp(1.0, double.infinity);
    final pos = value.position.inMilliseconds.toDouble().clamp(0.0, total);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Video ──────────────────────────────────────────────────────
            GestureDetector(
              onTap: _togglePlay,
              behavior: HitTestBehavior.opaque,
              child: VideoPlayer(_ctrl),
            ),

            // ── Controls overlay ───────────────────────────────────────────
            AnimatedOpacity(
              opacity: _showControls || !value.isPlaying ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withAlpha(160),
                    ],
                  ),
                ),
              ),
            ),

            // ── Centre play/pause ──────────────────────────────────────────
            if (_showControls || !value.isPlaying)
              Center(
                child: GestureDetector(
                  onTap: _togglePlay,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(120),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),

            // ── Bottom controls ────────────────────────────────────────────
            if (_showControls || !value.isPlaying)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _BottomBar(
                  position: pos,
                  total: total,
                  isMuted: value.volume == 0,
                  isCompleted: value.position >= value.duration,
                  showFullscreen: widget.showFullscreenButton,
                  positionLabel: _formatDuration(value.position),
                  durationLabel: _formatDuration(value.duration),
                  onSeek: _seekTo,
                  onMute: () => _ctrl.setVolume(value.volume == 0 ? 1.0 : 0.0),
                  onFullscreen: _openFullscreen,
                  onReplay: () {
                    _ctrl.seekTo(Duration.zero);
                    _ctrl.play();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Bottom bar ────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.position,
    required this.total,
    required this.isMuted,
    required this.isCompleted,
    required this.showFullscreen,
    required this.positionLabel,
    required this.durationLabel,
    required this.onSeek,
    required this.onMute,
    required this.onFullscreen,
    required this.onReplay,
  });

  final double position;
  final double total;
  final bool isMuted;
  final bool isCompleted;
  final bool showFullscreen;
  final String positionLabel;
  final String durationLabel;
  final void Function(double) onSeek;
  final VoidCallback onMute;
  final VoidCallback onFullscreen;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seek bar
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbSize: const WidgetStatePropertyAll(Size.fromRadius(6)),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withAlpha(80),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withAlpha(40),
            ),
            child: Slider(
              value: position,
              min: 0,
              max: total,
              onChanged: (v) => onSeek(v / total),
            ),
          ),
          // Time + buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Text(positionLabel,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11)),
                const Text(' / ',
                    style: TextStyle(
                        color: Colors.white60, fontSize: 11)),
                Text(durationLabel,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 11)),
                const Spacer(),
                // No download button — stream only
                IconButton(
                  icon: Icon(
                    isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: onMute,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: isMuted ? 'Unmute' : 'Mute',
                ),
                const SizedBox(width: 8),
                if (isCompleted)
                  IconButton(
                    icon: const Icon(Icons.replay_rounded,
                        color: Colors.white, size: 20),
                    onPressed: onReplay,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                if (showFullscreen) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.fullscreen_rounded,
                        color: Colors.white, size: 22),
                    onPressed: onFullscreen,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Fullscreen',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Loading placeholder ───────────────────────────────────────────────────────

class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder({required this.ratio});
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: ratio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          color: Colors.black,
          child: const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

// ── Error placeholder ─────────────────────────────────────────────────────────

class _ErrorPlaceholder extends StatelessWidget {
  const _ErrorPlaceholder({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          color: Colors.black87,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.error_outline_rounded,
                  color: Colors.red, size: 40),
              SizedBox(height: 8),
              Text('Could not load video',
                  style: TextStyle(color: Colors.white70)),
              Text('Check your connection and try again',
                  style: TextStyle(
                      color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Fullscreen player ─────────────────────────────────────────────────────────

class _FullscreenPlayer extends StatefulWidget {
  const _FullscreenPlayer({
    required this.controller,
    required this.autoPlay,
  });
  final VideoPlayerController controller;
  final bool autoPlay;

  @override
  State<_FullscreenPlayer> createState() => _FullscreenPlayerState();
}

class _FullscreenPlayerState extends State<_FullscreenPlayer> {
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    if (widget.autoPlay) widget.controller.play();
    widget.controller.addListener(_update);
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final value = ctrl.value;
    final total = value.duration.inMilliseconds.toDouble().clamp(1.0, double.infinity);
    final pos   = value.position.inMilliseconds.toDouble().clamp(0.0, total);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(child: VideoPlayer(ctrl)),
            if (_showControls) ...[
              // Dim overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha(100),
                      Colors.transparent,
                      Colors.black.withAlpha(160),
                    ],
                  ),
                ),
              ),
              // Centre play/pause
              Center(
                child: GestureDetector(
                  onTap: () =>
                      value.isPlaying ? ctrl.pause() : ctrl.play(),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(120),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),
              // Top bar (close + no download)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      // Intentionally no download / share button
                    ],
                  ),
                ),
              ),
              // Bottom seek bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbSize: const WidgetStatePropertyAll(Size.fromRadius(7)),
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white38,
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: pos,
                            min: 0,
                            max: total,
                            onChanged: (v) =>
                                ctrl.seekTo(value.duration * (v / total)),
                          ),
                        ),
                        Row(
                          children: [
                            Text(_fmt(value.position),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12)),
                            const Text(' / ',
                                style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12)),
                            Text(_fmt(value.duration),
                                style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12)),
                            const Spacer(),
                            IconButton(
                              icon: Icon(
                                value.volume == 0
                                    ? Icons.volume_off_rounded
                                    : Icons.volume_up_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: () => ctrl.setVolume(
                                  value.volume == 0 ? 1.0 : 0.0),
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8),
                            ),
                            IconButton(
                              icon: const Icon(Icons.fullscreen_exit_rounded,
                                  color: Colors.white, size: 22),
                              onPressed: () => Navigator.pop(context),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
