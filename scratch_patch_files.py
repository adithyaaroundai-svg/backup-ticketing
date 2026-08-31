import os
import re

files_to_update = [
    r"c:\Users\admin\Desktop\crm -ticketting\ticketing_host_new\ticketing_host_new\lib\features\chat\presentation\pages\all_aroundtally_chat_page.dart",
    r"c:\Users\admin\Desktop\crm -ticketting\ticketing_host_new\ticketing_host_new\lib\features\chat\presentation\pages\custom_channel_chat_page.dart",
    r"c:\Users\admin\Desktop\crm -ticketting\ticketing_host_new\ticketing_host_new\lib\features\chat\presentation\pages\direct_message_page.dart",
    r"c:\Users\admin\Desktop\crm -ticketting\ticketing_host_new\ticketing_host_new\lib\features\chat\presentation\pages\global_chat_page.dart",
    r"c:\Users\admin\Desktop\crm -ticketting\ticketing_host_new\ticketing_host_new\lib\features\chat\presentation\widgets\sales_team_chat_view.dart"
]

def process_file(path):
    if not os.path.exists(path):
        print(f"Not found: {path}")
        return
    
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. PlatformFile? _selectedFile; -> List<PlatformFile> _selectedFiles = [];
    content = re.sub(r'PlatformFile\?\s+_selectedFile;', r'List<PlatformFile> _selectedFiles = [];', content)

    # 2. _selectedFile = file; -> _selectedFiles.add(file);
    content = content.replace('_selectedFile = file;', '_selectedFiles.add(file);')

    # 3. _selectedFile == null -> _selectedFiles.isEmpty
    content = content.replace('_selectedFile == null', '_selectedFiles.isEmpty')

    # 4. _selectedFile != null -> _selectedFiles.isNotEmpty
    content = content.replace('_selectedFile != null', '_selectedFiles.isNotEmpty')

    # 5. File picker allowMultiple
    content = re.sub(
        r'allowMultiple:\s*false,',
        r'allowMultiple: true,',
        content
    )

    # 6. result.files.first -> result.files
    #    _selectedFile = result.files.first; -> _selectedFiles.addAll(result.files);
    content = content.replace('_selectedFile = result.files.first;', '_selectedFiles.addAll(result.files);')
    content = content.replace('_selectedFile = null;', '_selectedFiles.clear();')
    content = content.replace('setState(() => _selectedFile = null)', 'setState(() => _selectedFiles.clear())')

    # Now the tricky parts: The UI preview and the sendMessage logic.
    # UI Preview
    ui_preview_old = r'''            // Selected File Preview
            if (_selectedFiles.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.isDarkMode \? context.adaptiveCard : Colors.white,
                  borderRadius: BorderRadius.circular\(12\),
                  border: Border.all\(color: context.isDarkMode \? context.adaptiveSlate800 : Colors.grey.shade300\),
                  boxShadow: \[
                    BoxShadow\(
                      color: Colors.black.withOpacity\(0.05\),
                      blurRadius: 4,
                      offset: const Offset\(0, 2\),
                    \),
                  \],
                \),
                child: Row\(
                  children: \[
                    if \(_selectedFile!\.bytes != null &&
                        \['png', 'jpg', 'jpeg', 'webp', 'gif'\]\.contains\(\(_selectedFile!\.extension \?\? ''\)\.toLowerCase\(\)\)\)
                      ClipRRect\(
                        borderRadius: BorderRadius.circular\(8\),
                        child: Image.memory\(
                          _selectedFile!\.bytes!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        \),
                      \)
                    else
                      Icon\(_getFileIcon\(_selectedFile!\.extension\), size: 32, color: AppColors.primary\),
                    const SizedBox\(width: 12\),
                    Expanded\(
                      child: Column\(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: \[
                          Text\(
                            _selectedFile!\.name,
                            style: const TextStyle\(fontWeight: FontWeight.w600, fontSize: 14\),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          \),
                          if \(_selectedFile!\.size > 0\)
                            Text\(
                              '\$\{\(_selectedFile!\.size / 1024\)\.toStringAsFixed\(1\)\} KB',
                              style: TextStyle\(fontSize: 12, color: context.adaptiveSlate500\),
                            \),
                        \],
                      \),
                    \),
                    IconButton\(
                      icon: Icon\(Icons.close, color: context.adaptiveSlate500\),
                      onPressed: \(\) => setState\(\(\) => _selectedFiles.clear\(\)\),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints\(\),
                    \),
                  \],
                \),
              \),'''
    
    # We will use regex to find the UI preview block because some files might have slightly different spacing
    # Actually, it's easier to just find `// Selected File Preview` and replace until `// Input area`
    
    ui_preview_new = '''            // Selected Files Preview
            if (_selectedFiles.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedFiles.map((file) {
                    return Container(
                      width: 200,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.isDarkMode ? context.adaptiveCard : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.isDarkMode ? context.adaptiveSlate800 : Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          if (file.bytes != null &&
                              ['png', 'jpg', 'jpeg', 'webp', 'gif'].contains((file.extension ?? '').toLowerCase()))
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                file.bytes!,
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            Icon(_getFileIcon(file.extension), size: 24, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  file.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (file.size > 0)
                                  Text(
                                    '${(file.size / 1024).toStringAsFixed(1)} KB',
                                    style: TextStyle(fontSize: 10, color: context.adaptiveSlate500),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: context.adaptiveSlate500, size: 20),
                            onPressed: () => setState(() => _selectedFiles.remove(file)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),'''

    content = re.sub(r'// Selected File Preview.*?// Input area', ui_preview_new + '\n\n            // Input area', content, flags=re.DOTALL)
    
    # Drag drop overlay (around line 850)
    # Icon(_getFileIcon(_selectedFile!.extension) ... _selectedFile!.name
    content = content.replace('_selectedFile!.extension', '_selectedFiles.first.extension')
    content = content.replace('_selectedFile!.name', '(_selectedFiles.length == 1 ? _selectedFiles.first.name : "${_selectedFiles.length} files")')

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
        print(f"Updated {path}")

for f in files_to_update:
    process_file(f)
