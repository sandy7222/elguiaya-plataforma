

import 'dart:math';

class StressTestService {
  static final Random _random = Random();
  
  // Datos de prueba para pescadores
  static final List<Map<String, dynamic>> _pescadoresPrueba = [
    {
      'nombre': 'Carlos Martinez',
      'email': 'carlos.martinez@email.com',
      'telefono': '+54 9 11 1234-5678',
      'experiencia': 'principiante',
    },
    {
      'nombre': 'Ana Rodriguez',
      'email': 'ana.rodriguez@email.com',
      'telefono': '+54 9 11 2345-6789',
      'experiencia': 'intermedio',
    },
    {
      'nombre': 'Luis Fernandez',
      'email': 'luis.fernandez@email.com',
      'telefono': '+54 9 11 3456-7890',
      'experiencia': 'avanzado',
    },
    {
      'nombre': 'Maria Gonzalez',
      'email': 'maria.gonzalez@email.com',
      'telefono': '+54 9 11 4567-8901',
      'experiencia': 'principiante',
    },
    {
      'nombre': 'Diego Silva',
      'email': 'diego.silva@email.com',
      'telefono': '+54 9 11 5678-9012',
      'experiencia': 'intermedio',
    },
  ];
  
  // Datos de prueba para viajes
  static final List<Map<String, dynamic>> _viajesPrueba = [
    {
      'nombre': 'Viaje a Puerto Piramides',
      'tipo': 'desde costa',
      'duracion': '12',
      'presupuesto_min': 45000.0,
      'presupuesto_max': 85000.0,
      'destino': 'Puerto Piramides',
    },
    {
      'nombre': 'Viaje a San Clemente',
      'tipo': 'pesca de tiburon',
      'duracion': '8',
      'presupuesto_min': 80000.0,
      'presupuesto_max': 150000.0,
      'destino': 'San Clemente',
    },
    {
      'nombre': 'Viaje a Mar del Plata',
      'tipo': 'pesca nocturna',
      'duracion': '10',
      'presupuesto_min': 35000.0,
      'presupuesto_max': 75000.0,
      'destino': 'Mar del Plata',
    },
    {
      'nombre': 'Viaje a Neuquen',
      'tipo': 'pesca de dorado',
      'duracion': '6',
      'presupuesto_min': 25000.0,
      'presupuesto_max': 55000.0,
      'destino': 'Neuquen',
    },
    {
      'nombre': 'Viaje a Ushuaia',
      'tipo': 'desde embarcacion',
      'duracion': '14',
      'presupuesto_min': 120000.0,
      'presupuesto_max': 200000.0,
      'destino': 'Ushuaia',
    },
  ];
  
  // Equipamiento disponible
  static final List<String> _equipamientoOpciones = [
    'cana', 'carrete', 'anzuelos', 'equipo completo',
    'cana nocturna', 'sonar', 'silla de pesca', 'carnada'
  ];
  
