
def analyze_braces(filename):
    with open(filename, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    depth = 0
    class_found = False
    game_engine_start = 0
    
    for i, line in enumerate(lines):
        line_num = i + 1
        
        # Simple check for comments (imperfect but helps)
        stripped = line.strip()
        if stripped.startswith('//'):
            continue
            
        if 'class GameEngine' in line:
            class_found = True
            game_engine_start = line_num
            print(f"GameEngine starts at {line_num}")
            
        for char in line:
            if char == '{':
                depth += 1
            elif char == '}':
                depth -= 1
                if class_found and depth == 0:
                    print(f"GameEngine closes at {line_num}")
                    print(f"Line content: {line.strip()}")
                    return
analyze_braces(r'c:\Users\kimro\Documents\Codex\Club Blackout Android Android\lib\logic\game_engine.dart')
