import 'dart:io';

void main() {
  final file = File(r'C:/Users/sandy/.gemini/antigravity/brain/cf381d06-a8e0-477c-88b6-9c32f539d6b8/.system_generated/tasks/task-1015.log');
  if (!file.existsSync()) {
    print('Log file not found');
    return;
  }
  
  final lines = file.readAsLinesSync();
  print('--- ANALYZING LOG FOR ERRORS ---');
  for (var line in lines) {
    if (line.contains('checkout_payment_screen.dart') || line.contains('mercado_pago_webhook_service.dart')) {
      print(line);
    }
  }
}
