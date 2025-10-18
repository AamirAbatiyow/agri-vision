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
    final safeCustomLabels = customLabelsSafe;
    final treatmentList = <String>[];
    final rawTreatments = safeCustomLabels['treatment'];
    if (rawTreatments is List)
      treatmentList.addAll(rawTreatments.map((e) => e.toString()));
    else if (rawTreatments is String)
      treatmentList.add(rawTreatments);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('AWS Rekognition Test'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Take Picture Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _takePicture,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Picture'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 16),

            // Fetch AI Strands Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _fetchAIStrandsResults,
              icon: const Icon(Icons.cloud_download),
              label: const Text('Fetch AI Strands Results'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 20),

            // Captured Image
            if (_imageFile != null) ...[
              const Text(
                'Captured Image:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(_imageFile!, fit: BoxFit.contain),
              ),
              const SizedBox(height: 20),
            ],

            // Loading
            if (_isLoading)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text('Analyzing image...'),
                  ],
                ),
              ),

            // Error
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            // AI Strands Results
            if (safeCustomLabels.isNotEmpty) ...[
              const Text(
                'AI Strands Results:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disease: ${safeCustomLabels['disease'] ?? "N/A"}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Cause: ${safeCustomLabels['cause'] ?? "N/A"}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Symptoms: ${safeCustomLabels['symptoms'] ?? "N/A"}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Top Treatments:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (treatmentList.isNotEmpty)
                      for (var t in treatmentList)
                        Text('• $t', style: const TextStyle(fontSize: 14))
                    else
                      const Text(
                        'No treatments available',
                        style: TextStyle(fontSize: 14),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
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
                          backgroundColor: Colors.blue,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(color: Colors.white),
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
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${label['confidence'] ?? 0}%',
                            style: const TextStyle(
                              color: Colors.white,
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
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'No labels detected with confidence > 70%',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
