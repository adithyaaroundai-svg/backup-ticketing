import os

files = [
    'lib/features/chat/presentation/pages/global_chat_page.dart',
    'lib/features/chat/presentation/pages/direct_message_page.dart'
]

methods = '''
  Widget _buildReactionButton({
    required String emoji,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(emoji, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }

  Widget _buildMoreReactionsButton({
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(Icons.add, size: 16, color: Colors.grey),
        ),
      ),
    );
  }
  
  @override
'''

for file in files:
    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()

    # We can just replace "@override\n  Widget build(BuildContext context) {" 
    # with the methods + "@override\n  Widget build(BuildContext context) {"
    
    # only if we haven't already inserted them
    if '_buildReactionButton' not in content:
        content = content.replace(
            '@override\n  Widget build(BuildContext context) {',
            methods + '  Widget build(BuildContext context) {'
        )
    
        with open(file, 'w', encoding='utf-8') as f:
            f.write(content)
            
print('Added missing methods!')
