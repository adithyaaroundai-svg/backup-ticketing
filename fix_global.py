import re

file_path = 'lib/features/chat/presentation/pages/global_chat_page.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = re.sub(
    r'isHovering:\s*_isHovering,\s*messageId:\s*widget\.message\.id,\s*messageContent:\s*widget\.message\.content,\s*child:\s*widget\.child,\s*\)',
    '''isHovering: _isHovering,
          messageId: widget.message.id,
          messageContent: widget.message.content,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (widget.isMe && _isHovering) const Padding(padding: EdgeInsets.only(right: 8), child: _HoverableActionMenu()),
              Flexible(child: widget.child),
              if (!widget.isMe && _isHovering) const Padding(padding: EdgeInsets.only(left: 8), child: _HoverableActionMenu()),
            ]
          )
        )''',
    content
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Updated global_chat_page.dart')
