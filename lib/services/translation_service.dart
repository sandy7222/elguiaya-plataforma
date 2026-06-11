


class TranslationService {
  static const String _defaultLanguage = 'es';
  
  // Claves de traduccion
  static const Map<String, Map<String, String>> _translations = {
    'es': {
      'welcome_title': 'El Guía YA',
      'welcome_subtitle': 'Tu mejor amigo de pesca en Argentina',
      'login': 'Login',
      'register': 'Registro',
      'the_fisherman': 'El Pescador',
      'the_captain': 'El Capitan',
      'email': 'Email',
      'password': 'Contrasena',
      'start_session': 'INICIAR SESION',
      'create_account': 'CREAR CUENTA',
      'processing': 'Procesando...',
      'help': 'Ayuda',
      'terms_conditions': 'Terminos y Condiciones',
      'loading_config': 'Cargando configuracion...',
      'please_complete_fields': 'Por favor completa todos los campos',
      'access_granted': 'Acceso concedido',
      'invalid_credentials': 'Credenciales invalidas',
      'select_identity': 'Selecciona tu identidad',
      'choose_flow': 'Elige tu flujo de acceso',
      'enter_credentials': 'Ingresa tus credenciales',
      'new_user': '¿Eres nuevo?',
      'existing_user': '¿Ya tienes cuenta?',
    },
    'en': {
      'welcome_title': 'El Guía YA',
      'welcome_subtitle': 'Your best fishing buddy in Argentina',
      'login': 'Login',
      'register': 'Register',
      'the_fisherman': 'The Fisherman',
      'the_captain': 'The Captain',
      'email': 'Email',
      'password': 'Password',
      'start_session': 'SIGN IN',
      'create_account': 'CREATE ACCOUNT',
      'processing': 'Processing...',
      'help': 'Help',
      'terms_conditions': 'Terms and Conditions',
      'loading_config': 'Loading configuration...',
      'please_complete_fields': 'Please complete all fields',
      'access_granted': 'Access granted',
      'invalid_credentials': 'Invalid credentials',
      'select_identity': 'Select your identity',
      'choose_flow': 'Choose your access flow',
      'enter_credentials': 'Enter your credentials',
      'new_user': 'New user?',
      'existing_user': 'Already have an account?',
    },
    'pt': {
      'welcome_title': 'El Guía YA',
      'welcome_subtitle': 'Seu melhor amigo de pesca na Argentina',
      'login': 'Login',
      'register': 'Registro',
      'the_fisherman': 'O Pescador',
      'the_captain': 'O Capitão',
      'email': 'Email',
      'password': 'Senha',
      'start_session': 'INICIAR SESSÃO',
      'create_account': 'CRIAR CONTA',
      'processing': 'Processando...',
      'help': 'Ajuda',
      'terms_conditions': 'Termos e Condições',
      'loading_config': 'Carregando configuração...',
      'please_complete_fields': 'Por favor complete todos os campos',
      'access_granted': 'Acesso concedido',
      'invalid_credentials': 'Credenciais invalidas',
      'select_identity': 'Selecione sua identidade',
      'choose_flow': 'Escolha seu fluxo de acesso',
      'enter_credentials': 'Digite suas credenciais',
      'new_user': 'Novo usuario?',
      'existing_user': 'Ja tem conta?',
    },
  };

  static String _currentLanguage = _defaultLanguage;

  /// Establecer el idioma actual
  static void setLanguage(String languageCode) {
    if (_translations.containsKey(languageCode)) {
      _currentLanguage = languageCode;
    }
  }

  /// Obtener el idioma actual
  static String get currentLanguage => _currentLanguage;

  /// Obtener lista de idiomas disponibles
  static List<String> get availableLanguages => _translations.keys.toList();

  /// Obtener traduccion para una clave
  static String translate(String key, {String? languageCode}) {
    final lang = languageCode ?? _currentLanguage;
    
    if (!_translations.containsKey(lang)) {
      return _translations[_defaultLanguage]?[key] ?? key;
    }
    
    final langTranslations = _translations[lang]!;
    return langTranslations[key] ?? _translations[_defaultLanguage]?[key] ?? key;
  }

  /// Obtener traduccion con formato
  static String translateFormatted(String key, List<String> args, {String? languageCode}) {
    final translation = translate(key, languageCode: languageCode);
    
    if (args.isEmpty) return translation;
    
    String result = translation;
    for (int i = 0; i < args.length; i++) {
      result = result.replaceAll('{$i}', args[i]);
    }
    
    return result;
  }

  /// Obtener idioma del dispositivo (simulado)
  static String getDeviceLanguage() {
    // En produccion, usaria intl/locale
    return _defaultLanguage;
  }

  /// Inicializar servicio con idioma del dispositivo
  static void initialize() {
    final deviceLanguage = getDeviceLanguage();
    setLanguage(deviceLanguage);
  }

  /// Verificar si una clave existe
  static bool hasKey(String key, {String? languageCode}) {
    final lang = languageCode ?? _currentLanguage;
    
    if (!_translations.containsKey(lang)) {
      return _translations[_defaultLanguage]?.containsKey(key) ?? false;
    }
    
    return _translations[lang]!.containsKey(key);
  }

  /// Obtener todas las traducciones de un idioma
  static Map<String, String> getAllTranslations({String? languageCode}) {
    final lang = languageCode ?? _currentLanguage;
    return Map<String, String>.from(_translations[lang] ?? _translations[_defaultLanguage]!);
  }

  /// Agregar nuevas traducciones (para futuras expansiones)
  static void addTranslations(String languageCode, Map<String, String> translations) {
    _translations[languageCode] = {
      ...(_translations[languageCode] ?? {}),
      ...translations,
    };
  }

  /// Obtener nombre del idioma para mostrar
  static String getLanguageDisplayName(String languageCode) {
    switch (languageCode) {
      case 'es':
        return 'Espanol';
      case 'en':
        return 'English';
      case 'pt':
        return 'Português';
      default:
        return languageCode.toUpperCase();
    }
  }
}

/// Extension para facilitar el uso de traducciones
extension TranslationExtension on String {
  String t({String? languageCode}) => TranslationService.translate(this, languageCode: languageCode);
}
