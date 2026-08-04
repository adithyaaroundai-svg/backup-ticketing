import os
import re

files = [
    'lib/features/chat/presentation/widgets/sales_team_chat_view.dart',
    'lib/features/chat/presentation/pages/custom_channel_chat_page.dart',
    'lib/features/chat/presentation/pages/all_aroundtally_chat_page.dart',
]

for f in files:
    if not os.path.exists(f): continue
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
    
    # We want to replace:
    # if (_hovered && !isDeleted) ...[
    #   const SizedBox(width: 6),
    #   Container(
    
    # With:
    # if (!isDeleted) ...[
    #   const SizedBox(width: 6),
    #   IgnorePointer(
    #     ignoring: !_hovered,
    #     child: AnimatedOpacity(
    #       opacity: _hovered ? 1.0 : 0.0,
    #       duration: const Duration(milliseconds: 150),
    #       child: Container(
    
    # AND we need to add two closing `),` at the end of the `Container`.
    # But wait, there is no easy way to find the end of the `Container` using basic regex.
    # What if we just do:
    # if (!isDeleted) ...[
    #   if (_hovered) const SizedBox(width: 6), // Wait, that would still jump!
    
    # Let's use a clever regex. The Container ends where the `if (_hovered && !isDeleted) ...[` block ends, which is `],\n                ),`!
    
    # Let's split by `if (_hovered && !isDeleted) ...[`
    parts = content.split('if (_hovered && !isDeleted) ...[')
    if len(parts) > 1:
        new_content = parts[0]
        for part in parts[1:]:
            new_part = part.replace('const SizedBox(width: 6),\n              Container(', 
                                    'const SizedBox(width: 6),\n              IgnorePointer(\n                ignoring: !_hovered,\n                child: AnimatedOpacity(\n                  opacity: _hovered ? 1.0 : 0.0,\n                  duration: const Duration(milliseconds: 150),\n                  child: Container(')
            
            # Find the closing `],\n                ),` block to add the two closing `),`
            # This is exactly where the `...[` block ends.
            # Actually, `...[` ends with `\n            ],`
            # Wait, `...[` is an array expansion. It ends with `],`
            
            # Let's just find the first `\n            ],` and insert `),),` before it.
            # But wait, inside the `Container` there are multiple `],`
            # Let's just find `\n            ],` with the exact indentation?
            # Or we can just find `\n                    ),` (the end of PopupMenuButton) and append `),),` right after it!
            # Since `PopupMenuButton` is the LAST item in the action bar Container's children, the structure is:
            #                     PopupMenuButton( ... ),
            #                   ],
            #                 ),
            #               ),
            #             ],
            
            # So if we replace:
            #                   ],
            #                 ),
            #               ),
            #             ],
            # With:
            #                   ],
            #                 ),
            #               ),
            #               ),
            #               ),
            #             ],
            
            # Actually, let's just do an exact replace on the known string!
            target_end = """                      ],
                    ),

                  ],
                ),
              ),
            ],"""
            
            replacement_end = """                      ],
                    ),

                  ],
                ),
              ),
              ),
              ),
            ],"""
            
            new_part = new_part.replace(target_end, replacement_end)
            new_content += 'if (!isDeleted) ...[' + new_part
        content = new_content
        
        with open(f, 'w', encoding='utf-8') as file:
            file.write(content)
        print(f"Fixed {f}")
