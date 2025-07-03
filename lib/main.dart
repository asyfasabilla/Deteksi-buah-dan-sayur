import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const BuahSayurApp());
}

class BuahSayurApp extends StatelessWidget {
  const BuahSayurApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.green.shade50, // Ubah background agar tidak hitam
        textTheme: GoogleFonts.poppinsTextTheme(),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.green.shade700),
          titleTextStyle: GoogleFonts.poppins(
            color: Colors.green.shade700,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      home: const PredictPage(),
    );
  }
}

class PredictPage extends StatefulWidget {
  const PredictPage({super.key});

  @override
  State<PredictPage> createState() => _PredictPageState();
}

class _PredictPageState extends State<PredictPage> with SingleTickerProviderStateMixin {
  File? _image;
  String _result = "";
  bool _loading = false;
  late Interpreter _interpreter;
  List<String> _labels = [];
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
      lowerBound: 0.8,
      upperBound: 1.2,
    );
    loadModel();
    loadLabels();
  }

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('assets/model/model_buah_sayur.tflite');
  }

  Future<void> loadLabels() async {
    final labelData = await rootBundle.loadString('assets/model/labels.txt');
    setState(() {
      _labels = labelData.split('\n').where((e) => e.trim().isNotEmpty).toList();
    });
  }

  Future<void> pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile == null) return;

    setState(() {
      _image = File(pickedFile.path);
      _loading = true;
    });

    final imageBytes = await pickedFile.readAsBytes();
    final decodedImage = img.decodeImage(imageBytes);
    if (decodedImage == null) {
      setState(() {
        _result = "Gagal membaca gambar";
        _loading = false;
      });
      return;
    }

    final resizedImage = img.copyResize(decodedImage, width: 224, height: 224);
    var input = List.generate(1, (_) => List.generate(224, (y) => List.generate(224, (x) {
          final pixel = resizedImage.getPixel(x, y);
          return [
            pixel.r / 255.0,
            pixel.g / 255.0,
            pixel.b / 255.0,
          ];
        })));

    var output = List.filled(_labels.length, 0.0).reshape([1, _labels.length]);
    _interpreter.run(input, output);

    int resultIndex = 0;
    double maxConfidence = 0.0;
    for (int i = 0; i < _labels.length; i++) {
      if (output[0][i] > maxConfidence) {
        maxConfidence = output[0][i];
        resultIndex = i;
      }
    }

    setState(() {
      _loading = false;
      if (maxConfidence < 0.6) {
        _result = "Bukan termasuk buah dan sayur";
      } else {
        String label = _labels[resultIndex];
        double percent = maxConfidence * 100;
        _result = "$label - ${percent.toStringAsFixed(2)}%";
        _controller.forward(from: 0.8);
      }
    });
  }

  Future<void> showPickOptionsDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Pilih Sumber Gambar"),
        content: const Text("Ambil gambar dari kamera atau galeri."),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: const Text("Kamera"),
            onPressed: () {
              Navigator.pop(context);
              pickImage(ImageSource.camera);
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.photo),
            label: const Text("Galeri"),
            onPressed: () {
              Navigator.pop(context);
              pickImage(ImageSource.gallery);
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _interpreter.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  Colors.orange.shade50,
                  Colors.orange.shade100,
                  Colors.yellow.shade100,
                ],
                stops: const [0.0, 0.4, 0.7, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            right: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center, // Tambahkan ini agar konten rata tengah
                  children: [
                    // Header
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.eco_rounded, color: Colors.green.shade600, size: 32),
                            const SizedBox(width: 8),
                            Text(
                              'Klasifikasi Buah & Sayur',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          if (_image != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.file(_image!, height: 220, fit: BoxFit.cover),
                            )
                          else
                            Container(
                              height: 220,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.image, size: 80, color: Colors.green.shade100),
                                  const SizedBox(height: 12),
                                  Text(
                                    "Belum ada gambar",
                                    style: GoogleFonts.poppins(
                                      color: Colors.green.shade200,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 24),
                          if (_loading)
                            const CircularProgressIndicator()
                          else if (_result.isNotEmpty)
                            ScaleTransition(
                              scale: _controller,
                              child: Column(
                                children: [
                                  Text(
                                    'Hasil:',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      _result,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : () => showPickOptionsDialog(context),
                        icon: const Icon(Icons.image_search, color: Colors.white),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14.0),
                          child: Text('Pilih Gambar', style: GoogleFonts.poppins(fontSize: 18, color: Colors.white)),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
