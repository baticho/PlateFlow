import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Full-screen image with pinch / double-tap zoom. [url] must already be resolved (absolute).
Future<void> showImageViewer(BuildContext context, String url, {String? title}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => _ImageViewer(url: url, title: title),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _ImageViewer extends StatefulWidget {
  final String url;
  final String? title;
  const _ImageViewer({required this.url, this.title});

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> with SingleTickerProviderStateMixin {
  final _controller = TransformationController();
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  Animation<Matrix4>? _zoom;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      if (_zoom != null) _controller.value = _zoom!.value;
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    final zoomedIn = _controller.value.getMaxScaleOnAxis() > 1.01;
    Matrix4 end = Matrix4.identity();
    if (!zoomedIn && _doubleTapDetails != null) {
      final p = _doubleTapDetails!.localPosition;
      const scale = 2.5;
      end = Matrix4.identity()
        ..translateByDouble(-p.dx * (scale - 1), -p.dy * (scale - 1), 0, 1)
        ..scaleByDouble(scale, scale, 1, 1);
    }
    _zoom = Matrix4Tween(begin: _controller.value, end: end).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: widget.title == null
            ? null
            : Text(widget.title!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
      ),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onDoubleTapDown: (d) => _doubleTapDetails = d,
        onDoubleTap: _onDoubleTap,
        child: InteractiveViewer(
          transformationController: _controller,
          minScale: 1,
          maxScale: 5,
          child: SizedBox.expand(
            child: CachedNetworkImage(
              imageUrl: widget.url,
              fit: BoxFit.contain,
              placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
              errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64)),
            ),
          ),
        ),
      ),
    );
  }
}
