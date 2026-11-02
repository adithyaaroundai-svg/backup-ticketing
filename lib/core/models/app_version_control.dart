class AppVersionControl {
  final int minVersionCode;
  final int latestVersionCode;
  final String minVersionName;
  final String latestVersionName;
  final bool forceUpdate;
  final String title;
  final String message;
  final String releaseNotes;
  final String playStoreUrl;

  const AppVersionControl({
    this.minVersionCode = 1,
    this.latestVersionCode = 1,
    this.minVersionName = '1.0.0',
    this.latestVersionName = '1.0.0',
    this.forceUpdate = false,
    this.title = 'Update Required',
    this.message =
        'A newer version of TallyCare is available on Google Play. Please update to continue using the app.',
    this.releaseNotes = '',
    this.playStoreUrl =
        'https://play.google.com/store/apps/details?id=com.aroundtally.tallycare',
  });

  factory AppVersionControl.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val, int fallback) {
      if (val is int) return val;
      if (val is String) return int.tryParse(val) ?? fallback;
      return fallback;
    }

    return AppVersionControl(
      minVersionCode: parseInt(json['min_version_code'], 1),
      latestVersionCode: parseInt(json['latest_version_code'], 1),
      minVersionName: json['min_version_name']?.toString() ?? '1.0.0',
      latestVersionName: json['latest_version_name']?.toString() ?? '1.0.0',
      forceUpdate: json['force_update'] as bool? ?? true,
      title: json['title']?.toString() ?? 'Update Required',
      message: json['message']?.toString() ??
          'A newer version of TallyCare is available on Google Play. Please update to continue using the app.',
      releaseNotes: json['release_notes']?.toString() ?? '',
      playStoreUrl: json['play_store_url']?.toString() ??
          'https://play.google.com/store/apps/details?id=com.aroundtally.tallycare',
    );
  }

  Map<String, dynamic> toJson() => {
        'min_version_code': minVersionCode,
        'latest_version_code': latestVersionCode,
        'min_version_name': minVersionName,
        'latest_version_name': latestVersionName,
        'force_update': forceUpdate,
        'title': title,
        'message': message,
        'release_notes': releaseNotes,
        'play_store_url': playStoreUrl,
      };
}

enum AppUpdateStatus {
  upToDate,
  flexibleUpdate, // Newer version available, but not mandatory
  forceUpdate, // Mandatory update required before app can be used
}

class AppUpdateCheckResult {
  final AppUpdateStatus status;
  final int currentBuildNumber;
  final String currentVersionName;
  final AppVersionControl config;

  const AppUpdateCheckResult({
    required this.status,
    required this.currentBuildNumber,
    required this.currentVersionName,
    required this.config,
  });

  bool get isForceUpdate => status == AppUpdateStatus.forceUpdate;
  bool get isFlexibleUpdate => status == AppUpdateStatus.flexibleUpdate;
}
