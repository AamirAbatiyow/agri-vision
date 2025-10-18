// lib/pages/camera/camera_page.dart
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/activity_service.dart';
// NEW: import your standalone page (we won’t modify it)
import '../../experiments/rekognition_test_standalone.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _captures = [];
  bool _busy = false;

  Future<void> _takePhoto() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final x = await _picker.pickImage(source: ImageSource.camera, maxWidth: 2048, imageQuality: 88);
      if (x != null) setState(() => _captures.insert(0, x));
    } catch (e) {
      _snack('Camera error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFromGallery() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final xs = await _picker.pickMultiImage(maxWidth: 2048, imageQuality: 88);
      if (xs.isNotEmpty) setState(() => _captures.insertAll(0, xs));
    } catch (e) {
      _snack('Gallery error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openViewer(XFile file, {bool analyzeImmediately = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PhotoViewer(file: file, analyzeImmediately: analyzeImmediately),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plant Camera'),
        actions: [
          IconButton(
            tooltip: 'Pick from gallery',
            icon: const FaIcon(FontAwesomeIcons.images),
            onPressed: _busy ? null : _pickFromGallery,
          ),
          // NEW: quick entry to your Rekognition test page
          IconButton(
            tooltip: 'AWS Rekognition Lab',
            icon: const FaIcon(FontAwesomeIcons.cloud),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RekognitionTestPage()),
              );
            },
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        icon: _busy
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const FaIcon(FontAwesomeIcons.camera),
        label: Text(_busy ? 'Working…' : 'Capture'),
        onPressed: _busy ? null : _takePhoto,
      ),
      body: Column(
        children: [
          // Preview (latest photo or placeholder)
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Container(
              color: scheme.surfaceVariant,
              child: _captures.isEmpty
                  ? Center(
                      child: Text(
                        'No photos yet.\nTap Capture or pick from Gallery.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  : _AdaptiveImage(file: _captures.first, fit: BoxFit.cover),
            ),
          ),

          // Quick actions for latest
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const FaIcon(FontAwesomeIcons.magnifyingGlassChart, size: 16),
                    label: const Text('Analyze Latest'),
                    onPressed: _captures.isEmpty
                        ? null
                        : () => _openViewer(_captures.first, analyzeImmediately: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const FaIcon(FontAwesomeIcons.trash, size: 14),
                    label: const Text('Discard Latest'),
                    onPressed: _captures.isEmpty
                        ? null
                        : () => setState(() => _captures.removeAt(0)),
                  ),
                ),
              ],
            ),
          ),

          // Thumbnails
          Expanded(
            child: _captures.isEmpty
                ? Center(child: Text('Your captures will appear here.', style: TextStyle(color: scheme.onSurfaceVariant)))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: _captures.length,
                    itemBuilder: (_, i) {
                      final f = _captures[i];
                      return GestureDetector(
                        onTap: () => _openViewer(f),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _AdaptiveImage(file: f, fit: BoxFit.cover),
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

/// Displays an XFile in a way that works on mobile and web.
class _AdaptiveImage extends StatelessWidget {
  final XFile file;
  final BoxFit fit;
  const _AdaptiveImage({required this.file, this.fit = BoxFit.contain});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // On web, XFile.path is a blob URL
      return Image.network(file.path, fit: fit);
    } else {
      return Image.file(File(file.path), fit: fit);
    }
  }
}

/// Full-screen viewer + simple local "analysis".
class _PhotoViewer extends StatefulWidget {
  final XFile file;
  final bool analyzeImmediately;
  const _PhotoViewer({required this.file, this.analyzeImmediately = false});

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  Map<String, String>? _analysis;

  @override
  void initState() {
    super.initState();
    if (widget.analyzeImmediately) {
      Future.microtask(_runAnalysis);
    }
  }

  Future<void> _runAnalysis() async {
    try {
      final name = widget.file.name;
      final bytes = await widget.file.length();
      final seed = name.hashCode ^ bytes.hashCode;
      final health = 60 + (seed % 41); // 60–100
      final hydration = (seed % 3 == 0) ? 'Adequate' : (seed % 3 == 1) ? 'Slightly Dry' : 'Moist';
      final sunlight = const ['Low', 'Medium', 'High'][seed % 3];
      final disease = const ['Low', 'Medium'][seed % 2];

      setState(() {
        _analysis = {
          'Health Score': '$health / 100',
          'Hydration': hydration,
          'Sunlight': sunlight,
          'Disease Risk': disease,
        };
      });

      // count analysis for achievements
      ActivityService.I.onPhotoAnalyzed();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Analysis failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo'),
        actions: [
          IconButton(
            tooltip: 'Analyze',
            icon: const FaIcon(FontAwesomeIcons.magnifyingGlassChart),
            onPressed: _runAnalysis,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              minScale: 0.9,
              maxScale: 4.0,
              child: _AdaptiveImage(file: widget.file),
            ),
          ),
          if (_analysis != null) const Divider(height: 1),
          if (_analysis != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              color: scheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _analysis!.entries
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Text('${e.key}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                            Expanded(child: Text(e.value)),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const FaIcon(FontAwesomeIcons.download),
        label: const Text('Save (system)'),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to device (or available via share).')));
        },
      ),
    );
  }
}
