import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart'; // Para inicializar formatos locales en español

// Importaciones normalizadas
import 'package:capitanya_master/services/supabase_service.dart';
import 'package:capitanya_master/services/email_verification_policy.dart';
import 'package:capitanya_master/app_navigator.dart';
import 'package:capitanya_master/services/fcm_service.dart';
import 'package:capitanya_master/providers/cart_provider.dart';
import 'package:capitanya_master/providers/favoritos_provider.dart';
import 'package:capitanya_master/screens/bienvenida_definitiva_screen.dart';
import 'package:capitanya_master/screens/verificar_email_screen.dart';
import 'package:capitanya_master/screens/nueva_password_screen.dart';
import 'package:capitanya_master/screens/inicio_screen.dart';
import 'package:capitanya_master/screens/admin_catalogo_screen.dart';
import 'package:capitanya_master/screens/admin_dashboard_screen.dart';
import 'package:capitanya_master/screens/admin_banners_screen.dart';
import 'package:capitanya_master/screens/directorio_pescadores_screen.dart';
import 'package:capitanya_master/screens/directorio_capitanes_screen.dart';
import 'package:capitanya_master/screens/documentos_pendientes_screen.dart';
import 'package:capitanya_master/screens/admin_perfiles_aprobacion_screen.dart';
import 'package:capitanya_master/screens/admin_inventario_screen.dart';
import 'package:capitanya_master/screens/admin_sales_monitor_screen.dart';
import 'package:capitanya_master/screens/admin_reembolsos_screen.dart';
import 'package:capitanya_master/screens/admin_envios_screen.dart';
import 'package:capitanya_master/screens/admin_viajes_screen.dart';
import 'package:capitanya_master/screens/admin_disputas_screen.dart';
import 'package:capitanya_master/screens/admin_tracking_screen.dart';
import 'package:capitanya_master/screens/admin_logs_screen.dart';
import 'package:capitanya_master/screens/portal_capitan_screen.dart';
import 'package:capitanya_master/screens/portal_pescador_screen.dart';
import 'package:capitanya_master/screens/cart_screen.dart';
import 'package:capitanya_master/screens/notificaciones_screen.dart';
import 'package:capitanya_master/services/mercado_pago_service.dart';
import 'package:capitanya_master/services/dynamic_skill_system.dart';
import 'package:capitanya_master/services/afip_billing_skill.dart';
import 'package:capitanya_master/services/maestro_pescador_skill.dart';
import 'package:capitanya_master/services/emergencia_nautica_skill.dart';
import 'package:capitanya_master/services/navegacion_gps_skill.dart';
import 'package:capitanya_master/services/truco_argentino_skill.dart';
import 'package:capitanya_master/services/guia_local_core.dart';
import 'package:capitanya_master/services/connectivity_bridge.dart';
import 'package:capitanya_master/services/baqueano_ia_service.dart';
import 'package:capitanya_master/widgets/guia_overlay.dart';
import 'package:capitanya_master/widgets/map_selector_widget.dart';
import 'package:capitanya_master/services/guia_knowledge_sync_service.dart';
import 'package:capitanya_master/screens/categories_grid_screen.dart';
import 'package:capitanya_master/screens/pescador_perfil_edit_screen.dart';
import 'package:capitanya_master/screens/favoritos_screen.dart';
import 'package:capitanya_master/screens/blog_piques_screen.dart';
import 'package:capitanya_master/screens/pronostico_screen.dart';
import 'package:capitanya_master/screens/viajes_programados_screen.dart';
import 'package:capitanya_master/widgets/solunar_card_widget.dart';
import 'package:capitanya_master/services/deep_link_service.dart';
import 'package:capitanya_master/services/recordatorios_service.dart';
import 'package:capitanya_master/services/viaje_gps_coordinator.dart';
import 'package:capitanya_master/services/firebase_messaging_background.dart';
import 'package:capitanya_master/services/notificacion_sonido_listener.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:capitanya_master/screens/product_detail_screen.dart';
import 'package:capitanya_master/models/producto.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

