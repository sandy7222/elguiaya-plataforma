import os
import json

def get_text_from_node(node):
    """Recursively extract text strings from a JSON node."""
    texts = []
    if isinstance(node, str):
        if len(node.strip()) > 10:
            texts.append(node.strip())
    elif isinstance(node, list):
        for item in node:
            texts.extend(get_text_from_node(item))
    elif isinstance(node, dict):
        # Prioritize certain keys if present
        keys = ['descripcion_corta', 'descripcion_extensa', 'descripcion', 'uso', 'consejo_encarne', 'consejo', 'error_comun', 'aparejo', 'cana', 'reel', 'anzuelo', 'carnada']
        for k in keys:
            if k in node:
                texts.extend(get_text_from_node(node[k]))
        # Fetch other keys
        for k, v in node.items():
            if k not in keys:
                texts.extend(get_text_from_node(v))
    return texts

def generate_respuestas(content, filename):
    """Generate 3-5 short summaries from JSON content."""
    texts = get_text_from_node(content)
    
    # Filter unique, non-empty sentences and clean them up
    sentences = []
    seen = set()
    for t in texts:
        # Split by periods or newlines to get individual sentences
        parts = [p.strip() for p in t.replace('\n', ' ').split('.') if p.strip()]
        for p in parts:
            p_clean = p.replace('  ', ' ')
            if len(p_clean) >= 15 and len(p_clean) <= 150 and p_clean.lower() not in seen:
                seen.add(p_clean.lower())
                sentences.append(p_clean)
                
    # Fallbacks if we couldn't parse enough sentences
    if len(sentences) < 3:
        sentences.append(f"Información técnica sobre {filename.replace('_', ' ')} para pesca deportiva.")
        sentences.append("Consejos de baqueano para optimizar tu equipamiento y técnica de pesca en la zona.")
        sentences.append("Recomendaciones de seguridad y buenas prácticas para la navegación en el Paraná.")
        
    # Cap at 5, ensure minimum 3
    final_list = sentences[:5]
    if len(final_list) < 3:
        final_list = (final_list * 3)[:3]
        
    return final_list

def main():
    libs_dir = r"c:\CapitanYA\capitan11.5.2026\assets\elguia\librerias"
    had_field = 0
    updated = 0
    
    for filename in os.listdir(libs_dir):
        if not filename.endswith('.json'):
            continue
            
        filepath = os.path.join(libs_dir, filename)
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                data = json.load(f)
        except Exception as e:
            print(f"Error reading {filename}: {e}")
            continue
            
        if 'respuestas_puente' in data:
            had_field += 1
        else:
            # Generate responses
            respuestas = generate_respuestas(data, os.path.splitext(filename)[0])
            # Insert at the beginning or end of dictionary
            data['respuestas_puente'] = respuestas
            
            try:
                with open(filepath, 'w', encoding='utf-8') as f:
                    json.dump(data, f, ensure_ascii=False, indent=2)
                updated += 1
            except Exception as e:
                print(f"Error writing {filename}: {e}")
                
    print(f"AUDIT COMPLETE.")
    print(f"Files that already had 'respuestas_puente': {had_field}")
    print(f"Files updated with new 'respuestas_puente': {updated}")

if __name__ == '__main__':
    main()
