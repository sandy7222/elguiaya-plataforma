import 'dart:io';

void main() {
  final file = File(r'C:/Users/sandy/.gemini/antigravity-ide/brain/25653b92-1d90-447a-83fc-ba42156a4ee4/.system_generated/tasks/task-966.log');
  if (!file.existsSync()) {
    print('Log file not found');
    return;
  }
  
  final lines = file.readAsLinesSync();
  print('--- ERRORS IN LIB ---');
  for (var line in lines) {
    if (line.contains('error •')) {
      print(line);
    }
  }
}
