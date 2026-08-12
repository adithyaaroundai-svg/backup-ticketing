import os

files = [
    'lib/features/chat/presentation/pages/global_chat_page.dart',
    'lib/features/chat/presentation/pages/direct_message_page.dart'
]

old_text = '''                        // Message content with ticket handling
                        _buildSlackStyleMessageContent(context, ref),

                        // File attachment display
                        ChatAttachmentRenderer(
                          message: message,
                          isMe: isMe,
                        ),

                        const SizedBox(height: 6),

                        // Reactions display
                        if (message.reactions.isNotEmpty)
                          _buildReactionsDisplay(context, ref),
                      ],
                    ),
                    Positioned(
                      top: -12,
                      right: isMe ? null : 0,
                      left: isMe ? 0 : null,
                      child: const _HoverableActionMenu(),
                    ),
                  ],
                ),'''

new_text = '''                        // We wrap the bubble and attachments in a Stack
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                // Message content with ticket handling
                                _buildSlackStyleMessageContent(context, ref),

                                // File attachment display
                                ChatAttachmentRenderer(
                                  message: message,
                                  isMe: isMe,
                                ),
                              ],
                            ),
                            // Chevron positioned inside the bubble
                            Positioned(
                              bottom: 4,
                              right: isMe ? 4 : null,
                              left: isMe ? null : 4,
                              child: const _HoverableActionMenu(),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Reactions display
                        if (message.reactions.isNotEmpty)
                          _buildReactionsDisplay(context, ref),
                      ],
                    ),
                  ],
                ),'''

for file in files:
    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()

    # global_chat_page might have different spaces or wording
    if old_text in content:
        content = content.replace(old_text, new_text)
        print(f'Replaced in {file}')
    else:
        print(f'Could not find exact match in {file}')
        
    with open(file, 'w', encoding='utf-8') as f:
        f.write(content)
