import re

with open('d:/VMsProject/Creations/Screenique/screenique/lib/comments_bottom_sheet.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace colors for the main container
content = content.replace("color: Color(0xFFF4F4EC),", "color: const Color(0xFF0A0A0A),")
content = content.replace("border: Border(top: BorderSide(color: Color(0xFF111111), width: 2)),", "border: const Border(top: BorderSide(color: Color(0xFF222222), width: 1)),")
content = content.replace("color: const Color(0xFF888882)", "color: Colors.white24")

# Text "COMMENTS"
content = content.replace("color: Color(0xFF111111),", "color: Colors.white,")
content = content.replace("const Divider(color: Color(0xFF111111), thickness: 1.5, height: 24)", "const Divider(color: Colors.white10, thickness: 1, height: 24)")

# "No comments yet" text
content = content.replace("color: Color(0xFF888882)", "color: Colors.white54")

# Input Area border
content = content.replace("border: Border(top: BorderSide(color: Color(0xFFE0E0DB), width: 1.5)),", "border: const Border(top: BorderSide(color: Colors.white10, width: 1)),")

# Reply header text
content = content.replace("color: Color(0xFF454545)", "color: Colors.white70")
content = content.replace("color: Color(0xFF111111)", "color: Colors.white54") # Close button

# Input Field container
content = content.replace("color: const Color(0xFFEBEBE4)", "color: const Color(0xFF15181E)")
content = content.replace("border: Border.all(color: const Color(0xFF111111), width: 1.5)", "border: Border.all(color: Colors.white10, width: 1)")
content = content.replace("color: Color(0xFF111111)", "color: Colors.white") # Input text
content = content.replace("color: Color(0xFF888882)", "color: Colors.white38") # Hint text

# Comment Node
content = content.replace("background=111111&color=f4f4ec", "background=222222&color=ffffff")
content = content.replace("backgroundColor: const Color(0xFF111111),", "backgroundColor: const Color(0xFF222222),")
content = content.replace("color: Color(0xFF111111)", "color: Colors.white") # Name
content = content.replace("color: Color(0xFF888882)", "color: Colors.white54") # Time
content = content.replace("color: Color(0xFF454545)", "color: Colors.white70") # Text
content = content.replace("color: isLiked ? const Color(0xFFD32F2F) : const Color(0xFF888882)", "color: isLiked ? const Color(0xFFD32F2F) : Colors.white54")

# Write changes
with open('d:/VMsProject/Creations/Screenique/screenique/lib/comments_bottom_sheet.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Comments screen dark theme refactored.")
