import 'package:flutter/material.dart';
import 'package:flutter95/flutter95.dart';
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
// import 'package:shared_preferences/shared_preferences.dart'; // <-- ARTIK GEREKLİ DEĞİL
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:typed_data';
import 'utils/myErrorDialog.dart';
import 'utils/mySuccessDialog.dart';

// --- YENİ EKLENEN IMPORTLAR ---
import 'dart:convert'; // Gemini API için (JSON ve Base64)
import 'utils/progress_bar.dart'; // Yeni yükleme animasyonu
// ------------------------------

Future<void> main() async {
  // .env dosyasını uygulama başlamadan önce yükle
  await dotenv.load(fileName: ".env");
  runApp(const FitCheckerApp());
}

// =================================================================
// VERİ MODELLERİ
// =================================================================
abstract class ClothingItem {}

class ColorItem extends ClothingItem {
  final Color color;
  ColorItem(this.color);
}

class ImageItem extends ClothingItem {
  final String path;
  ImageItem(this.path);
}

enum ClothingCategory { top, bottom, coat }

// =================================================================

class FitCheckerApp extends StatelessWidget {
  const FitCheckerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Flutter95.background,
      home: const FitCheckerHome(),
      theme: ThemeData(
        textTheme: TextTheme(
          bodyMedium: Flutter95.textStyle,
          bodyLarge: Flutter95.textStyle,
          titleMedium: Flutter95.textStyle,
        ),
        scaffoldBackgroundColor: Flutter95.background,
      ),
    );
  }
}

class FitCheckerHome extends StatefulWidget {
  const FitCheckerHome({super.key});

  @override
  State<FitCheckerHome> createState() => _FitCheckerHomeState();
}

class _FitCheckerHomeState extends State<FitCheckerHome> {
  // --- STATE (DURUM) DEĞİŞKENLERİ ---
  final ImagePicker _picker = ImagePicker();

  List<ClothingItem> _tops = [ ColorItem(const Color(0xFFEECFEF)), /* ... */ ];
  List<ClothingItem> _bottoms = [ ColorItem(const Color(0xFFD8E8E8)), /* ... */ ];
  List<ClothingItem> _coats = [ ColorItem(const Color.fromARGB(255, 209, 245, 211)), /* ... */ ];

  File? _userImage;
  File? _generatedOutfitImage;

  int _topIndex = 0;
  int _bottomIndex = 0;
  int _coatIndex = 0;

  bool _isLoading = false;
  
  // --- YENİ EKLENDİ ---
  bool _showCoatCarousel = false;
  // --------------------

