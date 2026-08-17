import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../tickets/presentation/providers/ticket_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../../domain/entities/chat_message.dart';
import 'markdown_text_editing_controller.dart';
import 'chat_voice_recorder.dart';
import 'video_message_widget.dart';
import '../../../../core/utils/download_helper.dart';
import '../../../sales/presentation/providers/lead_provider.dart';

IconData _getFileIcon(String? fileType) {
  if (fileType == null) return Icons.insert_drive_file;
  
  final type = fileType.toLowerCase();
  if (type == 'pdf') return Icons.picture_as_pdf;
  if (type == 'jpg' || type == 'jpeg' || type == 'png' || type == 'gif') return Icons.image;
  if (type == 'mp4' || type == 'mov' || type == 'avi') return Icons.videocam;
  if (type == 'mp3' || type == 'wav') return Icons.audio_file;
  if (type == 'doc' || type == 'docx') return Icons.description;
  if (type == 'xls' || type == 'xlsx') return Icons.table_chart;
  if (type == 'zip' || type == 'rar') return Icons.folder_zip;
  
  return Icons.insert_drive_file;
}

class SalesTeamChatView extends ConsumerStatefulWidget {
  const SalesTeamChatView({super.key});

  @override
  ConsumerState<SalesTeamChatView> createState() => _SalesTeamChatViewState();
}

class _SalesTeamChatViewState extends ConsumerState<SalesTeamChatView> {
  final String _channelId = 'sales-channel';
  final MarkdownTextEditingController _messageCtrl = MarkdownTextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _showScrollToBottom = false;
  String? _replyingTo;
  String? _replyToName;
  String? _replyToContent;

  // File attachment state
  PlatformFile? _selectedFile;
  bool _isUploading = false;

  // Emoji / GIF picker state
  bool _showEmojiPicker = false;
  bool _showGifPicker = false;
  final List<Map<String, String>> _gifResults = [];
  bool _gifLoading = false;
  final _gifSearchCtrl = TextEditingController();

  // Mentions
  bool _showMentions = false;
  String _mentionQuery = '';
  int _mentionStartIndex = 0;

  bool _isRecordingVoice = false;
  bool _isTextEmpty = true;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _focusNode.addListener(_onFocusChange);

