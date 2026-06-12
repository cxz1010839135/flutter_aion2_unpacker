/// AION2 相关常量
class Aion2Constants {
  Aion2Constants._();

  static const String appName = 'AION2 解包工具';
  static const String appVersion = '1.0.0';
  static const String officialUrl = 'https://tw.ncsoft.com/aion2/index?redirect=false';

  /// UE5.3 引擎版本标识
  static const String engineVersion = 'UE 5.3';

  /// 台服默认安装路径候选
  static const List<String> defaultGamePaths = [
    r'C:\Program Files (x86)\NCSOFT\AION2_TW\Aion2',
    r'C:\Program Files\NCSOFT\AION2_TW\Aion2',
    r'D:\Games\NCSOFT\AION2_TW\Aion2',
    r'D:\NCSOFT\AION2_TW\Aion2',
    r'E:\Games\NCSOFT\AION2_TW\Aion2',
  ];

  static const String paksSubPath = r'Content\Paks';

  /// PAK 文件魔数
  static const int pakMagic = 0x5A6F12E1;
}
