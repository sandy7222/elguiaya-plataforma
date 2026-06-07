void main() {
  final text = "¡Hola che chamigo! 🎣 Soy el **Baqueano-IA** (ID: 123). ¿Que hacemos hoy pescador? 🛶 ";
  String cleanText = text.replaceAll('*', '');
  cleanText = cleanText.replaceAll('_', '');
  cleanText = cleanText.replaceAll('#', '');
  cleanText = cleanText.replaceAll(RegExp(r'[^a-zA-Z0-9áéíóúÁÉÍÓÚñÑüÜ\s\.,;:!\?\(\)\-\"\u0027\$%¡¿]'), '');
  cleanText = cleanText.replaceAll(RegExp(r'\s+'), ' ').trim();
  
  print('Original: $text');
  print('Cleaned:  $cleanText');
}