  // --- YARDIMCI FONKSİYON (GEMINI API İÇİN) ---
  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).padLeft(6, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadAllSavedData();
  }

  // --- YENİ EKLENDİ: Ana Görüntü Klasör Yolu ---
  /// Uygulamanın .../images/ klasörünün yolunu döndürür.
  Future<Directory> _getImagesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(appDir.path, 'FitChecker'));
    return imagesDir;
  }

  // --- YENİ EKLENDİ: Klasörleri Oluşturma ---
  /// Uygulama için gerekli tüm alt klasörleri oluşturur.
  Future<void> _initAppDirectories() async {
    try {
      final imagesDir = await _getImagesDirectory();
      
      final topsDir = Directory(p.join(imagesDir.path, 'Tops'));
      final bottomsDir = Directory(p.join(imagesDir.path, 'Bottoms'));
      final coatsDir = Directory(p.join(imagesDir.path, 'Coats'));
      final userPhotoDir = Directory(p.join(imagesDir.path, 'UserPhoto'));

      if (!await topsDir.exists()) await topsDir.create(recursive: true);
      if (!await bottomsDir.exists()) await bottomsDir.create(recursive: true);
      if (!await coatsDir.exists()) await coatsDir.create(recursive: true);
      if (!await userPhotoDir.exists()) await userPhotoDir.create(recursive: true);

      debugPrint("Directory structure initialized at: ${imagesDir.path}");

    } catch (e) {
      debugPrint("Error initializing directories: $e");
      if (mounted) {
        showErrorDialog95(context: context, title: "Startup Error", message: "Could not create app directories: $e");
      }
    }
  }
  
  // --- GÜNCELLENDİ: Veri Yükleme Yöneticisi ---
  Future<void> _loadAllSavedData() async {
    await _initAppDirectories(); // Önce klasörlerin var olduğundan emin ol
    await _loadClothes();        // Klasörlerden kıyafetleri yükle
    await _loadUserPhoto();      // Klasörden kullanıcı fotoğrafını yükle
    setState(() {});
  }

  // --- GÜNCELLENDİ: Kıyafet Yükleme (Dosya Sisteminden) ---
  Future<void> _loadClothes() async {
    final imagesDir = await _getImagesDirectory();

    for (var category in ClothingCategory.values) {
      List<ClothingItem> targetList;
      String subDir;

      switch (category) {
        case ClothingCategory.top:
          targetList = _tops;
          subDir = 'Tops';
          break;
        case ClothingCategory.bottom:
          targetList = _bottoms;
          subDir = 'Bottoms';
          break;
        case ClothingCategory.coat:
          targetList = _coats;
          subDir = 'Coats';
          break;
      }

      final categoryDir = Directory(p.join(imagesDir.path, subDir));
      
      // Halihazırda listelenen (örn. varsayılan renkler) yolları alma
      final existingPaths = targetList.whereType<ImageItem>().map((e) => e.path).toSet();

      if (await categoryDir.exists()) {
        try {
          // Klasördeki tüm dosyaları senkron olarak listele
          final files = categoryDir.listSync().whereType<File>().toList();
          
          for (var file in files) {
            // Eğer bu dosya yolu listede zaten yoksa ekle
            if (!existingPaths.contains(file.path)) {
              targetList.add(ImageItem(file.path));
            }
          }
        } catch (e) {
            debugPrint("Error reading directory ${categoryDir.path}: $e");
        }
      }
    }
  }
  
  // --- GÜNCELLENDİ: Kullanıcı Foto Yükleme (Dosya Sisteminden) ---
  Future<void> _loadUserPhoto() async {
    final imagesDir = await _getImagesDirectory();
    final userPhotoDir = Directory(p.join(imagesDir.path, 'UserPhoto'));

    if (await userPhotoDir.exists()) {
      try {
        final files = userPhotoDir.listSync().whereType<File>().toList();
        if (files.isNotEmpty) {
          // Dosyaları değiştirilme tarihine göre sırala (en yeni en başta)
          files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
          
          // En yeni fotoğrafı yükle
          setState(() {
            _userImage = files.first;
          });
        }
      } catch (e) {
        debugPrint("Error reading UserPhoto directory: $e");
      }
    }
  }

  // --- API İSTEK FONKSİYONLARI ---

  Future<Uint8List?> _removeBackground(String imagePath) async {
    // ... (Bu fonksiyonda değişiklik yok, aynı kalıyor)
    final String? apiKey = dotenv.env['REMOVE_BG_API_KEY']?.trim();
    if (apiKey == null || apiKey.isEmpty) { /*...*/ return null; }
    final uri = Uri.parse('https://api.remove.bg/v1.0/removebg');
    final request = http.MultipartRequest('POST', uri)
      ..headers['X-Api-Key'] = apiKey
      ..fields['size'] = 'auto'
      ..files.add(await http.MultipartFile.fromPath('image_file', imagePath));
    try {
      final streamedResponse = await request.send();
      if (streamedResponse.statusCode == 200) {
        return await streamedResponse.stream.toBytes();
      } else { /*...*/ return null; }
    } catch (e) { /*...*/ return null; }
  }

  Future<Uint8List?> _callGeminiImageApi({
    // ... (Bu fonksiyonda değişiklik yok, aynı kalıyor)
    required File userImageFile,
    required ClothingItem topItem,
    required ClothingItem bottomItem,
    required ClothingItem coatItem,
  }) async {
    final String? apiKey = dotenv.env['GOOGLE_API_KEY']?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint("HATA: .env dosyasında GOOGLE_API_KEY bulunamadı.");
      debugPrint("--- SİMÜLASYON MODU ---");
      await Future.delayed(const Duration(seconds: 3));
      if (topItem is ImageItem) {
        return await File(topItem.path).readAsBytes();
      }
      return null;
    }

    // --- "COAT" KONTROLÜ ---
    const Color defaultCoatColor = Color.fromARGB(255, 209, 245, 211);
    bool includeCoat = true;
    if (coatItem is ColorItem && coatItem.color == defaultCoatColor) {
      includeCoat = false;
    }
    // --- KONTROL SONU ---
    
    const String modelName = 'gemini-2.5-flash-image';
    final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey');
    List<Map<String, dynamic>> parts = [];
    String textPrompt = "Dress this person using the provided items. Dress her realistically.  However, do NOT change the person and do not change the face gestures. ";
    if (topItem is ColorItem) textPrompt += "Use this piece for the top: ${_colorToHex(topItem.color)}. ";
    if (bottomItem is ColorItem) textPrompt += "Use this piece for the bottom: ${_colorToHex(bottomItem.color)}. ";
    if (includeCoat && coatItem is ColorItem) textPrompt += "Use this piece for the coat: ${_colorToHex(coatItem.color)}. ";
    parts.add({"text": textPrompt});
    final userImageBytes = await userImageFile.readAsBytes();
    parts.add({"inlineData": {"mimeType": "image/png", "data": base64Encode(userImageBytes)}});
    if (topItem is ImageItem) {
      parts.add({"text": "Use this image as the top:"});
      parts.add({"inlineData": {"mimeType": "image/png", "data": base64Encode(await File(topItem.path).readAsBytes())}});
    }
    if (bottomItem is ImageItem) {
      parts.add({"text": "Use this image as the bottom:"});
      parts.add({"inlineData": {"mimeType": "image/png", "data": base64Encode(await File(bottomItem.path).readAsBytes())}});
    }
    if (includeCoat && coatItem is ImageItem) {
      parts.add({"text": "Use this image as the coat:"});
      parts.add({"inlineData": {"mimeType": "image/png", "data": base64Encode(await File(coatItem.path).readAsBytes())}});
    }
    final requestBody = jsonEncode({"contents": [{"parts": parts}]});
    try {
      final response = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: requestBody);
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic> responseParts = responseData['candidates'][0]['content']['parts'];
        for (var part in responseParts) {
          if (part.containsKey('inlineData')) {
            final String base64ImageData = part['inlineData']['data'];
            return base64Decode(base64ImageData);
          }
        }
        return null;
      } else { /*...*/ return null; }
    } catch (e) { /*...*/ return null; }
  }
  
  // --- RESİM SEÇME VE EKLEME FONKSİYONLARI ---

  Future<void> _pickUserPhoto() async {
    String? pickedFilePath;
    if (Platform.isAndroid || Platform.isIOS) {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) pickedFilePath = pickedFile.path;
    } else {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) pickedFilePath = result.files.single.path;
    }

    if (pickedFilePath != null) {
      setState(() { _isLoading = true; });
      final imageBytesWithoutBg = await _removeBackground(pickedFilePath);
      setState(() { _isLoading = false; });

      if (imageBytesWithoutBg != null) {
        final imagesDir = await _getImagesDirectory();
        final targetDir = Directory(p.join(imagesDir.path, 'UserPhoto'));
        final fileName = 'user_photo_no_bg_${DateTime.now().millisecondsSinceEpoch}.png';
        final savedImageFile = await File(p.join(targetDir.path, fileName)).writeAsBytes(imageBytesWithoutBg);
        
        debugPrint('>>> Arka planı temizlenmiş fotoğraf kaydedildi: ${savedImageFile.path}');

        setState(() {
          _userImage = savedImageFile;
          _generatedOutfitImage = null;
        });
      } else {
        showDialog95(context: context, title: 'Hata', message: 'Fotoğrafın arka planı temizlenemedi.');
      }
    }
  }

  Future<void> _pickAndAddImage(ClothingCategory category) async {
    String? pickedFilePath;
    if (Platform.isAndroid || Platform.isIOS) {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) pickedFilePath = pickedFile.path;
    } else {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) pickedFilePath = result.files.single.path;
    }

    if (pickedFilePath != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final imageBytesWithoutBg = await _removeBackground(pickedFilePath);

        if (imageBytesWithoutBg != null) {
          
          final imagesDir = await _getImagesDirectory();
          String subDir;
          switch (category) {
            case ClothingCategory.top: subDir = 'Tops'; break;
            case ClothingCategory.bottom: subDir = 'Bottoms'; break;
            case ClothingCategory.coat: subDir = 'Coats'; break;
          }
          
          final targetDir = Directory(p.join(imagesDir.path, subDir));
          final fileName = 'clothing_${category.name}_${DateTime.now().millisecondsSinceEpoch}.png';
          final savedImageFile = await File(p.join(targetDir.path, fileName)).writeAsBytes(imageBytesWithoutBg);
          final String successMessage = 'Kıyafet başarıyla yüklendi.\nDizin: ${targetDir.path}';

          final newItem = ImageItem(savedImageFile.path);
          setState(() {
            switch (category) {
              case ClothingCategory.top:
                _tops.add(newItem);
                _topIndex = _tops.length - 1;
                break;
              case ClothingCategory.bottom:
                _bottoms.add(newItem);
                _bottomIndex = _bottoms.length - 1;
                break;
              case ClothingCategory.coat:
                _coats.add(newItem);
                _coatIndex = _coats.length - 1;
                break;
            }
            _generatedOutfitImage = null;
          });
          
          if (mounted) {
            showSuccessDialog95(context: context, title: 'Yükleme Başarılı', message: successMessage);
          }

        } else {
          if (mounted) {
            showErrorDialog95(context: context, title: 'Hata', message: 'Kıyafet fotoğrafının arka planı temizlenemedi.');
          }
        }
      } catch (e) {
        debugPrint('Hata oluştu: $e');
        if (mounted) {
          showErrorDialog95(context: context, title: 'Hata', message: 'Beklenmedik bir hata oluştu: $e');
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // --- STATE GÜNCELLEME METOTLARI ---
  void _cycleTop(int direction) {
    setState(() {
      _topIndex = (_topIndex + direction + _tops.length) % _tops.length;
    });
  }

  void _cycleBottom(int direction) {
    setState(() {
      _bottomIndex = (_bottomIndex + direction + _bottoms.length) % _bottoms.length;
    });
  }

  void _cycleCoat(int direction) {
    setState(() {
      _coatIndex = (_coatIndex + direction + _coats.length) % _coats.length;
    });
  }
  
  // --- YENİ EKLENDİ ---
  void _toggleCoatCarousel(bool? newValue) {
    setState(() {
      _showCoatCarousel = newValue ?? false;
      
      // Bonus: Paltoyu gizlerken indeksi sıfırla
      if (!_showCoatCarousel) {
        _coatIndex = 0;
      }
    });
  }
  // --------------------


  // --- 'CREATE OUTFIT' FONKSİYONU GÜNCELLENDİ ---
  Future<void> _createOutfit() async {
    if (_userImage == null) {
      showErrorDialog95(
        context: context,
        title: 'Hata',
        message: 'Kombin oluşturmak için lütfen önce kendi fotoğrafınızı ekleyin.',
      );
      return;
    }
    setState(() { _isLoading = true; });
    try {
      final ClothingItem currentTop = _tops[_topIndex];
      final ClothingItem currentBottom = _bottoms[_bottomIndex];
      
      // --- DEĞİŞİKLİK BURADA ---
      // Palto carousel görünürse seçili olanı, değilse "yok" (ilk) olanı al.
      final ClothingItem currentCoat = _showCoatCarousel
          ? _coats[_coatIndex]
          : _coats[0]; // Varsayılan (boş) paltoyu gönder
      // --- DEĞİŞİKLİK SONU ---

      final Uint8List? generatedImageBytes = await _callGeminiImageApi(
        userImageFile: _userImage!,
        topItem: currentTop,
        bottomItem: currentBottom,
        coatItem: currentCoat, // Güncellenmiş palto bilgisi
      );
      if (generatedImageBytes != null && mounted) {
        // --- DEĞİŞİKLİK BURADA: Oluşturulan kombini de 'FitChecker' klasörüne kaydet ---
        // (Ana dizine kaydetmek yerine)
        final imagesDir = await _getImagesDirectory();
        final fileName = 'generated_outfit_${DateTime.now().millisecondsSinceEpoch}.png';
        
        // Ana 'FitChecker' klasörüne kaydet (veya yeni bir 'Generated' klasörü oluşturabilirsiniz)
        final savedImageFile = await File(p.join(imagesDir.path, fileName)).writeAsBytes(generatedImageBytes);
        // --- DEĞİŞİKLİK SONU ---
        
        setState(() {
          _generatedOutfitImage = savedImageFile;
        });
        showSuccessDialog95(
          context: context,
          title: 'Slay Diva!',
          message: 'Yeni kombininiz hazır!',
        );
      } else if (mounted) {
        showErrorDialog95(
          context: context,
          title: 'Hata',
          message: 'Kombin oluşturulamadı. Lütfen tekrar deneyin.',
        );
      }
    } catch (e) {
      debugPrint('Kombin oluşturma hatası: $e');
      if (mounted) {
        showErrorDialog95(
          context: context,
          title: 'Kritik Hata',
          message: 'Beklenmedik bir hata oluştu: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- ANA BUILD METODU (STACK İLE GÜNCELLENDİ) ---
  @override
  Widget build(BuildContext context) {
    final Widget mainScaffold = Scaffold95(
      title: 'Slay Diva 💅',
      toolbar: Toolbar95(
        actions: [
          Item95(label: 'Add Clothes', menu: _buildMenu()),
          Item95(label: 'Edit', onTap: (context) {}),
          Item95(label: 'Help', onTap: (context) {}),
        ],
      ),
      body: Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const double kDesktopBreakpoint = 700.0;
            if (constraints.maxWidth < kDesktopBreakpoint) {
              return _buildNarrowLayout(constraints);
            } else {
              return _buildWideLayout(constraints);
            }
          },
        ),
      ),
    );
    
    return Stack(
      children: [
        mainScaffold,
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: RetroProgressBar95(
                message: "Oluşturuluyor...",
                progressBarColor: const Color(0xFFF472B6),
                duration: const Duration(milliseconds: 800),
              ),
            ),
          ),
      ],
    );
  }

  // --- LAYOUT BUILDER'LARI ---
  // --- GÜNCELLENDİ: _buildWideLayout ---
  Widget _buildWideLayout(BoxConstraints constraints) {
    final double leftColumnRatio = 0.35;
    const double maxPhotoAreaWidth = 650.0;
    const double maxPhotoAreaHeight = 650.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 40,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: (constraints.maxWidth * leftColumnRatio).clamp(320.0, 450.0),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCarousel(title: 'Tops', items: _tops, currentIndex: _topIndex, onPrev: () => _cycleTop(-1), onNext: () => _cycleTop(1), constraints: constraints, isNarrow: false),
                    const SizedBox(height: 16),
                    _buildCarousel(title: 'Bottoms', items: _bottoms, currentIndex: _bottomIndex, onPrev: () => _cycleBottom(-1), onNext: () => _cycleBottom(1), constraints: constraints, isNarrow: false),
                    
                    // --- DEĞİŞİKLİK BURADA ---
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Checkbox95(
                        label: 'Add Coat',
                        value: _showCoatCarousel,
                        onChanged: _toggleCoatCarousel,
                      ),
                    ),
                    if (_showCoatCarousel)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          _buildCarousel(
                            title: 'Coats',
                            items: _coats,
                            currentIndex: _coatIndex,
                            onPrev: () => _cycleCoat(-1),
                            onNext: () => _cycleCoat(1),
                            constraints: constraints,
                            isNarrow: false,
                          ),
                        ],
                      ),
                    // --- DEĞİŞİKLİK SONU ---

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 60,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: maxPhotoAreaWidth,
                  maxHeight: maxPhotoAreaHeight,
                ),
                child: _buildPhotoArea(constraints, isNarrow: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- GÜNCELLENDİ: _buildNarrowLayout ---
  Widget _buildNarrowLayout(BoxConstraints constraints) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPhotoArea(constraints, isNarrow: true),
          const SizedBox(height: 16),
          _buildCarousel(title: 'Tops', items: _tops, currentIndex: _topIndex, onPrev: () => _cycleTop(-1), onNext: () => _cycleTop(1), constraints: constraints, isNarrow: true),
          const SizedBox(height: 16),
          _buildCarousel(title: 'Bottoms', items: _bottoms, currentIndex: _bottomIndex, onPrev: () => _cycleBottom(-1), onNext: () => _cycleBottom(1), constraints: constraints, isNarrow: true),
          
          // --- DEĞİŞİKLİK BURADA ---
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Checkbox95(
              label: 'Add Coat',
              value: _showCoatCarousel,
              onChanged: _toggleCoatCarousel,
            ),
          ),
          if (_showCoatCarousel)
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                _buildCarousel(
                  title: 'Coats',
                  items: _coats,
                  currentIndex: _coatIndex,
                  onPrev: () => _cycleCoat(-1),
                  onNext: () => _cycleCoat(1),
                  constraints: constraints,
                  isNarrow: true,
                ),
              ],
            ),
          // --- DEĞİŞİKLİK SONU ---

          const SizedBox(height: 20),
        ],
      ),
    );
  }


  // --- UI PARÇALARI (REUSABLE WIDGETS) ---
  Widget _buildCarousel({
    required String title,
    required List<ClothingItem> items,
    required int currentIndex,
    required VoidCallback onPrev,
    required VoidCallback onNext,
    required BoxConstraints constraints,
    required bool isNarrow,
  }) {
    final double innerWidth = isNarrow ? (constraints.maxWidth * 0.5).clamp(180.0, 250.0) : 220.0;
    final double innerHeight = (innerWidth * 0.7).clamp(90.0, 150.0);
    Widget content;
    if (items.isEmpty) {
        content = const Center(child: Text('No items yet.'));
    } else {
        final item = items[currentIndex];
        if (item is ColorItem) {
          content = Container(margin: const EdgeInsets.all(8), color: item.color);
        } else if (item is ImageItem) {
          content = Padding(
            padding: const EdgeInsets.all(4.0),
            child: Image.file(File(item.path), fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Center(child: Icon(Icons.error));
              },
            ),
          );
        } else {
          content = const SizedBox.shrink();
        }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 8),
          child: Text(title, style: Flutter95.textStyle),
        ),
        Elevation95(
          type: Elevation95Type.down,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: const Color(0xFF947B7B),
            child: Row(
              // mainAxisAlignment: MainAxisAlignment.center, // <--- DEĞİŞİKLİK: Bu satır kaldırıldı/yorumlandı
              children: [
                _triangleButton(onTap: onPrev),
                
                // <--- DEĞİŞİKLİK BURADA BAŞLIYOR ---
                Expanded(
                  child: Container(
                    // width: innerWidth, // <--- DEĞİŞİKLİK: Bu satır kaldırıldı
                    height: innerHeight,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: Flutter95.white,
                    child: Center(child: content),
                  ),
                ),
                // <--- DEĞİŞİKLİK BURADA BİTİYOR ---

                _triangleButton(onTap: onNext, rotate: false),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildPhotoArea(BoxConstraints constraints, {required bool isNarrow}) {
      Widget photoContent;
      if (_generatedOutfitImage != null) {
        photoContent = Image.file(_generatedOutfitImage!, fit: BoxFit.contain, alignment: Alignment.bottomCenter);
      } 
      else if (_userImage != null) {
        photoContent = Image.file(_userImage!, fit: BoxFit.contain, alignment: Alignment.bottomCenter);
      } 
      else {
        photoContent = const Center(child: Text('Add Your Photo', style: Flutter95.textStyle));
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Elevation95(
              type: Elevation95Type.down,
              child: Container(
                width: double.infinity,
                color: const Color(0xFFB38C8C),
                padding: const EdgeInsets.all(12),
                child: GestureDetector( 
                  onTap: _pickUserPhoto,
                  child: Container(
                    color: const Color(0xFFF1E2E2),
                    child: photoContent, 
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            
            // --- DEĞİŞİKLİK BURADA BAŞLIYOR ---

            // 1. ÇÖZÜM: Butonu dışarıdan SizedBox ile sararak boyut veriyoruz.
            child: SizedBox(
              width: 220.0,  // <-- Buton için istediğiniz genişlik
              height: 48.0, // <-- Buton için istediğiniz yükseklik
              child: Button95(
                onTap: _createOutfit,
                child: Padding(
                  // Bu padding artık sadece metnin kenara yapışmamasını sağlar
                  padding: const EdgeInsets.symmetric(horizontal: 8.0), 
                  child: Center(
                    
                    // 2. ÇÖZÜM: Yazıyı butona "bind" etmek için FittedBox kullanıyoruz.
                    child: FittedBox(
                      fit: BoxFit.scaleDown, // Metni, gerekirse küçülterek sığdır
                      child: Text(
                        'Create outfit diva!', 
                        style: Flutter95.textStyle.copyWith(
                          color: const Color.fromARGB(255, 0, 0, 0),
                        ),
                      ),
                    ),

                  ),
                ),
              ),
            ),
            // --- DEĞİŞİKLİK SONU ---
          ),
        ],
      );
    }

  Widget _triangleButton({required VoidCallback onTap, bool rotate = true}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.all(4.0),
        child: Elevation95(
          child: Container(
            width: 36,
            height: 36,
            color: const Color(0xFFD9C8C8),
            child: Transform.rotate(
              angle: rotate ? math.pi : 0,
              child: const Center(
                child: Icon(Icons.play_arrow, size: 18, color: Color(0xFF8B5A5A)),
              ),
            ),
          ),
        ),
      ),
    );
  }
  Menu95 _buildMenu() {
    return Menu95(
      items: [
        MenuItem95(value: 1, label: 'Add Tops'),
        MenuItem95(value: 2, label: 'Add Bottoms'),
        MenuItem95(value:3, label: 'Add Coat'),
      ],
      onItemSelected: (item) {
        switch (item) {
          case 1: _pickAndAddImage(ClothingCategory.top); break;
          case 2: _pickAndAddImage(ClothingCategory.bottom); break;
          case 3: _pickAndAddImage(ClothingCategory.coat); break;
        }
      },
    );
  }
}