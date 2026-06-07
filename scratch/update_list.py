import os
import re

def main():
    libs_dir = r"c:\CapitanYA\capitan11.5.2026\assets\elguia\librerias"
    engine_file = r"c:\CapitanYA\capitan11.5.2026\lib\services\el_guia_engine.dart"
    
    # 1. Get all json files basenames
    files = [os.path.splitext(f)[0] for f in os.listdir(libs_dir) if f.endswith('.json')]
    files.sort()
    
    # 2. Format them as Dart string list
    formatted_list = "      const archivos = [\n"
    chunk_size = 4
    for i in range(0, len(files), chunk_size):
        chunk = files[i:i+chunk_size]
        formatted_list += "        " + ", ".join(f"'{name}'" for name in chunk) + ",\n"
    formatted_list += "      ];"
    
    # 3. Read el_guia_engine.dart
    with open(engine_file, 'r', encoding='utf-8') as f:
        content = f.read()
        
    # 4. Find the archivos list block and replace it
    pattern = r"      const archivos = \[[^\]]*\];"
    new_content, count = re.subn(pattern, formatted_list, content)
    
    if count > 0:
        with open(engine_file, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"SUCCESS: Replaced archivos list in el_guia_engine.dart with {len(files)} files.")
    else:
        print("ERROR: Could not find archives pattern in el_guia_engine.dart")

if __name__ == '__main__':
    main()