    _messageCtrl.addListener(() {
      final text = _messageCtrl.text;
      final isEmpty = text.trim().isEmpty;
      if (isEmpty != _isTextEmpty) {
        setState(() => _isTextEmpty = isEmpty);
      }
      final selection = _messageCtrl.selection;
      
      if (!selection.isValid || selection.baseOffset == -1) return;

      final cursorPos = selection.baseOffset;
      final textBeforeCursor = text.substring(0, cursorPos);
      final lastAtSignIndex = textBeforeCursor.lastIndexOf('@');

      if (lastAtSignIndex != -1) {
        final textAfterAtSign = textBeforeCursor.substring(lastAtSignIndex + 1);
        if (!textAfterAtSign.contains(' ')) {
          setState(() {
            _showMentions = true;
            _mentionQuery = textAfterAtSign.toLowerCase();
            _mentionStartIndex = lastAtSignIndex;
          });
          return;
        }
      }
      
      if (_showMentions) {
        setState(() {
          _showMentions = false;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _gifSearchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final currentScroll = _scrollCtrl.position.pixels;
    final shouldShow = currentScroll > 100;
    if (shouldShow != _showScrollToBottom) {
      setState(() => _showScrollToBottom = shouldShow);
    }
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _scrollToBottom();
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _setReply(ChatMessage message) {
    setState(() {
      _replyingTo = message.id;
      _replyToName = message.senderName;
      _replyToContent = message.content;
    });
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
      _replyToName = null;
      _replyToContent = null;
    });
  }

  // Hardcoded working GIFs from Giphy public CDN — verified working URLs
  static const _defaultGifs = [
    'https://media.giphy.com/media/ZqlvCTNHpqrio/giphy.gif',
    'https://media.giphy.com/media/du3J3cXyzhj75IOgvA/giphy.gif',
    'https://media.giphy.com/media/3oEjI6SIIHBdRxXI40/giphy.gif',
    'https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/giphy.gif',
    'https://media.giphy.com/media/26ufdipQqU2lhNA4g/giphy.gif',
    'https://media.giphy.com/media/xT9IgG50Lg7rusyOqY/giphy.gif',
    'https://media.giphy.com/media/11sBLVxNs7v6WA/giphy.gif',
    'https://media.giphy.com/media/5GoVLqeAOo6PK/giphy.gif',
    'https://media.giphy.com/media/l3q2K5jinAlChoCLS/giphy.gif',
    'https://media.giphy.com/media/26BRuo6sLetdllPAQ/giphy.gif',
    'https://media.giphy.com/media/3oEdv9Y3FVGw5HKgGY/giphy.gif',
    'https://media.giphy.com/media/xT9IgDECMFdlRxetDO/giphy.gif',
  ];

  Future<void> _searchGifs(String query) async {
    if (query.trim().isEmpty || query == 'trending') {
      setState(() {
        _gifResults.clear();
        _gifResults.addAll(_defaultGifs.map((url) => {'url': url, 'preview': url}));
        _gifLoading = false;
      });
      return;
    }
    setState(() => _gifLoading = true);
    try {
      final uri = Uri.parse(
        'https://tenor.googleapis.com/v2/search?q=${Uri.encodeComponent(query)}&key=AIzaSyAyimkuYQYF_FXVql9aozqBPHzMKADCQNQ&limit=12&media_filter=gif',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = (data['results'] as List).map<Map<String, String>>((r) {
          final url = r['media_formats']?['gif']?['url'] as String? ?? '';
          final preview = r['media_formats']?['tinygif']?['url'] as String? ?? url;
          return {'url': url, 'preview': preview};
        }).where((m) => m['url']!.isNotEmpty).toList();
        if (results.isNotEmpty) {
          setState(() {
            _gifResults.clear();
            _gifResults.addAll(results);
          });
          setState(() => _gifLoading = false);
          return;
        }
      }
    } catch (_) {}
    setState(() {
      _gifResults.clear();
      _gifResults.addAll(_defaultGifs.map((url) => {'url': url, 'preview': url}));
      _gifLoading = false;
    });
  }

  Future<void> _sendGif(String gifUrl) async {
    final currentUser = ref.read(authProvider);
    if (currentUser == null) return;
    setState(() => _showGifPicker = false);
    final controller = ref.read(chatControllerProvider.notifier);
    await controller.sendMessage(
      senderId: currentUser.id,
      senderName: currentUser.fullName.isNotEmpty ? currentUser.fullName : currentUser.username,
      senderRole: currentUser.role,
      content: '',
      fileUrl: gifUrl,
      fileName: 'gif',
      fileType: 'gif',
      channel: _channelId,
    );
    _scrollToBottom();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: kIsWeb,
      );
      
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick file: $e')),
        );
      }
    }
  }

  void _cancelFileSelection() {
    setState(() {
      _selectedFile = null;
    });
  }

  Color _userColor(String name) {
    final colors = [
      AppColors.primary,
      AppColors.success,
      AppColors.warning,
      AppColors.error,
      AppColors.info,
    ];
    return colors[name.hashCode % colors.length];
  }

  Widget _buildMentionsList() {
    final agentsAsync = ref.watch(agentsListProvider);

    return agentsAsync.when(
      data: (agents) {
        final filteredAgents = agents.where((a) {
          final name = (a['full_name'] ?? a['username'] ?? '').toString().toLowerCase();
          final role = (a['role'] ?? '').toString().toLowerCase();
          return name.contains(_mentionQuery) || role.contains(_mentionQuery);
        }).toList()
          ..sort((a, b) {
            final nameA = (a['full_name'] ?? a['username'] ?? '').toString().toLowerCase();
            final nameB = (b['full_name'] ?? b['username'] ?? '').toString().toLowerCase();
            return nameA.compareTo(nameB);
          });

        if (filteredAgents.isEmpty) return const SizedBox.shrink();

        return Container(
          constraints: const BoxConstraints(maxHeight: 200),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: filteredAgents.length,
            itemBuilder: (context, index) {
              final agent = filteredAgents[index];
              final name = (agent['full_name'] ?? agent['username'] ?? '').toString();
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 12,
                  backgroundColor: _userColor(name).withValues(alpha: 0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 10,
                      color: _userColor(name),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                title: Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _userColor(name),
                  ),
                ),
                subtitle: Text(
                  (agent['role'] ?? '').toString(),
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () => _insertMention(name),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _insertMention(String name) {
    final text = _messageCtrl.text;
    final newText = text.replaceRange(
      _mentionStartIndex,
      _messageCtrl.selection.baseOffset,
      '@$name ',
    );

    _messageCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: _mentionStartIndex + name.length + 2,
      ),
    );

    setState(() {
      _showMentions = false;
    });

    _focusNode.requestFocus();
  }

  void _triggerMention() {
    final text = _messageCtrl.text;
    final selection = _messageCtrl.selection;
    
    int insertOffset = selection.baseOffset;
    if (insertOffset == -1) {
      insertOffset = text.length;
    }
    
    String prefix = '@';
    if (insertOffset > 0 && text[insertOffset - 1] != ' ') {
      prefix = ' @';
    }
    
    final newText = text.replaceRange(insertOffset, insertOffset, prefix);
    
    _messageCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: insertOffset + prefix.length),
    );
    
    setState(() {
      _showMentions = true;
      _mentionQuery = '';
      _mentionStartIndex = insertOffset + (prefix.length - 1);
    });
    
    _focusNode.requestFocus();
  }

  Future<void> _sendVoiceNote(String localPath, int durationSeconds) async {
    final currentUser = ref.read(authProvider);
    if (currentUser == null) return;

    final controller = ref.read(chatControllerProvider.notifier);
    
    await controller.sendVoiceMessage(
      senderId: currentUser.id,
      senderName: currentUser.fullName.isNotEmpty ? currentUser.fullName : currentUser.username,
      senderRole: currentUser.role,
      localAudioPath: localPath,
      durationSeconds: durationSeconds,
      channel: _channelId,
      replyToMessageId: _replyingTo,
      replyToSenderName: _replyToName,
      replyToContent: _replyToContent,
    );
    _scrollToBottom();
    _cancelReply();
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty && _selectedFile == null) return;

    final currentUser = ref.read(authProvider);
    if (currentUser == null) return;

    _messageCtrl.clear();
    _focusNode.requestFocus();

    String? fileUrl;
    String? fileName;
    String? fileType;

    // Upload file if selected
    if (_selectedFile != null) {
      setState(() => _isUploading = true);
      try {
        final supabase = Supabase.instance.client;
        final filePath = '${DateTime.now().millisecondsSinceEpoch}_${_selectedFile!.name}';
        
        Uint8List fileBytes;
        if (_selectedFile!.bytes != null) {
          fileBytes = Uint8List.fromList(_selectedFile!.bytes!);
        } else if (_selectedFile!.path != null) {
          fileBytes = await File(_selectedFile!.path!).readAsBytes();
        } else {
          throw Exception('No file bytes or path available');
        }
        
        await supabase.storage
            .from('chat_attachments')
            .uploadBinary(
              filePath, 
              fileBytes,
              fileOptions: FileOptions(
                contentType: _getMimeType(_selectedFile!.extension),
                upsert: false,
              ),
            );

        fileUrl = supabase.storage.from('chat_attachments').getPublicUrl(filePath);
        fileName = _selectedFile!.name;
        fileType = _selectedFile!.extension;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload file: $e')),
          );
        }
        setState(() => _isUploading = false);
        return;
      }
      setState(() {
        _selectedFile = null;
        _isUploading = false;
      });
    }

    final controller = ref.read(chatControllerProvider.notifier);
    await controller.sendMessage(
      senderId: currentUser.id,
      senderName: currentUser.fullName.isNotEmpty ? currentUser.fullName : currentUser.username,
      senderRole: currentUser.role,
      content: text,
      replyToMessageId: _replyingTo,
      replyToSenderName: _replyToName,
      replyToContent: _replyToContent,
      fileUrl: fileUrl,
      fileName: fileName,
      fileType: fileType,
      channel: _channelId,
    );

    setState(() {
      _replyingTo = null;
      _replyToName = null;
      _replyToContent = null;
    });

    _scrollToBottom();
  }

  Widget _buildDateDivider(DateTime date, BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(date.year, date.month, date.day);

    String dateText;
    if (msgDate == today) {
      dateText = 'Today';
    } else if (msgDate == yesterday) {
      dateText = 'Yesterday';
    } else {
      dateText = DateFormat('MMM d, yyyy').format(date);
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: context.isDarkMode 
              ? Colors.white.withValues(alpha: 0.1) 
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          dateText,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.isDarkMode 
                ? Colors.white70 
                : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  String _getMimeType(String? extension) {
    if (extension == null) return 'application/octet-stream';
    final ext = extension.toLowerCase();
    switch (ext) {
      case 'pdf': return 'application/pdf';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'gif': return 'image/gif';
      case 'webp': return 'image/webp';
      case 'mp4': return 'video/mp4';
      case 'mov': return 'video/quicktime';
      case 'avi': return 'video/x-msvideo';
      case 'mkv': return 'video/x-matroska';
      case 'webm': return 'video/webm';
      case 'mp3': return 'audio/mpeg';
      case 'wav': return 'audio/wav';
      case 'm4a': return 'audio/mp4';
      case 'ogg': return 'audio/ogg';
      case 'doc': return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls': return 'application/vnd.ms-excel';
      case 'xlsx': return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt': return 'application/vnd.ms-powerpoint';
      case 'pptx': return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt': return 'text/plain';
      case 'csv': return 'text/csv';
      case 'zip': return 'application/zip';
      case 'rar': return 'application/vnd.rar';
      case '7z': return 'application/x-7z-compressed';
      case 'tar': return 'application/x-tar';
      case 'apk': return 'application/vnd.android.package-archive';
      case 'exe': return 'application/x-msdownload';
      case 'dmg': return 'application/x-apple-diskimage';
      case 'json': return 'application/json';
      case 'xml': return 'application/xml';
      case 'html': return 'text/html';
      case 'svg': return 'image/svg+xml';
      default: return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatStreamProvider(_channelId));
    final currentUser = ref.watch(authProvider);

    ref.listen(chatStreamProvider(_channelId), (previous, next) {
      if (next is AsyncData<List<ChatMessage>> && next.value.isNotEmpty) {
        final previousCount = previous is AsyncData<List<ChatMessage>> ? previous.value.length : 0;
        final currentCount = next.value.length;
        if (currentCount > previousCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollCtrl.hasClients) {
              _scrollCtrl.jumpTo(0.0);
            }
          });
        }
      }
    });

    return Container(
      color: context.isDarkMode ? context.adaptiveBackground : const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (rawMessages) {
                var messages = rawMessages;
                const restrictedAgentIds = {
                  '0a5aeeb8-9544-4dc8-920f-e26c192b0dd3',
                  'f3b54de6-0372-4648-ad87-3e98089efc2d',
                };
                if (currentUser != null && restrictedAgentIds.contains(currentUser.id)) {
                  messages = rawMessages.where((m) => m.senderId == currentUser.id).toList();
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.hash,
                          size: 48,
                          color: AppColors.slate300,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No messages yet',
                          style: TextStyle(
                            color: AppColors.slate500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Text(
                          'Start the conversation!',
                          style: TextStyle(
                            color: AppColors.slate400,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final hasMore = ref.watch(chatStreamProvider('sales-team').notifier).hasMore;

                return Stack(
                    children: [
                      SelectionArea(
                        child: ListView.builder(
                          controller: _scrollCtrl,
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 60),
                        reverse: true,
                        itemCount: messages.length + (hasMore ? 1 : 0),
                        itemBuilder: (context, rawIndex) {
                          if (hasMore && rawIndex == messages.length) {
                            final isLoadingMore = ref.read(chatStreamProvider('sales-team').notifier).isLoadingMore;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: isLoadingMore
                                    ? SizedBox(
                                        width: 24, height: 24,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : TextButton(
                                        onPressed: () {
                                          ref.read(chatStreamProvider('sales-team').notifier).loadMoreMessages(limit: 10);
                                        },
                                        child: Text('Load earlier messages'),
                                      ),
                              ),
                            );
                          }

                          final index = messages.length - 1 - rawIndex;
                          final msg = messages[index];
                          final isMe = msg.senderId == currentUser?.id;
                          final prevMsg = index > 0 ? messages[index - 1] : null;
                          final showSender = prevMsg == null || prevMsg.senderId != msg.senderId;
                          final isDeleted = msg.isDeleted;

                          bool showDateDivider = false;
                          if (prevMsg == null) {
                            showDateDivider = true;
                          } else {
                            final prevDate = prevMsg.createdAt.toLocal();
                            final currDate = msg.createdAt.toLocal();
                            if (prevDate.year != currDate.year || prevDate.month != currDate.month || prevDate.day != currDate.day) {
                              showDateDivider = true;
                            }
                          }

                          Widget bubble = _ChatBubble(
                            message: msg,
                            isMe: isMe,
                            showSender: showSender,
                            isDeleted: isDeleted,
                            onReply: () => _setReply(msg),
                          );

                          if (showDateDivider) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildDateDivider(msg.createdAt.toLocal(), context),
                                bubble,
                              ],
                            );
                          }
                          return bubble;
                        },
                      ),
                      ),
                      if (_showScrollToBottom)
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: FloatingActionButton.small(
                            onPressed: _scrollToBottom,
                            backgroundColor: AppColors.primary,
                            child: const Icon(Icons.arrow_downward, color: Colors.white),
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                  child: Text('Error: $err'),
                ),
              ),
            ),
            // Reply preview
            if (_replyingTo != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.reply, size: 16, color: AppColors.slate500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Replying to $_replyToName',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _replyToContent ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: _cancelReply,
                    ),
                  ],
                ),
              ),
            // File preview
            if (_selectedFile != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  children: [
                    Icon(_getFileIcon(_selectedFile!.extension), size: 20, color: AppColors.slate500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedFile!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    if (_isUploading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: _cancelFileSelection,
                      ),
                  ],
                ),
              ),
            // Emoji picker panel
            if (_showEmojiPicker)
              Container(
                height: 220,
                color: context.isDarkMode ? context.adaptiveCard : Colors.white,
                padding: const EdgeInsets.all(8),
                child: GridView.count(
                  crossAxisCount: 10,
                  children: [
                    '😀','😂','😍','🥰','😎','🤔','😢','😡','🎉','🔥',
                    '👍','👎','❤️','💯','✅','🙏','😊','🤣','😅','😭',
                    '🤩','😏','😒','🤗','😤','🥺','😇','🤪','😜','🫡',
                    '👋','🙌','👏','🤝','✌️','🤞','💪','🫶','🫂','👀',
                    '🚀','⭐','🌟','💡','🎯','🏆','💎','🌈','🍕','☕',
                  ].map((e) => GestureDetector(
                    onTap: () {
                      _messageCtrl.text += e;
                      _messageCtrl.selection = TextSelection.collapsed(offset: _messageCtrl.text.length);
                    },
                    child: Center(
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  )).toList(),
                ),
              ),
            // GIF picker panel
            if (_showGifPicker)
              Container(
                height: 260,
                color: context.isDarkMode ? context.adaptiveCard : Colors.white,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextField(
                        controller: _gifSearchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Search GIFs...',
                          filled: true,
                          fillColor: context.isDarkMode ? context.adaptiveBackground : Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search, size: 18),
                            onPressed: () => _searchGifs(_gifSearchCtrl.text),
                          ),
                        ),
                        onSubmitted: _searchGifs,
                      ),
                    ),
                    Expanded(
                      child: _gifLoading
                          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                          : _gifResults.isEmpty
                              ? const Center(child: Text('Search for GIFs above', style: TextStyle(color: AppColors.slate400)))
                              : GridView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 4,
                                    mainAxisSpacing: 4,
                                    childAspectRatio: 1.5,
                                  ),
                                  itemCount: _gifResults.length,
                                  itemBuilder: (_, i) => GestureDetector(
                                    onTap: () => _sendGif(_gifResults[i]['url']!),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(
                                        _gifResults[i]['preview']!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200),
                                      ),
                                    ),
                                  ),
                                ),
                    ),
                  ],
                ),
              ),
            // Mentions List
            if (_showMentions) _buildMentionsList(),
            
            // Selected File Preview
            if (_selectedFile != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.isDarkMode ? context.adaptiveCard : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.isDarkMode ? context.adaptiveSlate800 : Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(_getFileIcon(_selectedFile!.extension), size: 32, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedFile!.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_selectedFile!.size > 0)
                            Text(
                              '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB',
                              style: TextStyle(fontSize: 12, color: context.adaptiveSlate500),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: context.adaptiveSlate500),
                      onPressed: () => setState(() => _selectedFile = null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            
            // Input area
            Container(
              padding: EdgeInsets.only(
                left: 8,
                right: 8,
                top: MediaQuery.sizeOf(context).width < 800 ? 8 : 8,
                bottom: MediaQuery.sizeOf(context).width < 800 ? 130 : 8, // padding to sit above floating nav
              ),
              decoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              child: SafeArea(
                bottom: false, // Don't double pad bottom
                child: Row(
                  children: [
                    // Attach file button
                    IconButton(
                      icon: Icon(Icons.add, color: context.adaptiveSlate500),
                      onPressed: _pickFile,
                      padding: const EdgeInsets.all(12),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.isDarkMode ? context.adaptiveCard : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: context.isDarkMode ? context.adaptiveSlate800 : AppColors.slate200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Focus(
                                onKeyEvent: (node, event) {
                                  if (event is KeyDownEvent &&
                                      event.logicalKey == LogicalKeyboardKey.enter) {
                                    if (HardwareKeyboard.instance.isShiftPressed) {
                                      return KeyEventResult.ignored; // Shift+Enter = newline
                                    } else {
                                      _sendMessage();
                                      return KeyEventResult.handled; // consume — no newline inserted
                                    }
                                  }
                                  return KeyEventResult.ignored;
                                },
                                child: TextField(
                                  controller: _messageCtrl,
                                  focusNode: _focusNode,
                                  maxLines: MediaQuery.sizeOf(context).width < 800 ? 1 : 5,
                                  minLines: 1,
                                  textInputAction: TextInputAction.newline,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: context.isDarkMode ? Colors.white : AppColors.slate900,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Type a message...',
                                    hintStyle: TextStyle(color: context.adaptiveSlate400, fontSize: 14),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: MediaQuery.sizeOf(context).width < 800 ? 0 : 12,
                                    ),
                                    prefixIconConstraints: const BoxConstraints(),
                                    prefixIcon: Padding(
                                      padding: const EdgeInsets.only(left: 12.0, right: 4.0),
                                      child: InkWell(
                                        onTap: () => setState(() {
                                          _showEmojiPicker = !_showEmojiPicker;
                                          if (_showEmojiPicker) _showGifPicker = false;
                                        }),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: Icon(
                                            Icons.emoji_emotions_outlined,
                                            color: _showEmojiPicker ? AppColors.primary : context.adaptiveSlate500,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                    suffixIconConstraints: const BoxConstraints(),
                                    suffixIcon: Padding(
                                      padding: const EdgeInsets.only(right: 12.0, left: 4.0),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InkWell(
                                            onTap: _triggerMention,
                                            borderRadius: BorderRadius.circular(12),
                                            child: Padding(
                                              padding: const EdgeInsets.all(4.0),
                                              child: Icon(Icons.alternate_email, color: context.adaptiveSlate500, size: 20),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          InkWell(
                                            onTap: () => setState(() {
                                              _showGifPicker = !_showGifPicker;
                                              if (_showGifPicker) {
                                                _showEmojiPicker = false;
                                                if (_gifResults.isEmpty) _searchGifs('trending');
                                              }
                                            }),
                                            borderRadius: BorderRadius.circular(12),
                                            child: Padding(
                                              padding: const EdgeInsets.all(4.0),
                                              child: Icon(
                                                Icons.movie_outlined,
                                                color: _showGifPicker ? AppColors.primary : context.adaptiveSlate500,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  onTap: () => setState(() {
                                    _showEmojiPicker = false;
                                    _showGifPicker = false;
                                  }),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Send button
                    if (_isRecordingVoice || (_isTextEmpty && _selectedFile == null && !_isUploading))
                      ChatVoiceRecorder(
                        key: const ValueKey('sales_chat_voice_recorder'),
                        disabled: _selectedFile != null || _isUploading,
                        onRecordComplete: (path, duration) => _sendVoiceNote(path, duration),
                        onRecordingStateChanged: (isRecording) {
                          setState(() => _isRecordingVoice = isRecording);
                        },
                      )
                    else
                      CircleAvatar(
                        backgroundColor: AppColors.primary,
                        radius: 20,
                        child: IconButton(
                          icon: const Icon(LucideIcons.send, color: Colors.white, size: 18),
                          onPressed: _sendMessage,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
  }
}

/// Derives a consistent, vibrant color from a sender's name string.
Color _senderColor(String name) {
  const colors = [
    Color(0xFF6366F1), // indigo
    Color(0xFF0EA5E9), // sky
    Color(0xFF10B981), // emerald
    Color(0xFFF59E0B), // amber
    Color(0xFFEF4444), // red
    Color(0xFF8B5CF6), // violet
    Color(0xFFEC4899), // pink
    Color(0xFF14B8A6), // teal
    Color(0xFFF97316), // orange
    Color(0xFF06B6D4), // cyan
    Color(0xFFA855F7), // purple
    Color(0xFF84CC16), // lime
  ];
  int hash = 0;
  for (final c in name.codeUnits) {
    hash = (hash * 31 + c) & 0x7FFFFFFF;
  }
  return colors[hash % colors.length];
}

class _ChatBubble extends ConsumerStatefulWidget {
  final ChatMessage message;
  final bool isMe;
  final bool showSender;
  final bool isDeleted;
  final VoidCallback onReply;

  const _ChatBubble({
    required this.message,
    required this.isMe,
    required this.showSender,
    required this.isDeleted,
    required this.onReply,
  });

  @override
  ConsumerState<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends ConsumerState<_ChatBubble> {
  bool _hovered = false;

  void _delete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This message will be marked as deleted for everyone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(chatControllerProvider.notifier).deleteMessage(
        widget.message.id,
        channel: widget.message.channel,
      );
    }
  }

  void _sendReaction(String emoji) {
    setState(() => _hovered = false);
    final currentUser = ref.read(authProvider);
    if (currentUser == null) return;
    ref.read(chatControllerProvider.notifier).toggleReaction(
      messageId: widget.message.id,
      userId: currentUser.id,
      emoji: emoji,
    );
  }

  void _showAllReactions(BuildContext context) {
    setState(() => _hovered = false);
    const all = [
      '👍','👎','❤️','😂','😮','😢','','',
      '👏','🎉','🙏','💯','✅','🤔','😊','🥰',
      '😎','🤩','😭','🤣','😅','🫡','💪','🚀',
      '⭐','🌟','💡','🎯','🏆','💎','🌈','🍕',
    ];
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
        child: SizedBox(
          width: 320,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Add Reaction',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: all.map((e) => GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _sendReaction(e);
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(e, style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                  )).toList(),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    
    final agentsAsync = ref.watch(agentsListProvider);
    final agents = agentsAsync.asData?.value ?? [];
    final agentData = agents.where((a) => a['id'] == message.senderId).firstOrNull;
    final currentSenderName = (agentData?['full_name']?.toString().isNotEmpty == true 
        ? agentData!['full_name'] 
        : agentData?['username']) ?? message.senderName;
        
    final isMe = widget.isMe;
    final showSender = widget.showSender;
    final isDeleted = widget.isDeleted;
    final nameColor = _senderColor(currentSenderName);
    final timeStr = "${message.createdAt.toLocal().hour}:${message.createdAt.toLocal().minute.toString().padLeft(2, '0')}";

    // Call activity messages — rendered as centered notification cards
    if (message.content.startsWith('__CALL_') && !isDeleted) {
      return _CallActivityCard(content: message.content, createdAt: message.createdAt);
    }

    // Lead creation messages — rendered as a live-status card
    if (message.content.startsWith('🎯 New Lead') && !isDeleted) {
      return _LeadChatCard(message: message, showSender: showSender);
    }

    return GestureDetector(
      onLongPress: () {
        final isMobile = MediaQuery.of(context).size.width < 900;
        if (isMobile) {
          setState(() => _hovered = true);
        }
      },
      onTap: () {
        final isMobile = MediaQuery.of(context).size.width < 900;
        if (isMobile && _hovered) {
          setState(() => _hovered = false);
        }
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
            // Constrain bubble to max 75% of available width
            ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Always show sender name
                    if (showSender)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          currentSenderName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: nameColor,
                          ),
                        ),
                      ),
                    // Bubble shrinks to content
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (message.replyToMessageId != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? (context.isDarkMode
                                            ? Colors.white.withValues(alpha: 0.15)
                                            : Colors.white)
                                      : (context.isDarkMode
                                            ? Colors.black.withValues(alpha: 0.2)
                                            : Colors.black.withValues(alpha: 0.04)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message.replyToSenderName ?? 'Unknown',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                        color: isMe
                                            ? (context.isDarkMode ? Colors.white.withValues(alpha: 0.9) : AppColors.primary)
                                            : AppColors.slate600,
                                      ),
                                    ),
                                    Text(
                                      message.replyToContent ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isMe
                                            ? (context.isDarkMode ? Colors.white70 : AppColors.primary.withValues(alpha: 0.8))
                                            : AppColors.slate500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // Message text + time on the same row
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Flexible(
                                  child: isDeleted
                                      ? Text(
                                          'This message was deleted',
                                          style: TextStyle(
                                            fontStyle: FontStyle.italic,
                                            color: AppColors.slate400,
                                          ),
                                        )
                                      : SelectableLinkify(
                                          text: message.content,
                                          onOpen: (link) async {
                                            final uri = Uri.parse(link.url);
                                            if (await url_launcher.canLaunchUrl(uri)) {
                                              await url_launcher.launchUrl(uri, mode: url_launcher.LaunchMode.externalApplication);
                                            }
                                          },
                                          style: TextStyle(
                                            color: isMe
                                                ? (context.isDarkMode ? Colors.white : AppColors.primary)
                                                : (context.isDarkMode ? Colors.white : AppColors.slate800),
                                            fontSize: 14,
                                          ),
                                          linkStyle: TextStyle(
                                            color: context.isDarkMode
                                                ? const Color(0xFF93C5FD)
                                                : const Color(0xFF1D4ED8),
                                            decoration: TextDecoration.underline,
                                            decorationColor: context.isDarkMode
                                                ? const Color(0xFF93C5FD)
                                                : const Color(0xFF1D4ED8),
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isMe
                                        ? (context.isDarkMode ? Colors.white60 : AppColors.primary.withValues(alpha: 0.6))
                                        : (context.isDarkMode ? Colors.white54 : AppColors.slate400),
                                  ),
                                ),
                              ],
                            ),
                            if (message.fileUrl != null && !isDeleted)
                              if (message.fileType?.toLowerCase() == 'gif')
                                // Render GIF as animated inline image
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    message.fileUrl!,
                                    width: 200,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (_, child, progress) => progress == null
                                        ? child
                                        : SizedBox(
                                            width: 200,
                                            height: 120,
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                value: progress.expectedTotalBytes != null
                                                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                                    : null,
                                              ),
                                            ),
                                          ),
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 200,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Center(child: Icon(Icons.gif, size: 32, color: AppColors.slate400)),
                                    ),
                                  ),
                                )
                               else if (['mp4', 'mov', 'avi', 'mkv'].contains(message.fileType?.toLowerCase()))
                                 Padding(
                                   padding: const EdgeInsets.only(top: 4),
                                   child: VideoMessageWidget(
                                     videoUrl: message.fileUrl!,
                                     fileName: message.fileName ?? 'video',
                                     onDownload: () => downloadFileDirectly(message.fileUrl!, message.fileName ?? 'video'),
                                   ),
                                 )
                               else
                                 GestureDetector(
                                  onTap: () async {
                                    final uri = Uri.parse(message.fileUrl!);
                                    try {
                                      await url_launcher.launchUrl(
                                        uri,
                                        mode: url_launcher.LaunchMode.externalApplication,
                                      );
                                    } catch (e) {
                                      debugPrint('Could not launch ${message.fileUrl}: $e');
                                    }
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(_getFileIcon(message.fileType),
                                            size: 16, color: AppColors.slate500),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            message.fileName ?? 'File',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(LucideIcons.download,
                                            size: 14, color: AppColors.slate500),
                                      ],
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    // Reaction badges below bubble
                    if (widget.message.reactions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: () {
                            final grouped = <String, int>{};
                            for (final r in widget.message.reactions) {
                              final e = r['emoji'] as String? ?? '';
                              if (e.isNotEmpty) grouped[e] = (grouped[e] ?? 0) + 1;
                            }
                            return grouped.entries.map((entry) => GestureDetector(
                              onTap: () => _sendReaction(entry.key),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 3)],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(entry.key, style: const TextStyle(fontSize: 13)),
                                    const SizedBox(width: 3),
                                    Text('${entry.value}', style: const TextStyle(fontSize: 11, color: AppColors.slate600, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            )).toList();
                          }(),
                        ),
                      ),
                  ],
                ),
              ), // Add comma here to separate ConstrainedBox and Positioned
            // Hover action bar
            if (!isDeleted)
              Positioned(
                right: -4,
                bottom: 20,
                child: IgnorePointer(
                  ignoring: !_hovered,
                  child: AnimatedOpacity(
                    opacity: _hovered ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: PopupMenuButton<String>(
                      position: PopupMenuPosition.under,
                      icon: Container(
                        decoration: BoxDecoration(
                          color: context.isDarkMode ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                          color: context.isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      splashRadius: 16,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: context.isDarkMode ? Colors.grey[800]! : Colors.grey[300]!, width: 1),
                      ),
                      color: context.isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                      surfaceTintColor: Colors.transparent,
                      elevation: 8,
                      itemBuilder: (menuCtx) => [
                        // Reactions
                        PopupMenuItem<String>(
                          value: 'reactions',
                          enabled: true,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Wrap(
                            alignment: WrapAlignment.spaceEvenly,
                            spacing: 2,
                            runSpacing: 4,
                            children: [
                              for (final emoji in ['👍', '❤️', '😂', '😮', '😢', '🙏'])
                                Tooltip(
                                  message: emoji,
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.of(menuCtx).pop();
                                      _sendReaction(emoji);
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Text(emoji, style: const TextStyle(fontSize: 22)),
                                    ),
                                  ),
                                ),
                              Tooltip(
                                message: 'More',
                                child: InkWell(
                                  onTap: () {
                                    Navigator.of(menuCtx).pop();
                                    _showAllReactions(context);
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(Icons.add_reaction_outlined, size: 22, color: context.isDarkMode ? Colors.grey[400] : Colors.grey[700]),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem<String>(
                          value: 'reply',
                          onTap: widget.onReply,
                          child: Row(
                            children: [
                              Icon(Icons.reply, size: 20, color: context.isDarkMode ? Colors.white70 : Colors.black87),
                              const SizedBox(width: 12),
                              Text('Reply', style: TextStyle(color: context.isDarkMode ? Colors.white70 : Colors.black87)),
                            ],
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'copy',
                          onTap: () async {
                            try {
                              await Clipboard.setData(ClipboardData(text: message.content));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                              }
                            } catch (e) {}
                          },
                          child: Row(
                            children: [
                              Icon(Icons.copy, size: 20, color: context.isDarkMode ? Colors.white70 : Colors.black87),
                              const SizedBox(width: 12),
                              Text('Copy', style: TextStyle(color: context.isDarkMode ? Colors.white70 : Colors.black87)),
                            ],
                          ),
                        ),
                        if (isMe)
                          PopupMenuItem<String>(
                            value: 'delete',
                            onTap: () {
                              Future.delayed(const Duration(milliseconds: 100), () {
                                if (context.mounted) {
                                  _delete(context);
                                }
                              });
                            },
                            child: const Row(
                              children: [
                                Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                SizedBox(width: 12),
                                Text('Delete', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  const _ActionBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: color ?? AppColors.slate500),
        ),
      ),
    );
  }
}

// ── Call Activity Card ────────────────────────────────────────────────────────
class _CallActivityCard extends StatelessWidget {
  final String content;
  final DateTime createdAt;

  const _CallActivityCard({required this.content, required this.createdAt});

  @override
  Widget build(BuildContext context) {
    final info = _parseCallContent(content);
    final timeStr = DateFormat('h:mm a').format(createdAt.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: info.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: info.color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(info.icon, size: 16, color: info.color),
              const SizedBox(width: 8),
              Text(
                info.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: info.color,
                ),
              ),
              if (info.duration != null) ...[
                Text(
                  ' · ${info.duration}',
                  style: TextStyle(fontSize: 12, color: info.color.withValues(alpha: 0.7)),
                ),
              ],
              const SizedBox(width: 10),
              Text(
                timeStr,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static _CallInfo _parseCallContent(String content) {
    final isVideo = content.contains('_VIDEO_');
    String? duration;
    final colonIdx = content.lastIndexOf(':');
    if (colonIdx != -1 && colonIdx < content.length - 1 && !content.substring(colonIdx + 1).startsWith('//')) {
      duration = content.substring(colonIdx + 1).trim();
      if (duration.isEmpty) duration = null;
    }
    if (content.contains('_MISSED__')) {
      return _CallInfo(icon: isVideo ? LucideIcons.videoOff : LucideIcons.phoneOff, label: isVideo ? 'Missed Video Call' : 'Missed Audio Call', color: Colors.red.shade600, duration: duration);
    } else if (content.contains('_ENDED__')) {
      return _CallInfo(icon: isVideo ? LucideIcons.video : LucideIcons.phone, label: isVideo ? 'Video Call Ended' : 'Audio Call Ended', color: Colors.grey.shade600, duration: duration);
    } else if (content.contains('_ONGOING__')) {
      return _CallInfo(icon: isVideo ? LucideIcons.video : LucideIcons.phone, label: isVideo ? 'Video Call Ongoing' : 'Audio Call Ongoing', color: Colors.green.shade600, duration: duration);
    } else {
      return _CallInfo(icon: isVideo ? LucideIcons.video : LucideIcons.phone, label: isVideo ? 'Video Call Started' : 'You were in a huddle', color: const Color(0xFF2563EB), duration: duration);
    }
  }
}

class _CallInfo {
  final IconData icon;
  final String label;
  final Color color;
  final String? duration;
  const _CallInfo({required this.icon, required this.label, required this.color, this.duration});
}

// ── Lead Chat Card ─────────────────────────────────────────────────────────────
// Parses a "🎯 New Lead" message and renders a rich card with live pipeline status.
class _LeadChatCard extends ConsumerWidget {
  final ChatMessage message;
  final bool showSender;

  const _LeadChatCard({required this.message, required this.showSender});

  // Extract [LeadID:uuid] tag from message content
  static String? _extractLeadId(String content) {
    final match = RegExp(r'\[LeadID:([^\]]+)\]').firstMatch(content);
    return match?.group(1);
  }

  // Remove the hidden tag from display text
  static String _displayContent(String content) {
    return content.replaceAll(RegExp(r'\[LeadID:[^\]]+\]\n?'), '').trim();
  }

  // Parse lines like "Company: Acme" into a map
  static Map<String, String> _parseLines(String content) {
    final map = <String, String>{};
    for (final line in content.split('\n')) {
      final idx = line.indexOf(':');
      if (idx > 0) {
        final key = line.substring(0, idx).trim();
        final val = line.substring(idx + 1).trim();
        if (key.isNotEmpty && val.isNotEmpty) map[key] = val;
      }
    }
    return map;
  }

  static Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new lead':
      case 'new':
      case 'pending':
        return Colors.orange;
      case 'contacted':
        return Colors.blue;
      case 'qualified':
        return Colors.cyan;
      case 'proposal':
        return Colors.purple;
      case 'negotiation':
        return Colors.deepOrange;
      case 'won':
      case 'win':
        return Colors.green;
      case 'lost':
      case 'loss':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  static String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'new':
      case 'pending':
        return 'New Lead';
      case 'win':
        return 'Won';
      case 'loss':
        return 'Lost';
      default:
        // Capitalise first letter of each word
        return status.split(' ').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.isDarkMode;
    final timeStr = DateFormat('h:mm a').format(message.createdAt.toLocal());

    final leadId = _extractLeadId(message.content);
    final displayText = _displayContent(message.content);
    final lines = _parseLines(displayText);

    final companyName = lines['Company'] ?? '';
    final customerName = lines['Customer'];
    final phone = lines['Phone'] ?? '';
    final source = lines['Source'];
    final product = lines['Product'];
    final owner = lines['Owner'] ?? '';

    // Look up live status from leadsProvider if we have a lead ID
    String liveStatus = lines['Status'] ?? 'New Lead';
    if (leadId != null) {
      final leadsAsync = ref.watch(leadsProvider);
      leadsAsync.whenData((leads) {
        for (final l in leads) {
          if (l.id == leadId) {
            liveStatus = l.status;
            break;
          }
        }
      });
      // Use a local variable so we can use it in build (whenData is side-effect only)
      final leads = leadsAsync.asData?.value ?? [];
      for (final l in leads) {
        if (l.id == leadId) {
          liveStatus = l.status;
          break;
        }
      }
    }

    final statusColor = _statusColor(liveStatus);
    final statusLabel = _statusLabel(liveStatus);

    final cardBg = isDark ? const Color(0xFF1E2D3D) : const Color(0xFFF0F7FF);
    final borderColor = isDark ? Colors.blue.shade800 : Colors.blue.shade100;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
            minWidth: 220,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showSender)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 2),
                  child: Text(
                    message.senderName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: _senderColor(message.senderName),
                    ),
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: isDark ? 0.08 : 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blue.shade900.withValues(alpha: 0.5) : Colors.blue.shade50,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                      ),
                      child: Row(
                        children: [
                          const Text('🎯', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'New Lead',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: isDark ? Colors.blue.shade200 : Colors.blue.shade800,
                              ),
                            ),
                          ),
                          // Live status badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Body
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Company name
                          Text(
                            companyName,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: isDark ? Colors.white : AppColors.slate900,
                            ),
                          ),
                          if (customerName != null && customerName.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              customerName,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white70 : AppColors.slate600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          // Info rows
                          _InfoRow(icon: LucideIcons.phone, text: phone, isDark: isDark),
                          if (product != null && product.isNotEmpty)
                            _InfoRow(icon: LucideIcons.box, text: product, isDark: isDark),
                          if (source != null && source.isNotEmpty)
                            _InfoRow(icon: LucideIcons.globe, text: source, isDark: isDark),
                          _InfoRow(icon: LucideIcons.user, text: owner, isDark: isDark),
                          // Timestamp
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.white38 : AppColors.slate400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;
  const _InfoRow({required this.icon, required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: isDark ? Colors.white54 : AppColors.slate400),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : AppColors.slate700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

