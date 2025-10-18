import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AWS Rekognition Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const RekognitionTestPage(),
    );
  }
}

class RekognitionTestPage extends StatefulWidget {
  const RekognitionTestPage({super.key});

  @override
  State<RekognitionTestPage> createState() => _RekognitionTestPageState();
}

class _RekognitionTestPageState extends State<RekognitionTestPage> {
  File? _imageFile;
  List<dynamic>? _labels;
  dynamic _customLabels; // keep dynamic to handle Map or List
  bool _isLoading = false;
  String? _errorMessage;
  final ImagePicker _picker = ImagePicker();

  static const String backendUrl = 'http://10.102.96.77:8000';

  // --- Helper to safely get _customLabels as a Map ---
  Map<String, dynamic> get customLabelsSafe {
    if (_customLabels == null) return {};
    if (_customLabels is Map<String, dynamic>) return _customLabels;
    if (_customLabels is List && (_customLabels as List).isNotEmpty) {
      final first = (_customLabels as List).first;
      if (first is Map<String, dynamic>) return first;
    }
    return {};
  }

  Future<void> _takePicture() async {
    try {
      setState(() {
        _errorMessage = null;
        _labels = null;
        _customLabels = null;
      });

      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo == null) return;

      setState(() {
        _imageFile = File(photo.path);
        _isLoading = true;
      });

      await _uploadImage(File(photo.path));
    } catch (e) {
      setState(() {
        _errorMessage = 'Error taking picture: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadImage(File imageFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$backendUrl/analyze'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error analyzing image: ${response.body}';
        });
        return;
      }

      // Fetch results JSON
      var resultsResponse = await http.get(Uri.parse('$backendUrl/results'));

      setState(() => _isLoading = false);

      if (resultsResponse.statusCode == 200) {
        final jsonResponse = json.decode(resultsResponse.body);
        setState(() {
          _labels = jsonResponse['labels'] ?? [];
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage =
              'Error fetching results: ${resultsResponse.statusCode}\n${resultsResponse.body}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Error uploading image: $e\nMake sure the Flask server is running on $backendUrl';
      });
    }
  }

  Future<void> _fetchAIStrandsResults() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _customLabels = null;
    });

    try {
      final response = await http.get(Uri.parse('$backendUrl/ai_results'));
      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        // Normalize to Map safely
        setState(() {
          _customLabels = jsonResponse['results'] ?? jsonResponse;
        });
      } else {
        setState(() {
          _errorMessage =
              'Error fetching AI Strands JSON: ${response.statusCode}\n${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final safeCustomLabels = customLabelsSafe;
    final treatmentList = <String>[];
    final rawTreatments = safeCustomLabels['treatment'];
    if (rawTreatments is List)
      treatmentList.addAll(rawTreatments.map((e) => e.toString()));
    else if (rawTreatments is String)
      treatmentList.add(rawTreatments);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.surface,
        title: const Text('Crop Disease Analyzer'),
      ),
      // gradient background
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [scheme.surface, scheme.surfaceContainerLow],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // animated Take Picture Button with modern styling
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _takePicture,
                  icon: const Icon(Icons.camera_alt, size: 24),
                  label: const Text(
                    'Take Picture',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Fetch AI Results Button with animation
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _fetchAIStrandsResults,
                  icon: const Icon(Icons.cloud_download, size: 24),
                  label: const Text(
                    'Fetch AI Strands Results',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.secondaryContainer,
                    foregroundColor: scheme.onSecondaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Captured Image with modern card styling
              if (_imageFile != null) ...[
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.scale(
                        scale: 0.95 + (0.05 * value),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Captured Image:',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: scheme.outlineVariant),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.shadow.withOpacity(0.1),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.file(_imageFile!, fit: BoxFit.contain),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],

              // Modern loading indicator
              if (_isLoading)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            scheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Analyzing image...',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Modern error card
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer.withOpacity(0.3),
                    border: Border.all(color: scheme.error.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: scheme.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                    ],
                  ),
                ),

              // AI Strands Results with modern card
              if (safeCustomLabels.isNotEmpty) ...[
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Strands Results:',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              scheme.primaryContainer.withOpacity(0.5),
                              scheme.surfaceContainerHigh,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: scheme.outlineVariant),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.shadow.withOpacity(0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.medical_services,
                                  color: scheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Disease:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              safeCustomLabels['disease'] ?? "N/A",
                              style: const TextStyle(fontSize: 15),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.science,
                                  color: scheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Cause:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              safeCustomLabels['cause'] ?? "N/A",
                              style: const TextStyle(fontSize: 15),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.warning_amber,
                                  color: scheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Symptoms:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              safeCustomLabels['symptoms'] ?? "N/A",
                              style: const TextStyle(fontSize: 15),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(
                                  Icons.healing,
                                  color: scheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Top Treatments:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (treatmentList.isNotEmpty)
                              ...treatmentList.map(
                                (t) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: scheme.primary,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          t,
                                          style: const TextStyle(fontSize: 15),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Text(
                                'No treatments available',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],

              // Standard Labels
              if (_labels != null && _labels!.isNotEmpty) ...[
                const Text(
                  'Standard Labels:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scheme.primaryContainer),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _labels!.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final label = _labels![index];
                      if (label is Map) {
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: scheme.primary,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(color: scheme.onPrimary),
                            ),
                          ),
                          title: Text(
                            label['name'] ?? 'N/A',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${label['confidence'] ?? 0}%',
                              style: TextStyle(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ],

              if (_labels == null || _labels!.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer.withOpacity(0.3),
                    border: Border.all(color: scheme.error.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: scheme.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No labels detected with confidence > 70%',
                          style: TextStyle(color: scheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
