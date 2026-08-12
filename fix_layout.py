import re

def process_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Remove the Positioned reaction menu from the message bubble Stack
    content = re.sub(
        r'Positioned\(\s*top:\s*-36,\s*right:\s*(isMe\s*\?\s*0\s*:\s*null|0),\s*left:\s*isMe\s*\?\s*null\s*:\s*0,\s*child:\s*Container\(\s*padding:\s*const\s*EdgeInsets\.only\(bottom:\s*24\),\s*color:\s*Colors\.transparent,\s*child:\s*const\s*_HoverableActionMenu\(\),\s*\)\s*\),',
        '',
        content
    )
    # Also handle the original version if the bridge script failed or didn't run on it
    content = re.sub(
        r'Positioned\(\s*top:\s*-36,\s*right:\s*(isMe\s*\?\s*0\s*:\s*null|0),\s*left:\s*isMe\s*\?\s*null\s*:\s*0,\s*child:\s*const\s*_HoverableActionMenu\(\)\s*\),',
        '',
        content
    )

    # 2. Update _HoverableMessageRow build method
    # Find the child: widget.child inside _HoverableActionMenuContext
    old_build = '''        child: _HoverableActionMenuContext(
          isMe: widget.isMe,
          onReply: widget.onReply,
          onDelete: widget.onDelete,
          onAddReaction: (context, reaction, messageId) =>
              _addReaction(context, reaction, messageId),
          onShowMoreReactions: (context, messageId) =>
              _showMoreReactions(context, messageId),
          onHandleStarMessage: (context, messageId) =>
              _handleStarMessage(context, messageId),
          isHovering: _isHovering,
          messageId: widget.message.id,
          messageContent: widget.message.content,
          child: widget.child,
        ),'''
        
    new_build = '''        child: _HoverableActionMenuContext(
          isMe: widget.isMe,
          onReply: widget.onReply,
          onDelete: widget.onDelete,
          onAddReaction: (context, reaction, messageId) =>
              _addReaction(context, reaction, messageId),
          onShowMoreReactions: (context, messageId) =>
              _showMoreReactions(context, messageId),
          onHandleStarMessage: (context, messageId) =>
              _handleStarMessage(context, messageId),
          isHovering: _isHovering,
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
        ),'''
        
    content = content.replace(old_build, new_build)

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

process_file('lib/features/chat/presentation/pages/global_chat_page.dart')
process_file('lib/features/chat/presentation/pages/direct_message_page.dart')
print('Updated both pages!')
