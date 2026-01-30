import pypdf
import re
import json
import os

def extract_text_from_pdf(path):
    if not os.path.exists(path):
        return f"File not found: {path}"
    try:
        reader = pypdf.PdfReader(path)
        full_text = ""
        for page in reader.pages:
            full_text += page.extract_text() + "\n"
        return full_text, reader
    except Exception as e:
        return f"Error reading {path}: {e}", None

def get_section(text, section_name, next_sections=[]):
    # Escape section names for regex
    section_name_esc = re.escape(section_name)
    next_sections_esc = [re.escape(s) for s in next_sections]
    
    # Try to find the section headers
    # Matches the section name (case-insensitive) followed by anything until one of the next sections or EOF
    pattern = rf"(?i){section_name_esc}.*?\n(.*?)(?:\n(?:" + "|".join(next_sections_esc) + r")|$)"
    match = re.search(pattern, text, re.DOTALL)
    if match:
        return match.group(1).strip()
    return "Section not found."

def get_fonts(reader):
    fonts = set()
    try:
        for page in reader.pages:
            if "/Resources" in page and "/Font" in page["/Resources"]:
                f = page["/Resources"]["/Font"]
                for key in f:
                    try:
                        fonts.add(f[key]["/BaseFont"])
                    except:
                        pass
    except:
        pass
    return list(fonts)

host_path = r"C:\Users\kimro\Downloads\Club Blackout (Booklet).pdf"
player_path = r"C:\Users\kimro\Downloads\Club Blackout Player Booklet A5 (1).pdf"

print("Extracting Host Guide...")
host_text, host_reader = extract_text_from_pdf(host_path)
print("Extracting Player Guide...")
player_text, player_reader = extract_text_from_pdf(player_path)

if host_reader:
    print("\n--- HOST GUIDE SECTIONS ---")
    sections = ["Overview", "Setup", "Night Phase", "Day Phase", "Roles"]
    for i, section in enumerate(sections):
        others = sections[:i] + sections[i+1:]
        content = get_section(host_text, section, others)
        print(f"[{section}]\n{content[:500]}...\n")

    print("\n--- HOST GUIDE METADATA ---")
    print(json.dumps(dict(host_reader.metadata), indent=4))
    print("\n--- HOST GUIDE FONTS ---")
    print(get_fonts(host_reader))

if player_reader:
    print("\n--- PLAYER GUIDE SECTIONS ---")
    sections = ["Roles", "Mechanics", "Overview"]
    for i, section in enumerate(sections):
        others = sections[:i] + sections[i+1:]
        content = get_section(player_text, section, others)
        print(f"[{section}]\n{content[:500]}...\n")

    print("\n--- PLAYER GUIDE METADATA ---")
    print(json.dumps(dict(player_reader.metadata), indent=4))
    print("\n--- PLAYER GUIDE FONTS ---")
    print(get_fonts(player_reader))
