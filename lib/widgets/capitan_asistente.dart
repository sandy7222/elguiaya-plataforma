import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

enum CapitanState {
  aparece,
  desaparece,
  saludo,
  durmiendo,
  despierta,
  piensaLeve,
  piensaProfundo,
  escuchando,
  soloEscucha,   // ⭐ Solo escucha sin hablar
  duda,
  explica,
  exito,
  chiste,
  hablaConMate,
  tomaMate,
  juegaCartas,
  // Estados emocionales para el Truco
  rieGana,
  enojado,
  asombrado,
  triste,
}

class CapitanAsistente extends StatefulWidget {
  final CapitanState estado;
  final double width;
  final double height;

  const CapitanAsistente({
    Key? key,
    this.estado = CapitanState.durmiendo,
    this.width = 250,
    this.height = 250,
  }) : super(key: key);

  @override
  State<CapitanAsistente> createState() => _CapitanAsistenteState();
}

class _CapitanAsistenteState extends State<CapitanAsistente> {
  Timer? _transitionTimer;
  String _currentGif = '';
  CapitanState? _pendingState;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _currentGif = _getDefaultGifPath(widget.estado);
    _updateGifPath(widget.estado, isInitial: true);
    // Pre-cargar TODOS los GIFs al inicio para que nunca haya flash blanco
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        for (final gif in [
          'assets/gifs/nace_como_aladino.gif',
          'assets/gifs/hace_un_rayo_y_se_esfuma.gif',
          'assets/gifs/se_rie_y_saluda_al_frente.gif',
          'assets/gifs/duerme.gif',
          'assets/gifs/se_despierte_y_queda_de_pie.gif',
          'assets/gifs/solo_piensa.gif',
          'assets/gifs/piensa_y_mira_arriba.gif',
          'assets/gifs/escucha_mientras_habla.gif',
          'assets/gifs/solo_escucha.gif',
          'assets/gifs/carita_de_pregunta_y_habla.gif',
          'assets/gifs/habla_y_explica.gif',
          'assets/gifs/habla_convencido_y_hace_ok.gif',
          'assets/gifs/chiste_y_rie.gif',
          'assets/gifs/habla_con_mate.gif',
          'assets/gifs/habla_y_ceba_mate.gif',
          'assets/gifs/ceba_mate_y_toma.gif',
          'assets/gifs/habla_y_juega_cartas.gif',
          'assets/gifs/se_rie_fuerte.gif',
          'assets/gifs/furioso.gif',
          'assets/gifs/triste.gif',
          'assets/gifs/bosteza_y_se_duerme.gif',
        ]) {
          precacheImage(AssetImage(gif), context);
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant CapitanAsistente oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.estado != widget.estado) {
      _updateGifPath(widget.estado);
    }
  }

  @override
  void dispose() {
    _transitionTimer?.cancel();
    super.dispose();
  }

  void _updateGifPath(CapitanState state, {bool isInitial = false}) {
    // Si estamos en plena animación de despertarse y entra una acción activa (no dormir ni desaparecer),
    // simplemente guardamos el nuevo estado de destino para cuando termine la animación de despertar.
    if (!isInitial &&
        _currentGif == 'assets/gifs/se_despierte_y_queda_de_pie.gif' &&
        state != CapitanState.durmiendo &&
        state != CapitanState.desaparece) {
      _pendingState = state;
      return;
    }

    _transitionTimer?.cancel();
    _pendingState = null;

    // Si el estado es desaparecer, cancelamos todo y mostramos la animación de irse inmediatamente
    if (state == CapitanState.desaparece) {
      _precacheGif('assets/gifs/hace_un_rayo_y_se_esfuma.gif');
      setState(() {
        _currentGif = 'assets/gifs/hace_un_rayo_y_se_esfuma.gif';
      });
      return;
    }

    // Si el personaje estaba durmiendo y pasa a cualquier otro estado activo,
    // primero mostramos la animación de despertarse.
    bool wasSleeping = !isInitial &&
        (_currentGif == 'assets/gifs/bosteza_y_se_duerme.gif' ||
            _currentGif == 'assets/gifs/duerme.gif');

    if (wasSleeping && state != CapitanState.durmiendo) {
      _pendingState = state;
      _precacheGif('assets/gifs/se_despierte_y_queda_de_pie.gif');
      setState(() {
        _currentGif = 'assets/gifs/se_despierte_y_queda_de_pie.gif';
      });

      // Después de 8.1 segundos (duración del GIF de despertar), mostramos la acción pendiente
      _transitionTimer = Timer(const Duration(milliseconds: 8100), () {
        if (mounted) {
          final nextGif = _getDefaultGifPath(_pendingState ?? state);
          _precacheGif(nextGif);
          setState(() {
            _currentGif = nextGif;
            _pendingState = null;
          });
        }
      });
      return;
    }

    if (state == CapitanState.durmiendo) {
      // Si ya está en la secuencia de sueño, no la interrumpimos
      if (!isInitial &&
          (_currentGif == 'assets/gifs/bosteza_y_se_duerme.gif' ||
              _currentGif == 'assets/gifs/duerme.gif')) {
        return;
      }

      _precacheGif('assets/gifs/bosteza_y_se_duerme.gif');
      _precacheGif('assets/gifs/duerme.gif');
      setState(() {
        _currentGif = 'assets/gifs/bosteza_y_se_duerme.gif';
      });

      // A los 12.8 segundos (duración del bostezo), pasamos al bucle continuo de sueño
      _transitionTimer = Timer(const Duration(milliseconds: 12800), () {
        if (mounted) {
          setState(() {
            _currentGif = 'assets/gifs/duerme.gif';
          });
        }
      });
    } else {
      final nextGif = _getDefaultGifPath(state);
      _precacheGif(nextGif);
      setState(() {
        _currentGif = nextGif;
      });
    }
  }

  String _getDefaultGifPath(CapitanState state) {
    switch (state) {
      case CapitanState.aparece:
        return 'assets/gifs/nace_como_aladino.gif';
      case CapitanState.desaparece:
        return 'assets/gifs/hace_un_rayo_y_se_esfuma.gif';
      case CapitanState.saludo:
        return 'assets/gifs/se_rie_y_saluda_al_frente.gif';
      case CapitanState.durmiendo:
        return 'assets/gifs/duerme.gif';
      case CapitanState.despierta:
        return 'assets/gifs/se_despierte_y_queda_de_pie.gif';
      case CapitanState.piensaLeve:
        return 'assets/gifs/solo_piensa.gif';
      case CapitanState.piensaProfundo:
        return 'assets/gifs/piensa_y_mira_arriba.gif';
      case CapitanState.escuchando:
        return 'assets/gifs/escucha_mientras_habla.gif';
      case CapitanState.soloEscucha:
        return 'assets/gifs/solo_escucha.gif';
      case CapitanState.duda:
        return 'assets/gifs/carita_de_pregunta_y_habla.gif';
      case CapitanState.explica:
        return 'assets/gifs/habla_y_explica.gif';
      case CapitanState.exito:
        return 'assets/gifs/habla_convencido_y_hace_ok.gif';
      case CapitanState.chiste:
        return 'assets/gifs/chiste_y_rie.gif';
      case CapitanState.hablaConMate:
        // Alterna aleatoriamente entre los dos GIFs de "habla con mate"
        return _random.nextBool()
            ? 'assets/gifs/habla_con_mate.gif'
            : 'assets/gifs/habla_y_ceba_mate.gif';
      case CapitanState.tomaMate:
        // Alterna aleatoriamente entre los dos GIFs de reposo con mate
        return _random.nextBool()
            ? 'assets/gifs/ceba_mate_y_toma.gif'
            : 'assets/gifs/habla_y_ceba_mate.gif';
      case CapitanState.juegaCartas:
        return 'assets/gifs/habla_y_juega_cartas.gif';
      case CapitanState.rieGana:
        return 'assets/gifs/se_rie_fuerte.gif';
      case CapitanState.enojado:
        return 'assets/gifs/furioso.gif';
      case CapitanState.asombrado:
        return 'assets/gifs/carita_de_pregunta_y_habla.gif';
      case CapitanState.triste:
        return 'assets/gifs/triste.gif';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedSwitcher(
        // Crossfade de 200ms: el GIF viejo sigue visible mientras el nuevo carga
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: Image.asset(
          _currentGif,
          key: ValueKey<String>(_currentGif),
          fit: BoxFit.contain,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            // Si ya cargó, mostramos la imagen
            if (wasSynchronouslyLoaded || frame != null) {
              return child;
            }
            // Mientras carga, mantenemos el mismo espacio para evitar colapsos y destellos
            return SizedBox(
              width: widget.width,
              height: widget.height,
            );
          },
          errorBuilder: (context, error, stackTrace) {
            // En caso de error, mostramos un contenedor transparente vacío en vez de un recuadro de error
            return SizedBox(
              width: widget.width,
              height: widget.height,
            );
          },
        ),
      ),
    );
  }

  /// Pre-carga un GIF en memoria antes de mostrarlo para evitar el flash blanco
  void _precacheGif(String path) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        precacheImage(AssetImage(path), context);
      }
    });
  }
}