  // Generar solicitud de prueba
  static Map<String, dynamic> generarSolicitudPrueba(int index) {
    final pescador = _pescadoresPrueba[index % _pescadoresPrueba.length];
    final viaje = _viajesPrueba[index % _viajesPrueba.length];
    final numeroPescadores = _random.nextInt(4) + 1; // 1-4 pescadores
    final presupuesto = viaje['presupuesto_min'] + 
        (_random.nextDouble() * (viaje['presupuesto_max'] - viaje['presupuesto_min']));
    
    // Seleccionar equipamiento aleatorio
    final equipamiento = <String>[];
    final numEquipamiento = _random.nextInt(4) + 1; // 1-4 items
    final equipamientoDisponible = List<String>.from(_equipamientoOpciones);
    equipamientoDisponible.shuffle(_random);
    
    for (int i = 0; i < numEquipamiento && i < equipamientoDisponible.length; i++) {
      equipamiento.add(equipamientoDisponible[i]);
    }
    
    // Generar fecha (entre hoy y 30 dias)
    final diasAdelante = _random.nextInt(30) + 1;
    final fechaSolicitada = DateTime.now().add(Duration(days: diasAdelante));
    
    // Mensaje personalizado segun experiencia
    String mensaje = '';
    switch (pescador['experiencia']) {
      case 'principiante':
        mensaje = 'Hola, soy ${pescador['nombre']}. Soy principiante en la pesca y me gustaria hacer un viaje a ${viaje['destino']}. Necesito guia y equipo basico. Mi presupuesto es de \$${presupuesto.toStringAsFixed(0)}. ¿Podrian ayudarme?';
        break;
      case 'intermedio':
        mensaje = 'Hola, soy ${pescador['nombre']}. Tengo experiencia intermedia y busco un viaje a ${viaje['destino']} para practicar ${viaje['tipo']}. Necesito equipo especializado. Presupuesto \$${presupuesto.toStringAsFixed(0)}.';
        break;
      case 'avanzado':
        mensaje = 'Hola, soy ${pescador['nombre']}. Soy pescador avanzado y busco un desafio en ${viaje['destino']}. Interesado en ${viaje['tipo']}. Presupuesto \$${presupuesto.toStringAsFixed(0)}.';
        break;
    }
    
    return {
      'id': 'sol-stress-${DateTime.now().millisecondsSinceEpoch}-$index',
      'pescador_id': 'pescador-stress-$index',
      'pescador_nombre': pescador['nombre'],
      'pescador_email': pescador['email'],
      'pescador_telefono': pescador['telefono'],
      'viaje_id': 'viaje-stress-$index',
      'viaje_nombre': viaje['nombre'],
      'viaje_fecha_solicitada': '${fechaSolicitada.day.toString().padLeft(2, '0')}/${fechaSolicitada.month.toString().padLeft(2, '0')}/${fechaSolicitada.year}',
      'viaje_duracion': '${viaje['duracion']} horas',
      'viaje_tipo_pesca': viaje['tipo'],
      'numero_pescadores': numeroPescadores,
      'equipamiento_requerido': equipamiento,
      'experiencia_nivel': pescador['experiencia'],
      'presupuesto_estimado': presupuesto,
      'mensaje_pescador': mensaje,
      'status': 'pendiente',
      'fecha_solicitud': DateTime.now().toIso8601String(),
      'fecha_respuesta': null,
      'precio_cotizado': null,
      'respuesta_capitan': null,
      'destino': viaje['destino'],
    };
  }
  
  // Simular envio de 5 solicitudes
  static Future<List<Map<String, dynamic>>> enviarSolicitudesStressTest() async {
    print('🚀 INICIANDO PRUEBA DE ESTRES - Envio de 5 solicitudes');
    print('=' * 60);
    
    final solicitudes = <Map<String, dynamic>>[];
    
    for (int i = 0; i < 5; i++) {
      print('\n📤 Enviando solicitud ${i + 1}/5...');
      
      // Generar solicitud
      final solicitud = generarSolicitudPrueba(i);
      solicitudes.add(solicitud);
      
      // Simular envio a Supabase
      await Future.delayed(Duration(milliseconds: 500 + _random.nextInt(1000)));
      
      print('✅ Solicitud ${i + 1} enviada:');
      print('   📧 Pescador: ${solicitud['pescador_nombre']}');
      print('   🎯 Destino: ${solicitud['destino']}');
      print('   💰 Presupuesto: \$${solicitud['presupuesto_estimado'].toStringAsFixed(0)}');
      print('   👥 N° Pescadores: ${solicitud['numero_pescadores']}');
      print('   🎣 Tipo: ${solicitud['viaje_tipo_pesca']}');
      print('   📅 Fecha: ${solicitud['viaje_fecha_solicitada']}');
      print('   📦 Equipamiento: ${solicitud['equipamiento_requerido'].join(', ')}');
      print('   📝 Mensaje: "${solicitud['mensaje_pescador']}"');
    }
    
    print('\n✅ PRUEBA DE ESTRES COMPLETADA - 5 solicitudes enviadas');
    print('=' * 60);
    
    return solicitudes;
  }
  
