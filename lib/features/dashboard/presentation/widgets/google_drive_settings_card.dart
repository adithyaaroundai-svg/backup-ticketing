import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/components/app_card.dart';
import '../../../../core/design_system/theme/app_colors.dart';
import '../../../../core/services/google_drive/google_drive_chat_service.dart';
import '../../../../core/services/google_drive/google_drive_models.dart';

class GoogleDriveSettingsCard extends StatefulWidget {
  const GoogleDriveSettingsCard({super.key});

  @override
  State<GoogleDriveSettingsCard> createState() => _GoogleDriveSettingsCardState();
}

class _GoogleDriveSettingsCardState extends State<GoogleDriveSettingsCard> {
  GoogleDriveConfig? _config;
  bool _isLoading = true;
  bool _isConnecting = false;
  bool _isConnectingWithToken = false;
  bool _isTesting = false;
  bool _showAdvanced = false;

  final _clientIdController = TextEditingController();
  final _clientSecretController = TextEditingController();
  final _refreshTokenController = TextEditingController();
  final _folderNameController = TextEditingController(text: GoogleDriveConfig.defaultFolderName);

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    _clientSecretController.dispose();
    _refreshTokenController.dispose();
    _folderNameController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final config = await GoogleDriveChatService.getConfig(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _config = config;
          if (config != null) {
            _clientIdController.text = config.clientId;
            _clientSecretController.text = config.clientSecret ?? '';
            _folderNameController.text = config.folderName;
          } else {
            _clientIdController.text = GoogleDriveConfig.defaultClientId;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _connectAccount() async {
    setState(() => _isConnecting = true);
    try {
      final customId = _clientIdController.text.trim();
      final customSecret = _clientSecretController.text.trim();
      final folder = _folderNameController.text.trim();

      final newConfig = await GoogleDriveChatService.authorizeCompanyAccount(
        customClientId: customId.isNotEmpty ? customId : null,
        customClientSecret: customSecret.isNotEmpty ? customSecret : null,
        customFolderName: folder.isNotEmpty ? folder : null,
      );

      if (mounted) {
        setState(() {
          _config = newConfig;
          _isConnecting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Company Google Drive connected successfully (${newConfig.email ?? 'Active'})!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConnecting = false);
        final err = e.toString();
        final isOriginMismatch = err.contains('popup_closed') || err.contains('origin_mismatch');
        final currentPort = kIsWeb ? Uri.base.port : 0;
        final errorMsg = isOriginMismatch
            ? 'Google blocked the popup ("origin_mismatch") because port $currentPort is not in Google Cloud Console\'s Authorized Origins. Please use the Direct Refresh Token setup below.'
            : 'Failed to connect Google Drive: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  Future<void> _connectWithToken() async {
    final token = _refreshTokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please paste a valid Google OAuth Refresh Token.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isConnectingWithToken = true);
    try {
      final customId = _clientIdController.text.trim();
      final customSecret = _clientSecretController.text.trim();
      final folder = _folderNameController.text.trim();

      final newConfig = await GoogleDriveChatService.connectWithRefreshToken(
        refreshToken: token,
        clientId: customId.isNotEmpty ? customId : null,
        clientSecret: customSecret.isNotEmpty ? customSecret : null,
        folderName: folder.isNotEmpty ? folder : null,
      );

      if (mounted) {
        setState(() {
          _config = newConfig;
          _isConnectingWithToken = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Company Google Drive connected successfully (${newConfig.email ?? 'Active'})!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConnectingWithToken = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect with token: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Future<void> _testConnection() async {
    setState(() => _isTesting = true);
    try {
      final success = await GoogleDriveChatService.testConnection();
      if (mounted) {
        setState(() => _isTesting = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google Drive connection is healthy and ready for uploads!'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google Drive connection test failed. Please try reconnecting.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTesting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Google Drive?'),
        content: const Text(
          'Chat attachments > 45 MB will no longer upload automatically to Google Drive until reconnected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnect', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      await GoogleDriveChatService.disconnect();
      await _loadConfig(forceRefresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Company Google Drive disconnected.'),
            backgroundColor: AppColors.slate700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _config != null && _config!.connected && _config!.canAuthenticate;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4285F4).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.cloud_sync_rounded,
                    color: Color(0xFF1A73E8),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Company Google Drive Integration',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isConnected
                                  ? const Color(0xFF34A853).withValues(alpha: 0.15)
                                  : AppColors.slate200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isConnected ? Icons.check_circle : Icons.radio_button_unchecked,
                                  size: 13,
                                  color: isConnected ? const Color(0xFF1E8E3E) : AppColors.slate600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isConnected ? 'Connected' : 'Not Connected',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isConnected ? const Color(0xFF1E8E3E) : AppColors.slate600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Automatic Google Drive streaming for chat attachments > 45 MB (Gmail style).',
                        style: TextStyle(fontSize: 12, color: AppColors.slate500),
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(LucideIcons.refreshCw, size: 16),
                    tooltip: 'Refresh Status',
                    onPressed: () => _loadConfig(forceRefresh: true),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Explanatory info box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF16A34A), size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'One-time company setup: Once an admin connects the company Google account below, '
                      'all team members and agents can attach large files (> 45 MB up to multiple GBs) without '
                      'signing in individually. TallyCare streams them in the background and shares direct links in chat.',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF166534), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (isConnected) ...[
              // Connected State Details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.mail, size: 16, color: AppColors.slate500),
                        const SizedBox(width: 8),
                        const Text(
                          'Authorized Account:',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _config?.email ?? 'Company Drive Account',
                          style: const TextStyle(fontSize: 13, color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(LucideIcons.folder, size: 16, color: AppColors.slate500),
                        const SizedBox(width: 8),
                        const Text(
                          'Destination Folder:',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _config?.folderName ?? GoogleDriveConfig.defaultFolderName,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                    if (_config?.connectedAt != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(LucideIcons.calendar, size: 16, color: AppColors.slate500),
                          const SizedBox(width: 8),
                          const Text(
                            'Connected Since:',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat.yMMMd().format(_config!.connectedAt!),
                            style: const TextStyle(fontSize: 13, color: AppColors.slate600),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Action buttons when connected
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isTesting ? null : _testConnection,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.checkCheck, size: 16),
                    label: const Text('Test Connection'),
                  ),
                  if (_config?.folderId != null && _config!.folderId!.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () {
                        launchUrl(
                          Uri.parse(
                            'https://drive.google.com/drive/folders/${_config!.folderId}',
                          ),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      icon: const Icon(LucideIcons.externalLink, size: 16),
                      label: const Text('Open Drive Folder'),
                    ),
                  OutlinedButton.icon(
                    onPressed: _disconnect,
                    icon: const Icon(LucideIcons.logOut, size: 16, color: AppColors.error),
                    label: const Text('Disconnect', style: TextStyle(color: AppColors.error)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Not Connected State: Two Connection Methods

              // Option A: Direct Refresh Token (Fastest, avoids origin_mismatch)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1A73E8).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.keyRound, size: 18, color: Color(0xFF1A73E8)),
                        const SizedBox(width: 8),
                        const Text(
                          'Quick Setup: Connect via Refresh Token',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF34A853).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Recommended for Web',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E8E3E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Bypasses browser popup blocks and origin mismatches. Generates a permanent connection for the entire company.',
                      style: TextStyle(fontSize: 12, color: AppColors.slate600),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _refreshTokenController,
                            decoration: const InputDecoration(
                              hintText: 'Paste Google OAuth Refresh Token (e.g. 1//04...)',
                              border: OutlineInputBorder(),
                              isDense: true,
                              prefixIcon: Icon(LucideIcons.key, size: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _isConnectingWithToken ? null : _connectWithToken,
                          icon: _isConnectingWithToken
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(LucideIcons.plug, size: 16),
                          label: const Text('Connect'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A73E8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Quick Guide Box
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.slate200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.helpCircle, size: 14, color: AppColors.slate500),
                              const SizedBox(width: 6),
                              const Text(
                                'How to get a Refresh Token in 1 minute:',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              InkWell(
                                onTap: () => launchUrl(
                                  Uri.parse('https://developers.google.com/oauthplayground'),
                                  mode: LaunchMode.externalApplication,
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Open Google OAuth Playground',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF1A73E8),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: 3),
                                    Icon(LucideIcons.externalLink, size: 12, color: Color(0xFF1A73E8)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '1. In OAuth Playground Step 1, select Drive API v3 -> https://www.googleapis.com/auth/drive.file\n'
                            '2. Click "Authorize APIs" and sign into your company Google account.\n'
                            '3. In Step 2, click "Exchange authorization code for tokens" and copy the "Refresh token".\n'
                            '4. Paste it in the input above and click Connect.',
                            style: TextStyle(fontSize: 11.5, color: AppColors.slate600, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Center(
                child: Text(
                  '— OR —',
                  style: TextStyle(fontSize: 12, color: AppColors.slate400, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),

              // Option B: Browser Popup
              Center(
                child: OutlinedButton.icon(
                  onPressed: _isConnecting ? null : _connectAccount,
                  icon: _isConnecting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.open_in_new, size: 16),
                  label: Text(
                    _isConnecting ? 'Waiting for Browser...' : 'Connect via Browser Popup (Standard OAuth)',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ),
              if (kIsWeb)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Center(
                    child: Text(
                      'Requires "http://localhost:${Uri.base.port}" added to Authorized JavaScript Origins in Google Cloud Console.',
                      style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              // Advanced Configuration Toggle
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
                  child: Text(
                    _showAdvanced ? 'Hide Advanced Settings' : 'Advanced OAuth Settings (Client ID / Secret)',
                    style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                  ),
                ),
              ),

              if (_showAdvanced) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.slate50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Custom OAuth Client ID (Optional)',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _clientIdController,
                        decoration: const InputDecoration(
                          hintText: 'Enter OAuth 2.0 Web/Desktop Client ID',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Custom OAuth Client Secret (Optional)',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _clientSecretController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: 'Enter Client Secret (if desktop client type)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Target Google Drive Folder Name',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _folderNameController,
                        decoration: const InputDecoration(
                          hintText: 'TallyCare Chat Attachments',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
