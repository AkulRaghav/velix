import 'dart:io';
class PlatformUtils {
  static bool get isAndroid => Platform.isAndroid;
  static bool get isIOS => Platform.isIOS;
  static bool get isMobile => isAndroid || isIOS;
  static bool get isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  static String get osName => Platform.operatingSystem;
  static String get osVersion => Platform.operatingSystemVersion;
}
