import sys
from pathlib import Path

p = Path(sys.argv[1]) if len(sys.argv) > 1 else None
if not p or not p.exists():
    print("usage: python analyze_braces.py <file.dart>")
    raise SystemExit(2)

text = p.read_text(encoding="utf-8", errors="ignore")
stack = []
pairs = {"{": "}", "(": ")", "[": "]"}
opens = set(pairs.keys())
closes = set(pairs.values())
rev = {v: k for k, v in pairs.items()}

for i, ch in enumerate(text):
    if ch in opens:
        stack.append(ch)
    elif ch in closes:
        if not stack or stack[-1] != rev[ch]:
            print(f"mismatch at char {i}: got {ch}")
            break
        stack.pop()
else:
    print("ok" if not stack else f"unclosed: {''.join(stack)}")