  // Simular respuesta del capitan
  static Future<Map<String, dynamic>> responderSolicitudStressTest(Map<String, dynamic> solicitud) async {
    print('\n📋 PROCESANDO RESPUESTA DEL CAPITAN');
    print('-' * 40);
    
    // Calcular precio basado en factores
    final basePrice = solicitud['presupuesto_estimado'] as double;
    final numPescadores = solicitud['numero_pescadores'] as int;
    final experiencia = solicitud['experiencia_nivel'] as String;
    
    // Ajuste por experiencia
    double experienciaFactor = 1.0;
    switch (experiencia) {
      case 'principiante':
        experienciaFactor = 1.2; // +20% por guia extra
        break;
      case 'intermedio':
        experienciaFactor = 1.0;
        break;
      case 'avanzado':
        experienciaFactor = 0.9; // -10% (necesita menos guia)
        break;
    }
    
    // Ajuste por numero de pescadores
    final grupoFactor = 1.0 + ((numPescadores - 1) * 0.1); // +10% por pescador adicional
    
    final precioFinal = basePrice * experienciaFactor * grupoFactor;
    
    // Generar respuesta personalizada
    String respuesta = '';
    switch (experiencia) {
      case 'principiante':
        respuesta = '¡Hola ${solicitud['pescador_nombre']}! Perfecto para principiantes. Te ofrezco un paquete completo con guia especializada, equipo para principiantes, y tecnicas basicas. Incluye transporte desde Capital y carnada. El viaje a ${solicitud['destino']} sera una experiencia inolvidable.';
        break;
      case 'intermedio':
        respuesta = '¡Hola ${solicitud['pescador_nombre']}! Excelente eleccion para tu nivel. Te ofrezco equipo de calidad intermedia con tecnicas avanzadas de ${solicitud['viaje_tipo_pesca']}. Incluye guia especializada y los mejores spots de ${solicitud['destino']}.';
        break;
      case 'avanzado':
        respuesta = '¡Hola ${solicitud['pescador_nombre']}! Veo que buscas un desafio. Te ofrezco equipo premium y acceso a zonas exclusivas de ${solicitud['destino']}. Para tu nivel, tengo tecnicas avanzadas y spots poco conocidos para ${solicitud['viaje_tipo_pesca']}.';
        break;
    }
    
    // Simular procesamiento
    await Future.delayed(Duration(milliseconds: 800 + _random.nextInt(500)));
    
    final respuestaData = {
      'solicitud_id': solicitud['id'],
      'precio_cotizado': precioFinal,
      'respuesta_capitan': respuesta,
      'fecha_respuesta': DateTime.now().toIso8601String(),
      'status': 'respondido',
    };
    
    print('✅ Respuesta generada:');
    print('   💰 Precio cotizado: \$${precioFinal.toStringAsFixed(0)}');
    print('   📄 Respuesta: "$respuesta"');
    print('   📅 Fecha respuesta: ${respuestaData['fecha_respuesta']}');
    
    return respuestaData;
  }
  
  // Simular proceso de pago
  static Future<Map<String, dynamic>> procesarPagoStressTest(String cotizacionId, double monto) async {
    print('\n💳 PROCESANDO PAGO');
    print('-' * 30);
    
    // Simular procesamiento de pago
    await Future.delayed(Duration(milliseconds: 1000 + _random.nextInt(1000)));
    
    // Crear pagos diferidos segun monto
    final pagos = <Map<String, dynamic>>[];
    
    if (monto <= 50000) {
      // Pago unico
      pagos.add({
        'id': 'pago-${DateTime.now().millisecondsSinceEpoch}',
        'monto': monto,
        'fecha_vencimiento': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'status': 'pendiente',
      });
    } else if (monto <= 100000) {
      // 2 cuotas
      final cuota = monto / 2;
      for (int i = 1; i <= 2; i++) {
        pagos.add({
          'id': 'pago-${DateTime.now().millisecondsSinceEpoch}-$i',
          'monto': cuota,
          'fecha_vencimiento': DateTime.now().add(Duration(days: 30 * i)).toIso8601String(),
          'status': 'pendiente',
          'cuota': '$i/2',
        });
      }
    } else {
      // 3 cuotas
      final cuota = monto / 3;
      for (int i = 1; i <= 3; i++) {
        pagos.add({
          'id': 'pago-${DateTime.now().millisecondsSinceEpoch}-$i',
          'monto': cuota,
          'fecha_vencimiento': DateTime.now().add(Duration(days: 30 * i)).toIso8601String(),
          'status': 'pending',
          'cuota': '$i/3',
        });
      }
    }
    
    print('✅ Pagos generados:');
    for (final pago in pagos) {
      print('   💰 Cuota ${pago['cuota'] ?? 'unica'}: \$${pago['monto'].toStringAsFixed(0)}');
      print('   📅 Vencimiento: ${pago['fecha_vencimiento']}');
    }
    
    return {
      'cotizacion_id': cotizacionId,
      'monto_total': monto,
      'pagos_generados': pagos,
      'status': 'pagado',
    };
  }
  
  // Simular finalizacion de mision
  static Future<Map<String, dynamic>> finalizarMisionStressTest(String cotizacionId) async {
    print('\n🎯 FINALIZANDO MISION');
    print('-' * 25);
    
    // Simular proceso de finalizacion
    await Future.delayed(const Duration(milliseconds: 800));
    
    final finalizacion = {
      'cotizacion_id': cotizacionId,
      'fecha_finalizacion': DateTime.now().toIso8601String(),
      'status': 'finalizado',
      'mision_completada': true,
    };
    
    print('✅ Mision finalizada:');
    print('   🆔 Cotizacion: $cotizacionId');
    print('   📅 Fecha finalizacion: ${finalizacion['fecha_finalizacion']}');
    print('   ✅ Estado: ${finalizacion['status']}');
    
    return finalizacion;
  }
  
