import 'package:flutter_test/flutter_test.dart';
import 'package:ticketing_system/core/services/google_drive/google_drive_models.dart';
import 'package:ticketing_system/core/utils/storage_utils.dart';

void main() {
  group('GoogleDriveConfig Model Tests', () {
    test('Default configuration properties are set correctly', () {
      const config = GoogleDriveConfig(connected: false);

      expect(config.connected, isFalse);
      expect(config.clientId, equals(GoogleDriveConfig.defaultClientId));
      expect(config.folderName, equals(GoogleDriveConfig.defaultFolderName));
      expect(config.thresholdBytes, equals(45 * 1024 * 1024)); // 45 MB
      expect(config.canAuthenticate, isFalse);
      expect(config.isTokenValid, isFalse);
    });

    test('isTokenValid recognizes valid vs expired access tokens', () {
      final validConfig = GoogleDriveConfig(
        connected: true,
        accessToken: 'mock_valid_token',
        expiry: DateTime.now().add(const Duration(minutes: 30)),
      );
      expect(validConfig.isTokenValid, isTrue);

      final expiredConfig = GoogleDriveConfig(
        connected: true,
        accessToken: 'mock_expired_token',
        expiry: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      expect(expiredConfig.isTokenValid, isFalse);

      final noTokenConfig = const GoogleDriveConfig(
        connected: true,
        accessToken: null,
      );
      expect(noTokenConfig.isTokenValid, isFalse);
    });

    test('canAuthenticate returns true when refreshToken is present', () {
      const configWithRefresh = GoogleDriveConfig(
        connected: true,
        refreshToken: 'mock_refresh_token_123',
      );
      expect(configWithRefresh.canAuthenticate, isTrue);
    });

    test('JSON serialization and deserialization roundtrip preserves all fields', () {
      final now = DateTime.now().toUtc();
      final expiry = now.add(const Duration(hours: 1));

      final original = GoogleDriveConfig(
        connected: true,
        email: 'admin@tallycare.com',
        folderName: 'TallyCare Custom Folder',
        folderId: 'folder_abc_123',
        clientId: 'custom_client_id.apps.googleusercontent.com',
        clientSecret: 'custom_secret_xyz',
        refreshToken: 'refresh_tok_999',
        accessToken: 'access_tok_888',
        expiry: expiry,
        thresholdBytes: 45 * 1024 * 1024,
        connectedAt: now,
        connectedBy: 'superadmin',
      );

      final json = original.toJson();
      final restored = GoogleDriveConfig.fromJson(json);

      expect(restored.connected, isTrue);
      expect(restored.email, equals('admin@tallycare.com'));
      expect(restored.folderName, equals('TallyCare Custom Folder'));
      expect(restored.folderId, equals('folder_abc_123'));
      expect(restored.clientId, equals('custom_client_id.apps.googleusercontent.com'));
      expect(restored.clientSecret, equals('custom_secret_xyz'));
      expect(restored.refreshToken, equals('refresh_tok_999'));
      expect(restored.accessToken, equals('access_tok_888'));
      expect(restored.thresholdBytes, equals(45 * 1024 * 1024));
      expect(restored.connectedBy, equals('superadmin'));
      expect(restored.canAuthenticate, isTrue);
    });

    test('String serialization helper serialize() and deserialize() work identically', () {
      final config = GoogleDriveConfig(
        connected: true,
        email: 'test@company.com',
        refreshToken: 'rt_123',
      );

      final rawString = config.serialize();
      final deserialized = GoogleDriveConfig.deserialize(rawString);

      expect(deserialized, isNotNull);
      expect(deserialized!.email, equals('test@company.com'));
      expect(deserialized.refreshToken, equals('rt_123'));
    });
  });

  group('Storage Constants and Threshold Tests', () {
    test('kGoogleDriveThreshold is exactly 45 MB', () {
      expect(kGoogleDriveThreshold, equals(45 * 1024 * 1024));
      expect(kGoogleDriveThreshold, equals(47185920));
    });

    test('formatChatFileSize formats large gigabyte files correctly', () {
      final threeGb = (3.05 * 1024 * 1024 * 1024).round();
      expect(formatChatFileSize(threeGb), equals('3.05 GB'));

      final fiftyMb = 50 * 1024 * 1024;
      expect(formatChatFileSize(fiftyMb), equals('50.0 MB'));

      final fortyFiveMb = 45 * 1024 * 1024;
      expect(formatChatFileSize(fortyFiveMb), equals('45.0 MB'));
    });
  });
}
