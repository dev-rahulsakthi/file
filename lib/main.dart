import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:html' as html;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;
  final lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: const Color(0xffFF7A00),
    scaffoldBackgroundColor: Colors.white,
    colorScheme: ColorScheme.light(
      primary: const Color(0xffFF7A00),
      secondary: const Color(0xffFF7A00),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xffFF7A00),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );

  final darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xffFF7A00),
    scaffoldBackgroundColor: const Color(0xff121212),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xffFF7A00),
      secondary: Color(0xffFF7A00),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xffFF7A00),
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FileFlow',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode,
      home: HomePage(onToggleTheme: _toggleTheme),
    );
  }
}

class HomePage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const HomePage({super.key, required this.onToggleTheme});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  String? uploadCode;
  final receiveController = TextEditingController();
  final GlobalKey _sendCardKey = GlobalKey();
  static const double _baseCardHeight = 210;
  double _syncedHeight = _baseCardHeight;

  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _carouselTimer;

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _fileName;
  int? _fileSize;
  Timer? _progressTimer;
  bool _processing = false;

  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    // Fade animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _opacityAnimation =
        Tween<double>(begin: 0.09, end: 0.2).animate(_animationController);
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _carouselTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startCarousel() {
    _carouselTimer?.cancel();

    _carouselTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) {
        if (!_pageController.hasClients) return;

        _currentPage = (_currentPage + 1) % 3;

        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      },
    );
  }

  Future<void> pickAndUpload() async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null) return;
      
      final file = result.files.single;
      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
        _processing = false;
        _fileName = file.name;
        _fileSize = file.size;
      });

      // Cancel any existing progress timer
      _progressTimer?.cancel();
      
      // Start smooth progress simulation
      _startProgressSimulation();

      var request = http.MultipartRequest(
        "POST",
        Uri.parse("https://file-2qxp.onrender.com/upload"),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          "file",
          file.bytes!,
          filename: file.name,
        ),
      );

      final response = await request.send();
      final body = await response.stream.bytesToString();

      // Set processing state and complete progress
      setState(() {
        _processing = true;
        _uploadProgress = 1.0;
      });
      
      // Small delay to show 100% progress and processing
      await Future.delayed(const Duration(milliseconds: 800));
      
      setState(() {
        uploadCode = body.split(":")[1].replaceAll(RegExp(r'[^\d]'), '');
        _isUploading = false;
        _uploadProgress = 0.0;
        _processing = false;
      });
      
      _progressTimer?.cancel();
      _syncHeight();
      _startCarousel();
    } catch (e) {
      _progressTimer?.cancel();
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
        _processing = false;
      });
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Upload failed: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startProgressSimulation() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_isUploading) {
        timer.cancel();
        return;
      }
      
      setState(() {
        // Faster progress at the beginning, slower near the end
        if (_uploadProgress < 0.7) {
          _uploadProgress += 0.01; // 1% every 50ms = 20% per second
        } else if (_uploadProgress < 0.9) {
          _uploadProgress += 0.005; // 0.5% every 50ms = 10% per second
        } else if (_uploadProgress < 0.95) {
          _uploadProgress += 0.002; // 0.2% every 50ms = 4% per second
        } else {
          // Slow down significantly at 95%
          if (_uploadProgress < 0.99) {
            _uploadProgress += 0.001; // 0.1% every 50ms = 2% per second
          } else {
            // Stop at 99% until actual upload completes
            _uploadProgress = 0.99;
          }
        }
      });
    });
  }

  void downloadFile() {
    final code = receiveController.text.trim();
    if (code.isEmpty) return;

    html.window.open(
      "https://file-2qxp.onrender.com/download/$code",
      "_blank",
    );

    receiveController.clear();
  }

  void _syncHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _sendCardKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        setState(() {
          _syncedHeight = box.size.height;
        });
      }
    });
  }

  Widget _receiveInput() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Have a file code? Enter it below to download your file.",
          style: TextStyle(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: receiveController,
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Enter file code",
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xffFF7A00),
                      width: 1.5,
                    ),
                  ),
                  prefixIcon: const Icon(
                    Icons.vpn_key,
                    size: 18,
                    color: Color(0xffFF7A00),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: downloadFile,
                child: const Text("Download"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800; // adjust breakpoint as needed
    final cardWidth = isMobile ? double.infinity : 520.0;

    return Scaffold(
      backgroundColor: Colors.orange.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            Image.asset("assets/fileflow.png", height: 40),
            const SizedBox(width: 12),
            const Text("FileFlow", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [
          if (!isMobile) ...[
            TextButton(
                onPressed: () {},
                child: const Text("Features",
                    style: TextStyle(color: Colors.white))),
            TextButton(
                onPressed: () {},
                child: const Text("How it works",
                    style: TextStyle(color: Colors.white))),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange,
              ),
              child: const Text("Get Started"),
            ),
            const SizedBox(width: 16),
          ],
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xffFF7A00), Color(0xffffa500)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background "FileFlow" text
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _opacityAnimation,
              builder: (context, child) {
                return Center(
                  child: Text(
                    "FileFlow",
                    style: TextStyle(
                      fontSize: 500,
                      color: Colors.orange.withOpacity(_opacityAnimation.value),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
          SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      // HERO section
                      const Text(
                        "Send & Receive Files\nInstantly",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 36, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Upload your files, get a shareable code, and transfer securely.\nNo registration required.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 40),

                      // SEND & RECEIVE CARDS
                      isMobile
                          ? Column(
                              children: [
                                _buildSendCard(cardWidth),
                                const SizedBox(height: 24),
                                _buildReceiveCard(cardWidth),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSendCard(cardWidth),
                                const SizedBox(width: 24),
                                _buildReceiveCard(cardWidth),
                              ],
                            ),

                      const SizedBox(height: 80),
                      // FOOTER
                      const Text(
                        "© 2026 FileFlow-dev-rahulsakthi. All rights reserved.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

// SEND CARD
Widget _buildSendCard(double width) {
  return SizedBox(
    width: width,
    height: 500,
    child: Stack(
      children: [
        Container(
          key: _sendCardKey,
          width: double.infinity,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Changed to prevent overflow
            children: [
              const Icon(Icons.cloud_upload,
                  size: 60, color: Color(0xffFF7A00)),
              const SizedBox(height: 16),
              const Text("Drop files here or click to upload"),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: _isUploading ? null : pickAndUpload,
                  child: const Text("Browse Files")),
              if (uploadCode != null) ...[
                const SizedBox(height: 24),
                Text("Your Code: $uploadCode",
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(
                    height: 160,
                    child: QrImageView(data: uploadCode!, size: 160)),
              ],
            ],
          ),
        ),
        if (_isUploading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30), // Added vertical padding
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Circular progress indicator
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            value: _uploadProgress,
                            strokeWidth: 6,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xffFF7A00).withOpacity(0.7),
                            ),
                          ),
                        ),
                        Text(
                          '${(_uploadProgress * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xffFF7A00),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Linear progress bar with more details
                    Column(
                      mainAxisSize: MainAxisSize.min, // Prevent overflow
                      children: [
                        Container(
                          constraints: BoxConstraints(
                            maxWidth: 400, // Limit width
                          ),
                          child: LinearProgressIndicator(
                            value: _uploadProgress,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              const Color(0xffFF7A00),
                            ),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // File info
                        if (_fileName != null)
                          Text(
                            _fileName!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 2, // Allow 2 lines
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        
                        const SizedBox(height: 4),
                        
                        // File size and status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (_fileSize != null)
                              Text(
                                '${(_fileSize! / 1024 / 1024).toStringAsFixed(2)} MB',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                _processing 
                                  ? 'Processing...' 
                                  : 'Uploading...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Cancel button
                    if (_uploadProgress < 1.0)
                      TextButton(
                        onPressed: () {
                          _progressTimer?.cancel();
                          setState(() {
                            _isUploading = false;
                            _uploadProgress = 0.0;
                            _processing = false;
                          });
                        },
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
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

// RECEIVE CARD
  Widget _buildReceiveCard(double width) {
    return SizedBox(
      width: width,
      child: Container(
        constraints: BoxConstraints(
          minHeight: uploadCode != null && _syncedHeight > _baseCardHeight
              ? _syncedHeight
              : _baseCardHeight,
        ),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: uploadCode == null ? _receiveInput() : _carouselContent(),
      ),
    );
  }

  Widget _carouselContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "While your file is ready…",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: PageView(
            controller: _pageController,
            children: const [
              _CarouselCard(
                icon: Icons.lock,
                text: "End-to-end secure transfers",
              ),
              _CarouselCard(
                icon: Icons.flash_on,
                text: "Lightning fast downloads",
              ),
              _CarouselCard(
                icon: Icons.devices,
                text: "Works across all devices",
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CarouselCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CarouselCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 48, color: Color(0xffFF7A00)),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center),
      ],
    );
  }
}