  // Simular puntuacion del pescador
  static Future<Map<String, dynamic>> puntuarServicioStressTest(
    String cotizacionId,
    int calificacion,
    String comentario,
  ) async {
    print('\n⭐ REGISTRANDO PUNTUACION');
    print('-' * 25);
    
    // Simular guardado en Supabase
    await Future.delayed(const Duration(milliseconds: 600));
    
    final puntuacion = {
      'cotizacion_id': cotizacionId,
      'calificacion': calificacion,
      'comentario': comentario,
      'fecha_puntuacion': DateTime.now().toIso8601String(),
      'guardado_en_supabase': true,
    };
    
    print('✅ Puntuacion guardada:');
    print('   🆔 Cotizacion: $cotizacionId');
    print('   ⭐ Calificacion: $calificacion/5');
    print('   💬 Comentario: "$comentario"');
    print('   📅 Fecha: ${puntuacion['fecha_puntuacion']}');
    print('   ✅ Guardado en Supabase: ${puntuacion['guardado_en_supabase']}');
    
    return puntuacion;
  }
  
  // Ejecutar prueba de estres completa
  static Future<Map<String, dynamic>> ejecutarPruebaDeEstresCompleta() async {
    print('\n🔥 INICIANDO PRUEBA DE ESTRES COMPLETA - Capitan YA');
    print('=' * 70);
    
    final resultados = <String, dynamic>{};
    
    try {
      // Paso 1: Enviar 5 solicitudes
      print('\n📍 PASO 1: Generacion de Solicitudes');
      final solicitudes = await enviarSolicitudesStressTest();
      resultados['solicitudes_enviadas'] = solicitudes;
      
      // Paso 2: Elegir una solicitud para procesar completamente
      final solicitudSeleccionada = solicitudes.first;
      print('\n📍 PASO 2: Seleccion de Solicitud');
      print('✅ Solicitud seleccionada: ${solicitudSeleccionada['id']}');
      print('   📧 Pescador: ${solicitudSeleccionada['pescador_nombre']}');
      print('   🎯 Destino: ${solicitudSeleccionada['destino']}');
      
      // Paso 3: Responder solicitud
      print('\n📍 PASO 3: Respuesta del Capitan');
      final respuesta = await responderSolicitudStressTest(solicitudSeleccionada);
      resultados['respuesta_capitan'] = respuesta;
      
      // Paso 4: Procesar pago
      print('\n📍 PASO 4: Proceso de Pago');
      final pago = await procesarPagoStressTest(
        solicitudSeleccionada['id'], 
        respuesta['precio_cotizado'],
      );
      resultados['pago_procesado'] = pago;
      
      // Paso 5: Finalizar mision
      print('\n📍 PASO 5: Finalizacion de Mision');
      final finalizacion = await finalizarMisionStressTest(solicitudSeleccionada['id']);
      resultados['mision_finalizada'] = finalizacion;
      
      // Paso 6: Puntuar servicio
      print('\n📍 PASO 6: Puntuacion del Servicio');
      final puntuacion = await puntuarServicioStressTest(
        solicitudSeleccionada['id'],
        5, // Calificacion perfecta para prueba
        'Excelente servicio, muy profesional y el capitan conoce los mejores lugares. El equipo era de primera calidad. ¡Volvere sin duda!',
      );
      resultados['puntuacion_registrada'] = puntuacion;
      
      // Resumen final
      print('\n🎉 PRUEBA DE ESTRES COMPLETADA EXITOSAMENTE');
      print('=' * 70);
      print('✅ Solicitudes enviadas: ${solicitudes.length}');
      print('✅ Solicitud procesada: ${solicitudSeleccionada['id']}');
      print('✅ Respuesta generada: \$${respuesta['precio_cotizado'].toStringAsFixed(0)}');
      print('✅ Pagos generados: ${pago['pagos_generados'].length}');
      print('✅ Mision finalizada: ${finalizacion['mision_completada']}');
      print('✅ Puntuacion guardada: ${puntuacion['calificacion']}/5');
      print('✅ Todos los pasos completados sin errores');
      
      resultados['prueba_completada'] = true;
      resultados['fecha_finalizacion'] = DateTime.now().toIso8601String();
      
      return resultados;
      
    } catch (e) {
      print('\n❌ ERROR EN PRUEBA DE ESTRES: $e');
      resultados['prueba_completada'] = false;
      resultados['error'] = e.toString();
      resultados['fecha_error'] = DateTime.now().toIso8601String();
      return resultados;
    }
  }
}
