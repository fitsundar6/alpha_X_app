import 'package:flutter/foundation.dart';

/// Application Version Information model for Alpha X Gym.
/// Encapsulates version requirements, release notes, and platform download links.
class AppVersionInfo {
  final String latestVersion;
  final String minimumRequiredVersion;
  final bool forceUpdate;
  final String releaseNotes;
  final String downloadUrl;
  final String playStoreUrl;
  final String appStoreUrl;
  final DateTime? updatedAt;

  const AppVersionInfo({
    required this.latestVersion,
    required this.minimumRequiredVersion,
    this.forceUpdate = false,
    this.releaseNotes = '',
    this.downloadUrl = '',
    this.playStoreUrl = '',
    this.appStoreUrl = '',
    this.updatedAt,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      latestVersion: json['latestVersion']?.toString() ?? '1.0.0',
      minimumRequiredVersion: json['minimumRequiredVersion']?.toString() ?? '1.0.0',
      forceUpdate: json['forceUpdate'] == true,
      releaseNotes: json['releaseNotes']?.toString() ?? '',
      downloadUrl: json['downloadUrl']?.toString() ?? '',
      playStoreUrl: json['playStoreUrl']?.toString() ?? '',
      appStoreUrl: json['appStoreUrl']?.toString() ?? '',
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'latestVersion': latestVersion,
        'minimumRequiredVersion': minimumRequiredVersion,
        'forceUpdate': forceUpdate,
        'releaseNotes': releaseNotes,
        'downloadUrl': downloadUrl,
        'playStoreUrl': playStoreUrl,
        'appStoreUrl': appStoreUrl,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  /// Compares two semantic version strings (e.g. "1.0.0" and "1.0.1").
  /// Returns:
  /// - negative if v1 < v2
  /// - 0 if v1 == v2
  /// - positive if v1 > v2
  static int compareVersions(String v1, String v2) {
    final cleanV1 = _cleanVersion(v1);
    final cleanV2 = _cleanVersion(v2);

    final parts1 = cleanV1.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final parts2 = cleanV2.split('.').map((p) => int.tryParse(p) ?? 0).toList();

    final maxLen = parts1.length > parts2.length ? parts1.length : parts2.length;

    for (int i = 0; i < maxLen; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;

      if (p1 < p2) return -1;
      if (p1 > p2) return 1;
    }

    return 0;
  }

  static String _cleanVersion(String v) {
    var s = v.trim();
    if (s.toLowerCase().startsWith('v')) {
      s = s.substring(1).trim();
    }
    // Remove build number (+1) and prerelease tags (-beta)
    if (s.contains('+')) {
      s = s.split('+').first;
    }
    if (s.contains('-')) {
      s = s.split('-').first;
    }
    return s;
  }

  /// Returns true if a newer version exists compared to [currentVersion]
  bool isUpdateAvailable(String currentVersion) {
    return compareVersions(currentVersion, latestVersion) < 0;
  }

  /// Returns true if the app is below the minimum required version or forceUpdate is flagged
  bool isForceUpdateRequired(String currentVersion) {
    if (forceUpdate) return true;
    return compareVersions(currentVersion, minimumRequiredVersion) < 0;
  }

  /// Resolves the most appropriate download/store URL for the current platform
  String resolveDownloadUrl({TargetPlatform? platform, bool isWeb = kIsWeb}) {
    if (isWeb) {
      return downloadUrl.isNotEmpty ? downloadUrl : playStoreUrl;
    }

    final target = platform ?? defaultTargetPlatform;
    switch (target) {
      case TargetPlatform.android:
        return playStoreUrl.isNotEmpty ? playStoreUrl : downloadUrl;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return appStoreUrl.isNotEmpty ? appStoreUrl : downloadUrl;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      default:
        return downloadUrl.isNotEmpty ? downloadUrl : playStoreUrl;
    }
  }
}
