import 'dart:async';
import 'package:supabase/supabase.dart';

void main() async {
  const url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';

  print('Initializing Supabase client...');
  final client = SupabaseClient(url, anonKey);

  print('Logging in as maruba@gmail.com...');
  final loginRes = await client.auth.signInWithPassword(
    email: 'maruba@gmail.com',
    password: 'maruba123',
  );
  
  final userId = loginRes.user!.id;
  print('Logged in successfully! User ID: $userId');

  print('Subscribing to stream of notificaciones_globales...');
  try {
    // Note: in pure 'supabase' package, stream() is available on SupabaseClient if we have realtime client,
    // but pure supabase client might need realtime initialization or it might not have stream() directly depending on package version.
    // Let's check if the client has stream.
    // In supabase 2.x pure Dart package, .stream is part of the PostgrestTransformBuilder or custom extensions.
    // Let's check how it behaves.
    final stream = client
        .from('notificaciones_globales')
        .stream(primaryKey: ['id'])
        .eq('receptor_id', userId)
        .order('created_at', ascending: false);

    print('Stream created. Listening...');
    final subscription = stream.listen(
      (data) {
        print('Stream received data: $data');
      },
      onError: (err) {
        print('Stream received error: $err');
      },
      onDone: () {
        print('Stream done.');
      },
    );

    // Wait a bit to see if any errors or data are received
    await Future.delayed(const Duration(seconds: 5));
    print('Cancelling subscription...');
    await subscription.cancel();
    print('Subscription cancelled.');
  } catch (e) {
    print('Synchronous error: $e');
  }
}