Future<void> main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  // FCM background handler lo antes posible (Android)
  if (!kIsWeb) {
    try {
      if (Platform.isAndroid) {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      }
    } catch (_) {}
  }

  // Inicializar formatos de fecha para locales en español ('es')
  await initializeDateFormatting('es', null);

  // 1. Supabase PRIMERO (requisito del SDK — el resto depende de él)
  await SupabaseService.initialize();

  // 2. Solo lo mínimo para el primer frame (Hive, conectividad, preferencias overlay)
  await Future.wait([
    GuiaLocalCore.inicializar(),
    ConnectivityBridge.inicializar(),
    GuiaOverlayController.cargarPreferencia(),
  ]);

  // 3. Registrar skills dinámicas del sistema (sin red, instantáneo)
  SystemSkillRegistry.register(AfipBillingSkill());
  SystemSkillRegistry.register(MaestroPescadorSkill());
  SystemSkillRegistry.register(EmergenciaNauticaSkill());
  SystemSkillRegistry.register(NavegacionGpsSkill());
  SystemSkillRegistry.register(TrucoArgentinoSkill());

  // 4. Ejecutar sincronizaciones de conocimiento El Guía
  GuiaKnowledgeSyncService.verificarYEjecutarSincronizaciones();

  // 5. Inicializar servicio de Deep Links
  DeepLinkService().inicializar();

  // 5b. Push FCM Android (campanita con sonido fuera de la app) - Asíncrono no bloqueante
  unawaited(FCMService.inicializar().then((_) {
    NotificacionSonidoListener.iniciar();
  }));

  // 6. 🗓️ Iniciar scheduler de recordatorios automáticos (WhatsApp 7d, 3d, 24h, 12h)
  //    Corre en segundo plano cada 5 minutos verificando recordatorios pendientes.
  RecordatoriosService.iniciarScheduler();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => FavoritosProvider()),
      ],
      child: const MyApp(),
    ),
  );

  // Servicios pesados / de red: después del primer frame (no bloquean el login)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(BaqueanoIAService.inicializar());
    unawaited(
      MercadoPagoService.cargarCredenciales().timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      ),
    );
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'El Guia YA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Outfit',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF001F3F),
          foregroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.white),
          actionsIconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 8,
            shadowColor: Colors.blue.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
      // 🚀 ENVOLTORIO ACTUALIZADO: Apunta directo a la vista con AuthGate
      home: const SessionWrapper(),
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const GuiaOverlay(),
          ],
        );
      },
      routes: {
        '/inicio': (context) => const InicioScreen(),
        '/admin/catalogo': (context) => const AdminCatalogoScreen(),
        '/admin/dashboard': (context) => const AdminDashboardScreen(),
        '/admin/banners': (context) => const AdminBannersScreen(),
        '/admin/directorio_pescadores': (context) =>
            const DirectorioPescadoresScreen(),
        '/admin/directorio_capitanes': (context) =>
            const DirectorioCapitanesScreen(),
        '/admin/documentos_pendientes': (context) =>
            const DocumentosPendientesScreen(),
        '/admin/perfiles_aprobacion': (context) =>
            const AdminPerfilValidationScreen(),
        '/admin/inventario': (context) => const AdminInventarioScreen(),
        '/admin/pedidos': (context) => const AdminSalesMonitorScreen(),
        '/admin/reembolsos': (context) => const AdminReembolsosScreen(),
        '/admin/envios': (context) => const AdminEnviosScreen(),
        '/admin/viajes': (context) => const AdminViajesScreen(),
        '/admin/disputas': (context) =>
            const AdminDisputasScreen(embedMode: false),
        '/admin/trazabilidad': (context) =>
            const AdminTrackingScreen(embedMode: false),
        '/admin/logs': (context) => const AdminLogsScreen(embedMode: false),
        '/carrito': (context) => const CartScreen(),
        '/notificaciones': (context) => const NotificacionesScreen(),
        '/mapa': (context) => Scaffold(
          appBar: AppBar(
            title: const Text(
              'MAPA DE RUTA',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1.5,
              ),
            ),
            backgroundColor: const Color(0xFF001529),
            foregroundColor: Colors.white,
          ),
          body: MapSelectorWidget(onRouteSelected: (p0, p1, p2) {}),
        ),
        '/tienda': (context) => const CategoriesGridScreen(),
        '/perfil': (context) => PescadorPerfilEditScreen(),
        '/favoritos': (context) => const FavoritosScreen(),
        '/blog': (context) => const BlogPiquesScreen(),
        '/solunar': (context) => Scaffold(
          appBar: AppBar(
            title: const Text(
              'TABLA SOLUNAR',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1.5,
              ),
            ),
            backgroundColor: const Color(0xFF001529),
            foregroundColor: Colors.white,
          ),
          body: const SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
            child: SolunarCardWidget(),
          ),
        ),
        '/clima': (context) => const PronosticoScreen(),
        '/historial': (context) => const ViajesProgramadosScreen(esCapitan: false),
        '/panel': (context) => const PortalPescadorScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name != null && settings.name!.startsWith('/producto/')) {
          final parts = settings.name!.split('/');
          if (parts.length >= 3) {
            final productId = parts[2];
            return MaterialPageRoute(
              builder: (context) => ProductDetailRouteWrapper(productId: productId),
              settings: settings,
            );
          }
        }
        return null;
      },
    );
  }
}

class SessionWrapper extends StatefulWidget {
  const SessionWrapper({super.key});

  @override
  State<SessionWrapper> createState() => _SessionWrapperState();
}

