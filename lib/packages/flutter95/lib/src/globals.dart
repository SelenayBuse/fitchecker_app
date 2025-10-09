import 'package:flutter/widgets.dart';

class Flutter95 {
  // Eskiden gri tonlarıydı, şimdi sevimli pembe tonları! 🌸
  // Bu tonlar 3D buton efektinin temelini oluşturuyor.
  static const pinks = [
    Color(0xFFFFFFFF), // En açık renk (Işıklandırma için saf beyaz)
    Color(0xFFFEE7F0), // Ana yüzey rengi (Çok açık pastel pembe)
    Color(0xFFF8C4D8), // Gölge rengi (Biraz daha koyu pembe)
    Color(0xFFB48DA0), // Koyu gölge ve pasif yazı rengi (Daha tok, lila-pembe)
  ];

  // Ana renklerimizi canlı ve tatlı pembelerle değiştirdik
  static const primary = Color(0xFFF472B6);     // Canlı bir pembe
  static const secondary = Color(0xFFFBCFE8);   // Çok açık, yardımcı pembe

  // Pencere başlıkları için tatlı bir pembe gradyanı
  static const headerDark = Color(0xFFF472B6);  // Başlangıç rengi
  static const headerLight = Color(0xFFFBCFE8); // Bitiş rengi

  // Bunlar standart, dokunmuyoruz.
  static const white = Color(0xFFFFFFFF);
  static const black = Color.fromRGBO(5, 6, 8, 1);
  
  // İpucu kutucuklarının arkaplanı için krem rengi
  static const tooltipBackground = Color(0xFFFFF7E3);

  // Arkaplan rengi olarak yeni pembe paletimizi kullanıyoruz
  static Color get background => pinks[1];

  static const _elevationWidth = 1.5;

  //
  // BURADAN SONRAKİ KODLARIN MANTIĞINA DOKUNMADIK.
  // SADECE YUKARIDA TANIMLADIĞIMIZ YENİ PEMBE RENKLERİNİ KULLANIYORLAR.
  // 'grays' yerine 'pinks' yazdık.
  //
  
  static final elevatedDecoration = BoxDecoration(
    color: background,
    border: Border(
      top: BorderSide(color: Flutter95.pinks[0], width: _elevationWidth),
      left: BorderSide(color: Flutter95.pinks[0], width: _elevationWidth),
      bottom: BorderSide(color: Flutter95.pinks[2], width: _elevationWidth),
      right: BorderSide(color: Flutter95.pinks[2], width: _elevationWidth),
    ),
  );

  static final elevatedDecorationOutside = BoxDecoration(
    color: background,
    border: Border(
      top: const BorderSide(color: Flutter95.white, width: _elevationWidth),
      left: const BorderSide(color: Flutter95.white, width: _elevationWidth),
      bottom: BorderSide(color: Flutter95.pinks[3], width: _elevationWidth),
      right: BorderSide(color: Flutter95.pinks[3], width: _elevationWidth),
    ),
  );

  static final pressedDecoration = BoxDecoration(
    color: background,
    border: Border(
      top: BorderSide(color: Flutter95.pinks[2], width: _elevationWidth),
      left: BorderSide(color: Flutter95.pinks[2], width: _elevationWidth),
      bottom: BorderSide(color: Flutter95.pinks[0], width: _elevationWidth),
      right: BorderSide(color: Flutter95.pinks[0], width: _elevationWidth),
    ),
  );

  static final pressedDecorationOutside = BoxDecoration(
    color: background,
    border: Border(
      top: BorderSide(color: Flutter95.pinks[3], width: _elevationWidth),
      left: BorderSide(color: Flutter95.pinks[3], width: _elevationWidth),
      bottom: const BorderSide(color: Flutter95.white, width: _elevationWidth),
      right: const BorderSide(color: Flutter95.white, width: _elevationWidth),
    ),
  );

  static final invisibleBorder = BoxDecoration(
    color: background,
    border: Border.all(color: background),
  );

  static const headerTextStyle = TextStyle(
    color: Color(0xFFFFFFFF),
    fontSize: 16,
    decoration: TextDecoration.none,
    fontWeight: FontWeight.bold,
  );

  static const textStyle = TextStyle(
    color: Flutter95.black,
    fontSize: 14,
    decoration: TextDecoration.none,
    fontWeight: FontWeight.normal,
  );

  static final disabledTextStyle = TextStyle(
    color: Flutter95.pinks[3], // Pasif yazı rengi için yeni paletimiz
    fontSize: 14,
    decoration: TextDecoration.none,
    fontWeight: FontWeight.normal,
    shadows: [
      Shadow(
        color: Flutter95.pinks[0],
        offset: const Offset(1, 1),
      ),
    ],
  );
}