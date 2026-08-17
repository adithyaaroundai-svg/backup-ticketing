import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../../data/repositories/chat_repository.dart';
import '../../../../core/utils/download_helper.dart';
import '../../domain/entities/chat_message.dart';
import '../../../tickets/presentation/providers/ticket_provider.dart';
import '../widgets/chat_voice_recorder.dart';
import '../widgets/video_message_widget.dart';
import '../widgets/chat_drop_overlay.dart';
import '../../../../core/services/chat_drag_drop_paste_helper.dart';

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

Future<void> _downloadFile(String url, String fileName) async {
  await downloadFileDirectly(url, fileName);
}

class AllAroundTallyChatPage extends ConsumerStatefulWidget {
  const AllAroundTallyChatPage({super.key});

  @override
  ConsumerState<AllAroundTallyChatPage> createState() => _AllAroundTallyChatPageState();
}

class _AllAroundTallyChatPageState extends ConsumerState<AllAroundTallyChatPage> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();

  bool _showScrollToBottom = false;
  String? _replyingTo;
  String? _replyToName;
  String? _replyToContent;

  // File attachment state
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  bool _isDragging = false;
  ChatDragDropPasteSubscription? _dragDropPasteSub;

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

    _ctrl.addListener(() {
      final text = _ctrl.text;
      final isEmpty = text.trim().isEmpty;
      if (isEmpty != _isTextEmpty) {
        setState(() => _isTextEmpty = isEmpty);
      }
      final selection = _ctrl.selection;
      
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

    _dragDropPasteSub = registerChatDragDropAndPaste(
      onFileReceived: (file) {
        if (!mounted) return;
        setState(() {
          _selectedFile = file;
        });
        _focusNode.requestFocus();
      },
      onDragStateChanged: (isDragging) {
        if (!mounted) return;
        if (_isDragging != isDragging) {
          setState(() => _isDragging = isDragging);
        }
      },
    );
  }

  DateTime? _lastMarkedReadAt;

  @override
  void dispose() {
    _dragDropPasteSub?.cancel();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _gifSearchCtrl.dispose();
    super.dispose();
  }

  void _markVisibleMessagesRead(List<ChatMessage> messages) {
    if (messages.isEmpty) return;

    final validMessages = messages.where((m) => !m.id.startsWith('temp_')).toList();
    if (validMessages.isEmpty) return;

    final newestMessageAt = validMessages.last.createdAt.toUtc();

    if (_lastMarkedReadAt != null &&
        !newestMessageAt.isAfter(_lastMarkedReadAt!)) {
      return;
    }

    _lastMarkedReadAt = newestMessageAt;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ref
          .read(allAroundTallyUnreadCountProvider.notifier)
          .markAsRead(timestamp: newestMessageAt);
    });
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final currentScroll = _scrollCtrl.position.pixels;
    final shouldShow = currentScroll > 100;
    if (shouldShow != _showScrollToBottom) {
      setState(() => _showScrollToBottom = shouldShow);
    }

    final maxScroll = _scrollCtrl.position.maxScrollExtent;
    if (maxScroll > 0 && currentScroll >= maxScroll - 200) {
      final notifier = ref.read(chatStreamProvider('all-aroundtally').notifier);
      if (notifier.hasMore && !notifier.isLoadingMore) {
        notifier.loadMore();
      }
    }
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _scrollToBottom();
      });
    }
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
      channel: 'all-aroundtally',
      replyToMessageId: _replyingTo,
      replyToSenderName: _replyToName,
      replyToContent: _replyToContent,
    );
    _scrollToBottom();
    _cancelReply();
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
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

  Future<void> _sendMessage() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty && _selectedFile == null) return;

    final currentUser = ref.read(authProvider);
    if (currentUser == null) return;

    _ctrl.clear();
    _focusNode.unfocus();

    String? fileUrl;
    String? fileName;
    String? fileType;

    // Upload file if selected
    if (_selectedFile != null) {
      setState(() => _isUploading = true);
      try {
        final supabase = Supabase.instance.client;
        final filePath = '${currentUser.id}/${DateTime.now().millisecondsSinceEpoch}_${_selectedFile!.name}';
        
        if (kIsWeb && _selectedFile!.bytes != null) {
          await supabase.storage
              .from('chat_attachments')
              .uploadBinary(filePath, _selectedFile!.bytes!);
        } else if (_selectedFile!.path != null) {
          final file = File(_selectedFile!.path!);
          await supabase.storage
              .from('chat_attachments')
              .upload(filePath, file);
        }

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
      channel: 'all-aroundtally',
    );

    setState(() {
      _replyingTo = null;
      _replyToName = null;
      _replyToContent = null;
    });

    _scrollToBottom();
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
    // For 'trending' or empty — load defaults instantly
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
      // Try Tenor v2
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
    // Fallback: filter defaults by query keyword
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
      channel: 'all-aroundtally',
    );
    _scrollToBottom();
  }

  // ignore: unused_element
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
    final text = _ctrl.text;
    final newText = text.replaceRange(
      _mentionStartIndex,
      _ctrl.selection.baseOffset,
      '@$name ',
    );

    _ctrl.value = TextEditingValue(
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
    final text = _ctrl.text;
    final selection = _ctrl.selection;
    
    int insertOffset = selection.baseOffset;
    if (insertOffset == -1) {
      insertOffset = text.length;
    }
    
    String prefix = '@';
    if (insertOffset > 0 && text[insertOffset - 1] != ' ') {
      prefix = ' @';
    }
    
    final newText = text.replaceRange(insertOffset, insertOffset, prefix);
    
    _ctrl.value = TextEditingValue(
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

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatStreamProvider('all-aroundtally'));
    final currentUser = ref.watch(authProvider);

    ref.listen(chatStreamProvider('all-aroundtally'), (previous, next) {
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
        _markVisibleMessagesRead(next.value);
      }
    });

    return MainLayout(
      currentPath: '/channel/all-aroundtally',
      child: Scaffold(
        backgroundColor: context.isDarkMode ? context.adaptiveBackground : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'All AroundTally',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                'Company-wide channel',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,

        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: messagesAsync.when(
                data: (messages) {
                  _markVisibleMessagesRead(messages);
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
                            'Start the conversation with your team!',
                            style: TextStyle(
                              color: AppColors.slate400,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Stack(
                    children: [
                      Builder(
                        builder: (context) {
                          _markVisibleMessagesRead(messages);
                          final hasMore = ref.watch(chatStreamProvider('all-aroundtally').notifier).hasMore;
                          return SelectionArea(
                            child: ListView.builder(
                              controller: _scrollCtrl,
                            padding: const EdgeInsets.all(16),
                        reverse: true,
                        itemCount: messages.length + (hasMore ? 1 : 0),
                        itemBuilder: (context, rawIndex) {
                          if (hasMore && rawIndex == messages.length) {
                            final isLoadingMore = ref.read(chatStreamProvider('all-aroundtally').notifier).isLoadingMore;
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
                                          ref.read(chatStreamProvider('all-aroundtally').notifier).loadMoreMessages(limit: 10);
                                        },
                                        child: Text('Load earlier messages'),
                                      ),
                              ),
                            );
                          }
                          final index = messages.length - 1 - rawIndex;
                          final msg = messages[index];
                          final isMe = msg.senderId == currentUser?.id;
                          
                          bool showDateHeader = false;
                          if (index == 0) {
                            showDateHeader = true;
                          } else {
                            final prevMsg = messages[index - 1];
                            if (!_isSameDay(msg.createdAt, prevMsg.createdAt)) {
                              showDateHeader = true;
                            }
                          }
                          
                          bool showSender = true;
                          if (!showDateHeader && index > 0) {
                            final prevMsg = messages[index - 1];
                            if (prevMsg.senderId == msg.senderId) {
                              showSender = false;
                            }
                          }
                          
                          final isDeleted = msg.isDeleted;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (showDateHeader) _DateHeader(date: msg.createdAt),
                              _ChatBubble(
                                message: msg,
                                isMe: isMe,
                                showSender: showSender,
                                isDeleted: isDeleted,
                                onReply: () => _setReply(msg),
                              ),
                            ],
                          );
                        },
                      ),
                      );
                    },
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
                      _ctrl.text += e;
                      _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
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
                    if (_selectedFile!.bytes != null &&
                        ['png', 'jpg', 'jpeg', 'webp', 'gif'].contains((_selectedFile!.extension ?? '').toLowerCase()))
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          _selectedFile!.bytes!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
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
              padding: EdgeInsets.symmetric(
                horizontal: 8,
                vertical: MediaQuery.sizeOf(context).width < 800 ? 0 : 8,
              ),
              decoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              child: SafeArea(
                child: Row(
                  children: [
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
                  child: KeyboardListener(
                                focusNode: FocusNode(),
                                onKeyEvent: (event) {
                                  if (event is KeyDownEvent &&
                                      event.logicalKey == LogicalKeyboardKey.enter &&
                                      !HardwareKeyboard.instance.isShiftPressed) {
                                    _sendMessage();
                                  }
                                },
                                child: TextField(
                                  controller: _ctrl,
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
                        key: const ValueKey('all_aroundtally_chat_voice_recorder'),
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
        ChatDropOverlay(isVisible: _isDragging),
      ],
    ),
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
      '👍','👎','❤️','😂','😮','😢','�','�',
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
    final timeStr = DateFormat('h:mm a').format(message.createdAt.toLocal());

    // Call activity messages — rendered as centered notification cards
    if (message.content.startsWith('__CALL_') && !isDeleted) {
      return _CallActivityCard(content: message.content, createdAt: message.createdAt);
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
                    IntrinsicWidth(
                      child: Container(
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
                                    color: isMe
                                        ? (context.isDarkMode ? Colors.white60 : AppColors.primary.withValues(alpha: 0.6))
                                        : (context.isDarkMode ? Colors.white54 : AppColors.slate400),
                                  ),
                                ),
                                if (isMe && !isDeleted) ...[
                                  const SizedBox(width: 4),
                                  Builder(
                                    builder: (context) {
                                      final readBy = ReadReceiptsTracker.getReadBy(message.id);
                                      final isRead = readBy.any((id) => id != message.senderId.trim().toLowerCase());
                                      return Icon(
                                        isRead ? LucideIcons.checkCheck : LucideIcons.check,
                                        size: 13,
                                        color: isRead
                                            ? (context.isDarkMode ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
                                            : (context.isDarkMode ? Colors.white60 : AppColors.primary.withValues(alpha: 0.6)),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                            if (message.fileUrl != null && !isDeleted)
                              if (message.fileType?.toLowerCase() == 'gif' || ['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(message.fileType?.toLowerCase()) || (message.fileName?.toLowerCase().endsWith('.jpg') == true) || (message.fileName?.toLowerCase().endsWith('.png') == true) || (message.fileName?.toLowerCase().endsWith('.jpeg') == true))
                                // Render image/gif
                                GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      barrierColor: Colors.black.withValues(alpha: 0.65),
                                      builder: (ctx) {
                                        final screenSize = MediaQuery.sizeOf(ctx);
                                        final maxW = screenSize.width < 700
                                            ? screenSize.width * 0.96
                                            : (screenSize.width * 0.90).clamp(600.0, 1280.0);
                                        final maxH = screenSize.height < 700
                                            ? screenSize.height * 0.94
                                            : (screenSize.height * 0.88).clamp(600.0, 920.0);

                                        return GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () => Navigator.of(ctx).pop(),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: Center(
                                              child: GestureDetector(
                                                onTap: () {},
                                                child: Container(
                                                  width: maxW,
                                                  height: maxH,
                                                  margin: const EdgeInsets.all(24),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF0F172A),
                                                    borderRadius: BorderRadius.circular(16),
                                                    border: Border.all(
                                                      color: Colors.white.withValues(alpha: 0.15),
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black.withValues(alpha: 0.5),
                                                        blurRadius: 24,
                                                        offset: const Offset(0, 8),
                                                      ),
                                                    ],
                                                  ),
                                                  clipBehavior: Clip.antiAlias,
                                                  child: Column(
                                                    children: [
                                                      // Header bar
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                          vertical: 10,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFF1E293B),
                                                          border: Border(
                                                            bottom: BorderSide(
                                                              color: Colors.white.withValues(alpha: 0.08),
                                                            ),
                                                          ),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            const Icon(
                                                              Icons.image,
                                                              size: 18,
                                                              color: AppColors.primary,
                                                            ),
                                                            const SizedBox(width: 10),
                                                            Expanded(
                                                              child: Text(
                                                                message.fileName ?? 'Image Preview',
                                                                style: const TextStyle(
                                                                  color: Colors.white,
                                                                  fontSize: 13,
                                                                  fontWeight: FontWeight.w600,
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                            IconButton(
                                                              icon: const Icon(
                                                                Icons.download,
                                                                color: Colors.white70,
                                                                size: 20,
                                                              ),
                                                              tooltip: 'Download',
                                                              constraints: const BoxConstraints(),
                                                              padding: const EdgeInsets.all(6),
                                                              onPressed: () => _downloadFile(
                                                                message.fileUrl!,
                                                                message.fileName ?? 'image',
                                                              ),
                                                            ),
                                                            const SizedBox(width: 8),
                                                            IconButton(
                                                              icon: const Icon(
                                                                Icons.close,
                                                                color: Colors.white70,
                                                                size: 20,
                                                              ),
                                                              tooltip: 'Close',
                                                              constraints: const BoxConstraints(),
                                                              padding: const EdgeInsets.all(6),
                                                              onPressed: () => Navigator.of(ctx).pop(),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      // Image body
                                                      Expanded(
                                                        child: Container(
                                                          color: const Color(0xFF090D16),
                                                          padding: const EdgeInsets.all(12),
                                                          child: Center(
                                                            child: InteractiveViewer(
                                                              panEnabled: true,
                                                              minScale: 0.5,
                                                              maxScale: 4.0,
                                                              child: Image.network(
                                                                message.fileUrl!,
                                                                fit: BoxFit.contain,
                                                                loadingBuilder: (_, child, progress) =>
                                                                    progress == null
                                                                        ? child
                                                                        : const Center(
                                                                            child: CircularProgressIndicator(
                                                                              strokeWidth: 2,
                                                                              valueColor:
                                                                                  AlwaysStoppedAnimation<Color>(
                                                                                Colors.white70,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                errorBuilder: (_, __, ___) => const Center(
                                                                  child: Column(
                                                                    mainAxisSize: MainAxisSize.min,
                                                                    children: [
                                                                      Icon(
                                                                        Icons.broken_image,
                                                                        color: Colors.white38,
                                                                        size: 48,
                                                                      ),
                                                                      SizedBox(height: 8),
                                                                      Text(
                                                                        'Failed to load image',
                                                                        style: TextStyle(
                                                                          color: Colors.white54,
                                                                          fontSize: 13,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  child: ClipRRect(
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
                                        child: const Center(child: Icon(Icons.image_not_supported, size: 32, color: AppColors.slate400)),
                                      ),
                                    ),
                                  ),
                                )
                              else if (['mp4', 'mov', 'avi', 'mkv'].contains(message.fileType?.toLowerCase()))
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: VideoMessageWidget(
                                    videoUrl: message.fileUrl!,
                                    fileName: message.fileName ?? 'video',
                                    onDownload: () => _downloadFile(message.fileUrl!, message.fileName ?? 'video'),
                                  ),
                                )
                              else
                                GestureDetector(
                                  onTap: () => _downloadFile(
                                      message.fileUrl!, message.fileName ?? 'file'),
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
              ),
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

class _DateHeader extends StatelessWidget {
  final DateTime date;

  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    String text;
    final now = DateTime.now();

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      text = 'Today';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      text = 'Yesterday';
    } else {
      text = DateFormat('MMMM d, y').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.slate200)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.slate500,
              ),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.slate200)),
        ],
      ),
    );
  }
}

