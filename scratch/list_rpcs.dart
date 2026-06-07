import 'dart:io';

void main() {
  final file = File('lib/services/supabase_service.dart');
  if (!file.existsSync()) {
    print('supabase_service.dart not found');
    return;
  }
  
  final content = file.readAsStringSync();
  final regex = RegExp(r"\.rpc\(\s*['"'""](\w+)['"'""]");
  final matches = regex.allMatches(content);
  final rpcs = matches.map((m) => m.group(1)).toSet();
  print('--- RPCs in supabase_service.dart ---');
  for (var rpc in rpcs) {
    print('RPC: $rpc');
  }
}
