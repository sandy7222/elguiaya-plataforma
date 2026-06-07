import sys

# Reconfigure stdout to print utf-8 safely
sys.stdout.reconfigure(encoding='utf-8')

with open(r"c:\CapitanYA\capitan11.5.2026\lib\services\el_guia_engine.dart", 'r', encoding='utf-8') as f:
    lines = f.readlines()

found = False
for i, line in enumerate(lines):
    if 'Future<ElGuiaRespuesta> _generarRespuesta(' in line:
        found = True
        print(f"Line {i+1}: {line.strip()}")
        # print 45 lines below it
        for j in range(i, min(i+45, len(lines))):
            print(f"  {j+1}: {lines[j].rstrip()}")
        break

if not found:
    print("Could not find the definition of _generarRespuesta")
