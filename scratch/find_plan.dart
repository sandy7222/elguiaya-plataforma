import 'dart:io';
import 'dart:convert';

void main() async {
  final file = File(r'C:\Users\sandy\.gemini\antigravity\brain\cf381d06-a8e0-477c-88b6-9c32f539d6b8\.system_generated\logs\transcript.jsonl');
  if (!await file.exists()) {
    print('File not found!');
    return;
  }
  
  final lines = await file.readAsLines();
  int targetIndex = -1;
  for (int i = lines.length - 1; i >= 0; i--) {
    final line = lines[i];
    if (line.trim().isEmpty) continue;
    try {
      final obj = jsonDecode(line);
      final content = obj['content'] ?? '';
      if (content.contains('Está perfecto, ejecuta el plan')) {
        targetIndex = obj['step_index'];
        print('Found user message at step index: $targetIndex');
        break;
      }
    } catch (e) {}
  }

  if (targetIndex == -1) {
    print('Target not found!');
    return;
  }

  // Print steps immediately preceding targetIndex
  for (var line in lines) {
    if (line.trim().isEmpty) continue;
    try {
      final obj = jsonDecode(line);
      final idx = obj['step_index'];
      if (idx != null && idx >= targetIndex - 12 && idx <= targetIndex) {
        print('=== STEP $idx (Source: ${obj['source']}, Type: ${obj['type']}) ===');
        if (obj['content'] != null) {
          print(obj['content']);
        } else if (obj['thinking'] != null) {
          print('Thinking: ${obj['thinking']}');
        }
        if (obj['tool_calls'] != null) {
          print('Tool calls: ${obj['tool_calls']}');
        }
        print('\n');
      }
    } catch (e) {}
  }
}
