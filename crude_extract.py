import re
import os

def extract_strings_from_pdf(path):
    if not os.path.exists(path):
        return f"File not found: {path}"
    
    with open(path, 'rb') as f:
        content = f.read()
    
    # Try to find text within parentheses ( ) which is common for literal strings in PDF
    # and < > for hex strings.
    # This is very crude but might work if the PDF is not fully compressed/encrypted.
    
    # Matches strings like (Some Text)
    # We want to filter out very short strings and non-ASCII stuff.
    matches = re.findall(b'\((.*?)\)', content)
    
    text_blocks = []
    for m in matches:
        try:
            # Drop strings that are too short or have lots of non-printable chars
            s = m.decode('ascii')
            if len(s) > 3 and all(31 < ord(c) < 127 for c in s):
                text_blocks.append(s)
        except:
            continue
            
    return "\n".join(text_blocks)

host_path = r"C:\Users\kimro\Downloads\Club Blackout (Booklet).pdf"
player_path = r"C:\Users\kimro\Downloads\Club Blackout Player Booklet A5 (1).pdf"

print("--- HOST GUIDE RAW STRINGS ---")
print(extract_strings_from_pdf(host_path)[:2000])

print("\n--- PLAYER GUIDE RAW STRINGS ---")
print(extract_strings_from_pdf(player_path)[:2000])
