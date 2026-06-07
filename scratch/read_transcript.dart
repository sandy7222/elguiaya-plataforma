import 'dart:io';
import 'dart:convert';

void main() async {
  final file = File(r'C:\Users\sandy\.gemini\antigravity-ide\brain\827b9791-96ed-4dc6-b3c7-a8af27e6df33\.system_generated\logs\transcript.jsonl');
  if (!await file.exists()) {
    print('File not found!');
    return;
  }
  
  final lines = await file.readAsLines();
  print('--- SEARCHING TRANSCRIPT FOR STEPS ---');
  for (var line in lines) {
    if (line.trim().isEmpty) continue;
    try {
      final obj = jsonDecode(line);
      final int idx = obj['step_index'] ?? -1;
      
      // Let's filter model and user messages around the key step indices we identified
      if (idx == 90 || idx == 91 || idx == 92 || idx == 93 || idx == 119 || idx == 121 || idx == 134) {
        print('\n=== STEP $idx (Source: ${obj['source']}, Type: ${obj['type']}) ===');
        final content = obj['content']?.toString() ?? '';
        print(content);
      }
    } catch (e) {
      print('Error: $e');
    }
  }
}
