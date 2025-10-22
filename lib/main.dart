import 'package:flutter/material.dart';
import 'package:flutter95/flutter95.dart';
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:typed_data';
import 'utils/myErrorDialog.dart';
import 'utils/mySuccessDialog.dart';

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

      // DOĞRU YER BURASI
      theme: ThemeData(
        textTheme: TextTheme(
          
          // 'Flutter95.textStyle' yerine doğrudan kendimiz yazıyoruz
          bodyMedium: const TextStyle(
            fontFamily: 'Flutter95', // <-- Bu isim pubspec.yaml'daki ile aynı olmalı
            // Gerekirse diğer stil özelliklerini ekleyebilirsiniz
            // fontSize: 12,
            // color: Colors.black, 
          ),
          
          bodyLarge: const TextStyle(
            fontFamily: 'Flutter95',
          ),
          
          titleMedium: const TextStyle(
            fontFamily: 'Flutter95',
          ),
          
          // Diğer tüm metin stilleri için de bunu yapabilirsiniz
          // (displayLarge, displayMedium, ... headlineSmall, vb.)
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

  @override
  void initState() {
    super.initState();
    _loadAllSavedData();
  }

  Future<void> _loadAllSavedData() async {
    await _loadClothes();
    await _loadUserPhoto();
    setState(() {});
  }

  // --- KALICI DEPOLAMA METOTLARI ---
  Future<void> _saveClothes(ClothingCategory category) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${category.name}_images';
    List<ClothingItem> list;
    switch (category) {
      case ClothingCategory.top: list = _tops; break;
      case ClothingCategory.bottom: list = _bottoms; break;
      case ClothingCategory.coat: list = _coats; break;
    }
    final imagePaths = list.whereType<ImageItem>().map((item) => item.path).toList();
    await prefs.setStringList(key, imagePaths);
  }

  Future<void> _loadClothes() async {
    final prefs = await SharedPreferences.getInstance();
    for (var category in ClothingCategory.values) {
      final key = '${category.name}_images';
      final imagePaths = prefs.getStringList(key) ?? [];
      List<ClothingItem> targetList;
      switch (category) {
        case ClothingCategory.top: targetList = _tops; break;
        case ClothingCategory.bottom: targetList = _bottoms; break;
        case ClothingCategory.coat: targetList = _coats; break;
      }
      final existingPaths = targetList.whereType<ImageItem>().map((e) => e.path).toSet();
      for (var path in imagePaths) {
         if (!existingPaths.contains(path)) {
           targetList.add(ImageItem(path));
         }
      }
    }
  }

  Future<void> _saveUserPhotoPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_photo_path', path);
  }

  Future<void> _loadUserPhoto() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('user_photo_path');
    if (path != null && await File(path).exists()) {
      setState(() {
        _userImage = File(path);
      });
    }
  }

  // --- API İSTEK FONKSİYONLARI ---

  Future<Uint8List?> _removeBackground(String imagePath) async {
    final String? apiKey = dotenv.env['REMOVE_BG_API_KEY']?.trim();

    if (apiKey == null || apiKey.isEmpty) {
      debugPrint("HATA: .env dosyasında REMOVE_BG_API_KEY bulunamadı veya boş.");
      return null;
    }

    final uri = Uri.parse('https://api.remove.bg/v1.0/removebg');
    final request = http.MultipartRequest('POST', uri)
      ..headers['X-Api-Key'] = apiKey
      ..fields['size'] = 'auto'
      ..files.add(await http.MultipartFile.fromPath('image_file', imagePath));
      
    // ... fonksiyonun geri kalanı aynı ...
    try {
      final streamedResponse = await request.send();
      if (streamedResponse.statusCode == 200) {
        
        return await streamedResponse.stream.toBytes();

      } else {
        debugPrint("API Hatası: ${streamedResponse.statusCode}");
        debugPrint("Hata Detayı: ${await streamedResponse.stream.bytesToString()}");
        return null;
      }
    } catch (e) {
      debugPrint("İstek gönderilirken hata oluştu: $e");
      return null;
    }
  }

  Future<void> _generateOutfit() async {
    final topPath = _tops[_topIndex] is ImageItem ? (_tops[_topIndex] as ImageItem).path : null;
    final bottomPath = _bottoms[_bottomIndex] is ImageItem ? (_bottoms[_bottomIndex] as ImageItem).path : null;
    final coatPath = _coats[_coatIndex] is ImageItem ? (_coats[_coatIndex] as ImageItem).path : null;
    final userPhotoPath = _userImage?.path;

    if (userPhotoPath == null || topPath == null || bottomPath == null) {
      showDialog95(context: context, title: 'Eksik Parça!', message: 'Lütfen bir kullanıcı fotoğrafı, bir üst ve bir alt seçin.');
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final String? apiKey_nano = dotenv.env['NANO_BANANA_API_KEY'];
      var uri = Uri.parse('https://api.nanobanana.com/v1/generate_outfit'); // KENDİ API ADRESİN
      var request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $apiKey_nano';

      request.files.add(await http.MultipartFile.fromPath('user_photo', userPhotoPath));
      request.files.add(await http.MultipartFile.fromPath('top', topPath));
      request.files.add(await http.MultipartFile.fromPath('bottom', bottomPath));
      if (coatPath != null) {
        request.files.add(await http.MultipartFile.fromPath('coat', coatPath));
      }
      
      var streamedResponse = await request.send();
      
      if (streamedResponse.statusCode == 200) {
        final responseBytes = await streamedResponse.stream.toBytes();
        final tempDir = await getTemporaryDirectory();
        final generatedFile = await File('${tempDir.path}/generated_outfit.png').writeAsBytes(responseBytes);
        setState(() { _generatedOutfitImage = generatedFile; });
      } else {
        final responseBody = await streamedResponse.stream.bytesToString();
        showDialog95(context: context, title: 'API Hatası', message: 'Bir hata oluştu: ${streamedResponse.statusCode}\n$responseBody');
      }
    } catch (e) {
      showDialog95(context: context, title: 'Hata', message: 'İstek gönderilirken bir sorun oluştu: $e');
    } finally {
      setState(() { _isLoading = false; });
    }
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
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'user_photo_no_bg_${DateTime.now().millisecondsSinceEpoch}.png';
        final savedImageFile = await File(p.join(appDir.path, fileName)).writeAsBytes(imageBytesWithoutBg);
        
        debugPrint('>>> Arka planı temizlenmiş fotoğraf kaydedildi: ${savedImageFile.path}');

        setState(() {
          _userImage = savedImageFile;
          _generatedOutfitImage = null; 
        });
        await _saveUserPhotoPath(savedImageFile.path);
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
      // --- DÜZELTME 2: YÜKLEME BAŞLIYOR ---
      // Yüklemeyi burada başlatın ve tüm işlemler bitene kadar açık kalsın.
      setState(() {
        _isLoading = true;
      });

      try {
        // Arka plan kaldırma işlemi
        final imageBytesWithoutBg = await _removeBackground(pickedFilePath);

        if (imageBytesWithoutBg != null) {
          final appDir = await getApplicationDocumentsDirectory();
          final fileName = 'clothing_${category.name}_${DateTime.now().millisecondsSinceEpoch}.png';
          final savedImageFile = await File(p.join(appDir.path, fileName)).writeAsBytes(imageBytesWithoutBg);

          // --- DÜZELTME 1: DIALOG MESAJI ---
          // Kullanıcıya gösterilecek mesajı burada oluşturun.
          final String successMessage = 'Kıyafet başarıyla yüklendi.\nDizin: ${appDir.path}';

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
          
          // Bu işlem de 'await' içerdiği için loader'ın içinde kalmalı.
          await _saveClothes(category); 

          // Tüm işlemler bittikten sonra başarıyı göster
          if (mounted) { // 'await' sonrası context kontrolü
            showSuccessDialog95(context: context, title: 'Yükleme Başarılı', message: successMessage);
          }

        } else {
          // Arka plan temizlenemezse
          if (mounted) { // 'await' sonrası context kontrolü
            showErrorDialog95(context: context, title: 'Hata', message: 'Kıyafet fotoğrafının arka planı temizlenemedi.');
          }
        }
      } catch (e) {
        // Beklenmedik bir hata olursa
        debugPrint('Hata oluştu: $e');
        if (mounted) {
          showErrorDialog95(context: context, title: 'Hata', message: 'Beklenmedik bir hata oluştu: $e');
        }
      } finally {
        // --- DÜZELTME 2: YÜKLEME BİTTİ ---
        // İşlem başarılı da olsa, hata da alsa 'finally' bloğu çalışır.
        // Yükleme göstergesini burada durdurun.
        if (mounted) { // 'await' sonrası context kontrolü
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

  void _createOutfit() {
    showDialog95(
      context: context,
      title: 'Create outfit',
      message: 'This will call Nano Banana (not implemented).',
    );
  }

  // --- ANA BUILD METODU ---
  @override
  Widget build(BuildContext context) {
    return Scaffold95(
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
  }

  // --- LAYOUT BUILDER'LARI ---

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
                    _buildCarousel(
                      title: 'TOPS',
                      items: _tops,
                      currentIndex: _topIndex,
                      onPrev: () => _cycleTop(-1),
                      onNext: () => _cycleTop(1),
                      constraints: constraints,
                      isNarrow: false,
                    ),
                    const SizedBox(height: 16),
                    _buildCarousel(
                      title: 'BOTTOMS',
                      items: _bottoms,
                      currentIndex: _bottomIndex,
                      onPrev: () => _cycleBottom(-1),
                      onNext: () => _cycleBottom(1),
                      constraints: constraints,
                      isNarrow: false,
                    ),
                    const SizedBox(height: 16),
                    _buildCarousel(
                      title: 'COATS',
                      items: _coats,
                      currentIndex: _coatIndex,
                      onPrev: () => _cycleCoat(-1),
                      onNext: () => _cycleCoat(1),
                      constraints: constraints,
                      isNarrow: false,
                    ),
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

  Widget _buildNarrowLayout(BoxConstraints constraints) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPhotoArea(constraints, isNarrow: true),
          const SizedBox(height: 16),
          _buildCarousel(
            title: 'TOPS',
            items: _tops,
            currentIndex: _topIndex,
            onPrev: () => _cycleTop(-1),
            onNext: () => _cycleTop(1),
            constraints: constraints,
            isNarrow: true,
          ),
          const SizedBox(height: 16),
          _buildCarousel(
            title: 'BOTTOMS',
            items: _bottoms,
            currentIndex: _bottomIndex,
            onPrev: () => _cycleBottom(-1),
            onNext: () => _cycleBottom(1),
            constraints: constraints,
            isNarrow: true,
          ),
          const SizedBox(height: 16),
          _buildCarousel(
            title: 'COATS',
            items: _coats,
            currentIndex: _coatIndex,
            onPrev: () => _cycleCoat(-1),
            onNext: () => _cycleCoat(1),
            constraints: constraints,
            isNarrow: true,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- UI PARÇALARI (REUSABLE WIDGETS) ---

  Widget _buildCarousel({
    required String title,
    required List<ClothingItem> items, // Artık ClothingItem listesi alıyor
    required int currentIndex,
    required VoidCallback onPrev,
    required VoidCallback onNext,
    required BoxConstraints constraints,
    required bool isNarrow,
  }) {
    final double innerWidth = isNarrow
        ? (constraints.maxWidth * 0.5).clamp(180.0, 250.0)
        : 220.0;
    final double innerHeight = (innerWidth * 0.7).clamp(90.0, 150.0);

    // Görüntülenecek widget'ı belirle: Resim mi, Renk mi?
    Widget content;
    if (items.isEmpty) {
        content = const Center(child: Text('No items yet.'));
    } else {
        final item = items[currentIndex];
        if (item is ColorItem) {
          content = Container(
            margin: const EdgeInsets.all(8),
            color: item.color,
          );
        } else if (item is ImageItem) {
          content = Padding(
            padding: const EdgeInsets.all(4.0),
            child: Image.file(
              File(item.path),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // Resim yüklenemezse hata göster
                return const Center(child: Icon(Icons.error));
              },
            ),
          );
        } else {
          content = const SizedBox.shrink(); // Tanımsız tip için boş widget
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _triangleButton(onTap: onPrev),
                Container(
                  width: innerWidth,
                  height: innerHeight,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: Flutter95.white,
                  child: Center(
                    child: content, // Belirlenen widget'ı burada göster
                  ),
                ),
                _triangleButton(onTap: onNext, rotate: false),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoArea(BoxConstraints constraints, {required bool isNarrow}) {
    // Fotoğraf alanında gösterilecek widget
    Widget photoContent;
    if (_userImage != null) {
      photoContent = Image.file(_userImage!, fit: BoxFit.cover, alignment: Alignment.bottomCenter);
    } else {
      photoContent = const Center(
        child: Text('Add Your Photo', style: Flutter95.textStyle),
      );
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
              child: GestureDetector( // Tıklama algılaması için
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
          child: Button95(
            onTap: _createOutfit,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Create outfit diva!', style: Flutter95.textStyle),
            ),
          ),
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
                child: Icon(
                  Icons.play_arrow,
                  size: 18,
                  color: Color(0xFF8B5A5A),
                ),
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
        MenuItem95(value: 3, label: 'Add Coat'), // Değeri düzelttim
      ],
      onItemSelected: (item) {
        switch (item) {
          case 1:
            _pickAndAddImage(ClothingCategory.top);
            break;
          case 2:
            _pickAndAddImage(ClothingCategory.bottom);
            break;
          case 3:
            _pickAndAddImage(ClothingCategory.coat);
            break;
        }
      },
    );
  }
}