class _SessionWrapperState extends State<SessionWrapper> with WidgetsBindingObserver {
  StreamSubscription<AuthState>? _authSubscription;
  Session? _currentSession;
  Map<String, dynamic>? _perfil;
  bool _isLoadingPerfil = false;
  String? _lastFetchedUserId;
  bool _initialized = false;
  bool _passwordRecoveryPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenToAuth();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        Supabase.instance.client.auth.currentSession != null) {
      ViajeGpsCoordinator().resumeIfNeeded();
    }
  }

  void _listenToAuth() {
    final initialSession = Supabase.instance.client.auth.currentSession;
    if (initialSession != null) {
      _currentSession = initialSession;
      _fetchPerfil(initialSession.user.id);
    } else {
      setState(() {
        _initialized = true;
      });
    }

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) async {
      if (!mounted) return;

      if (data.event == AuthChangeEvent.passwordRecovery) {
        setState(() {
          _passwordRecoveryPending = true;
          _currentSession = data.session;
        });
        return;
      }

      final newSession = data.session;
      final newUserId = newSession?.user.id;

      if (newUserId != _lastFetchedUserId || newSession == null) {
        setState(() {
          _currentSession = newSession;
          if (newSession == null) {
            _perfil = null;
            _lastFetchedUserId = null;
            _initialized = true;
            _isLoadingPerfil = false;
            SupabaseService.cacheSessionEsCapitan(null);
          }
        });

        if (newSession != null) {
          await _fetchPerfil(newUserId!);
        }
      } else {
        if (_currentSession != newSession) {
          setState(() {
            _currentSession = newSession;
          });
        }
      }
    });
  }

  Future<void> _fetchPerfil(String userId) async {
    if (!mounted) return;
    setState(() {
      _isLoadingPerfil = true;
    });

    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('admin, es_capitan, estado')
          .eq('user_id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _perfil = res;
          _lastFetchedUserId = userId;
          _isLoadingPerfil = false;
          _initialized = true;
        });
        SupabaseService.cacheSessionEsCapitan(res?['es_capitan'] == true);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          FCMService.registrarDispositivo();
          NotificacionSonidoListener.reiniciar();
          ViajeGpsCoordinator().resumeIfNeeded();
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error en SessionWrapper al cargar perfil: $e');
      if (mounted) {
        setState(() {
          _isLoadingPerfil = false;
          _initialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _currentSession;

    // Sin sesión: mostrar login de inmediato (no esperar branding ni perfil).
    if (session == null) {
      return const BienvenidaDefinitivaScreen();
    }

    if (_passwordRecoveryPending) {
      return NuevaPasswordScreen(
        onCompletado: () {
          if (mounted) {
            setState(() => _passwordRecoveryPending = false);
          }
        },
      );
    }

    if (!_initialized || (_isLoadingPerfil && _perfil == null)) {
      return const Scaffold(
        backgroundColor: Color(0xFF001A33),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00E676)),
        ),
      );
    }

    final bool isAdmin =
        (session.user.email == 'admin@elguiaya.com') ||
        (session.user.email == 'admin@capitanya.com') || // compatibilidad legacy
        (session.user.userMetadata?['rol'] == 'admin') ||
        (_perfil != null && _perfil!['admin'] == true);

    if (isAdmin) return const AdminDashboardScreen();

    if (EmailVerificationPolicy.requiresEmailVerification(session.user)) {
      final email = session.user.email ?? '';
      return VerificarEmailScreen(email: email);
    }

    final perfil = _perfil;
    if (perfil != null) {
      final bool esCapitan = perfil['es_capitan'] == true;
      final String estado = perfil['estado'] ?? 'pendiente';

      if (esCapitan && estado == 'pendiente') {
        return const BienvenidaDefinitivaScreen();
      }

      if (esCapitan) return const PortalCapitanScreen();
      return const PortalPescadorScreen();
    }

    return const BienvenidaDefinitivaScreen();
  }
}

class ProductDetailRouteWrapper extends StatefulWidget {
  final String productId;
  const ProductDetailRouteWrapper({super.key, required this.productId});

  @override
  State<ProductDetailRouteWrapper> createState() => _ProductDetailRouteWrapperState();
}

class _ProductDetailRouteWrapperState extends State<ProductDetailRouteWrapper> {
  bool _loading = true;
  String? _error;
  Producto? _producto;

  @override
  void initState() {
    super.initState();
    _cargarProducto();
  }

  Future<void> _cargarProducto() async {
    try {
      final res = await Supabase.instance.client
          .from('productos')
          .select()
          .eq('id', widget.productId)
          .maybeSingle();

      if (!mounted) return;

      if (res == null) {
        setState(() {
          _error = 'El producto no existe o no está disponible.';
          _loading = false;
        });
      } else {
        setState(() {
          _producto = Producto.fromSupabase(res);
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al cargar el producto: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF000D26),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
          ),
        ),
      );
    }

    if (_error != null || _producto == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF000D26),
        appBar: AppBar(
          title: const Text('Error de Carga'),
          backgroundColor: const Color(0xFF001F3F),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _error ?? 'Producto no encontrado',
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return ProductDetailScreen(producto: _producto!);
  }
}
