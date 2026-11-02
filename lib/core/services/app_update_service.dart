import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_version.dart';
import '../models/app_version_control.dart';

/// Service responsible for checking app updates against Supabase remote config
/// and launching the Google Play Store when an update is available.
class AppUpdateService {
  static const String settingKey = 'app_version_control';
  static const String defaultPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=com.aroundtally.tallycare';

  /// Performs an update check against the Supabase `app_settings` table.
  /// Returns `null` if the check could not be performed or on Web.
  Future<AppUpdateCheckResult?> checkForUpdate() async {
    // Only enforce updates on mobile devices (Android / iOS).
    // Web and desktop applications are served/deployed separately and skipped.
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return null;

    try {
      // 1. Get current installed app version details
      int currentBuildNumber = int.tryParse(AppVersion.buildNumber) ?? 1;
      String currentVersionName = AppVersion.version;

      try {
        final packageInfo = await PackageInfo.fromPlatform();
        final parsedBuild = int.tryParse(packageInfo.buildNumber);
        if (parsedBuild != null && parsedBuild > 0) {
          currentBuildNumber = parsedBuild;
        }
        if (packageInfo.version.isNotEmpty) {
          currentVersionName = 'v${packageInfo.version}';
        }
      } catch (e) {
        debugPrint('PackageInfo read error (using fallback): $e');
      }

      // 2. Query Supabase for remote version control configuration
      final client = Supabase.instance.client;
      final response = await client
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', settingKey)
          .maybeSingle();

      if (response == null || response['setting_value'] == null) {
        debugPrint('No app_version_control setting found in app_settings.');
        return null;
      }

      final rawValue = response['setting_value'];
      if (rawValue is! Map<String, dynamic>) {
        debugPrint('Invalid format for app_version_control: $rawValue');
        return null;
      }

      final config = AppVersionControl.fromJson(rawValue);

      // 3. Determine update status
      AppUpdateStatus status;
      if (currentBuildNumber < config.minVersionCode && config.forceUpdate) {
        status = AppUpdateStatus.forceUpdate;
      } else if (currentBuildNumber < config.latestVersionCode) {
        status = AppUpdateStatus.flexibleUpdate;
      } else {
        status = AppUpdateStatus.upToDate;
      }

      debugPrint(
        'AppUpdateCheck: installed=($currentVersionName, build $currentBuildNumber), '
        'minCode=${config.minVersionCode}, latestCode=${config.latestVersionCode}, '
        'status=$status',
      );

      return AppUpdateCheckResult(
        status: status,
        currentBuildNumber: currentBuildNumber,
        currentVersionName: currentVersionName,
        config: config,
      );
    } catch (e, st) {
      debugPrint('AppUpdateService.checkForUpdate error (non-fatal): $e\n$st');
      return null;
    }
  }

  /// Opens the Google Play Store (or custom store URL).
  /// Attempts the native `market://` scheme first, then falls back to `https://`.
  Future<bool> openPlayStore({String? customUrl}) async {
    final urlString = (customUrl != null && customUrl.isNotEmpty)
        ? customUrl
        : defaultPlayStoreUrl;

    try {
      if (!kIsWeb && Platform.isAndroid) {
        final marketUri = Uri.parse('market://details?id=com.aroundtally.tallycare');
        if (await canLaunchUrl(marketUri)) {
          return await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        }
      }

      final webUri = Uri.parse(urlString);
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch Play Store: $e');
      try {
        final webUri = Uri.parse(urlString);
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        return false;
      }
    }
  }
}

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService();
});

/// AsyncNotifier to hold the current update check result and allow manual refresh
class AppUpdateNotifier extends AsyncNotifier<AppUpdateCheckResult?> {
  @override
  Future<AppUpdateCheckResult?> build() async {
    final service = ref.watch(appUpdateServiceProvider);
    return service.checkForUpdate();
  }

  Future<void> check() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(appUpdateServiceProvider);
      return service.checkForUpdate();
    });
  }

  /// Dismisses a flexible update prompt for the current session
  void dismissFlexible() {
    state = const AsyncValue.data(null);
  }
}

final appUpdateProvider =
    AsyncNotifierProvider<AppUpdateNotifier, AppUpdateCheckResult?>(
  AppUpdateNotifier.new,
);
