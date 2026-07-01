import urllib.request
import json
import time
import sys

url_tokens = 'https://ymgsxwfwntbqvguvbhoa.supabase.co/rest/v1/fcm_tokens?select=*'
url_edge = 'https://ymgsxwfwntbqvguvbhoa.supabase.co/functions/v1/enviar-push-fcm'

headers = {
    'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw',
    'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw',
    'Content-Type': 'application/json'
}

print('Starting polling script... Waiting for active FCM token in database.', flush=True)

start_time = time.time()
timeout = 180 # 3 minutes timeout

while time.time() - start_time < timeout:
    req = urllib.request.Request(url_tokens, headers={k: v for k, v in headers.items() if k != 'Content-Type'})
    try:
        with urllib.request.urlopen(req) as res:
            tokens = json.loads(res.read().decode('utf-8'))
            if len(tokens) > 0:
                target = tokens[0]
                token = target['token']
                uid = target['usuario_id']
                device = target['dispositivo']
                print(f'\nFound registered token for User {uid} on {device}!', flush=True)
                
                # Send push notification via Edge Function
                payload = {
                    'token': token,
                    'titulo': '⚓ ¡Prueba de Antigravity!',
                    'cuerpo': 'Hola chamigo, esta es una prueba enviada por el agente de desarrollo. ¡Llegó con la pantalla en reposo!',
                    'tipo': 'seguridad',
                    'sonido': 'default'
                }
                
                data = json.dumps(payload).encode('utf-8')
                edge_req = urllib.request.Request(url_edge, data=data, headers=headers, method='POST')
                
                with urllib.request.urlopen(edge_req) as edge_res:
                    print('Push notification sent successfully!', flush=True)
                    print(edge_res.read().decode('utf-8'), flush=True)
                
                sys.exit(0)
    except Exception as e:
        print(f'Error: {e}', flush=True)
        
    print('.', end='', flush=True)
    time.sleep(3)

print('\nTimeout reached. No tokens registered.', flush=True)
sys.exit(1)
