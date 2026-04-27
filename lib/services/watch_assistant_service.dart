import 'package:flutter/services.dart';

class WatchAppInfo {
  const WatchAppInfo({required this.packageName, required this.appName});

  final String packageName;
  final String appName;

  factory WatchAppInfo.fromMap(Map<dynamic, dynamic> map) {
    return WatchAppInfo(
      packageName: map['packageName']?.toString() ?? '',
      appName: map['appName']?.toString() ?? '',
    );
  }
}

class WatchAssistantService {
  static const MethodChannel _channel = MethodChannel(
    'ai_watch/watch_assistant',
  );

  Future<List<WatchAppInfo>> getLaunchableApps() async {
    final result = await _channel.invokeMethod<List<dynamic>>(
      'getLaunchableApps',
    );

    if (result == null) return const [];

    return result
        .whereType<Map<dynamic, dynamic>>()
        .map(WatchAppInfo.fromMap)
        .where((app) => app.packageName.isNotEmpty && app.appName.isNotEmpty)
        .toList();
  }

  Future<bool> openApp(String packageName) async {
    if (packageName.trim().isEmpty) return false;
    final result = await _channel.invokeMethod<bool>('openApp', {
      'packageName': packageName,
    });
    return result ?? false;
  }
}
