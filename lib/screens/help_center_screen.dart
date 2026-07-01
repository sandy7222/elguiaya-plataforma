import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/safe_button.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  final FocusNode _searchFocusNode = FocusNode();
  bool _showSuggestions = false;

  // Categor�as de FAQs
  final String _catEnvios = "Envíos";
  final String _catPagos = "Pagos";
  final String _catCambios = "Cambios";
  final String _catCancelaciones = "Cancelaciones";

  // Lista de FAQs
  late List<FaqItem> _faqs;
  List<FaqItem> _filteredFaqs = [];

  // Categor�a seleccionada por filtro r�pido
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _faqs = [
      FaqItem(
        category: _catEnvios,
        question: '�Cuánto tarda en llegar mi pedido?',
        answer: 'Los envíos a CABA y GBA demoran entre 24 y 48 horas h�biles. Al interior del país, el plazo es de 3 a 5 días h�biles a trav�s de Andreani.',
      ),
      FaqItem(
        category: _catEnvios,
        question: '�Cómo realizo el seguimiento de mi envío?',
        answer: 'Una vez despachado el producto, te enviaremos un email con el c�digo de seguimiento de Andreani. Tambi�n podés verlo en la sección "Mis Compras" dentro de tu perfil.',
      ),
      FaqItem(
        category: _catEnvios,
        question: '�Puedo retirar mi compra en una sucursal?',
        answer: 'Sí, ofrecemos retiro sin cargo en nuestro centro de distribución de San Fernando, Tigre o Rosario, de lunes a viernes de 9:00 a 18:00 hs.',
      ),
      FaqItem(
        category: _catPagos,
        question: '�Qué medios de pago aceptan?',
        answer: 'Aceptamos todas las tarjetas de crédito y débito a trav�s de Mercado Pago. Tambi�n podés abonar con dinero en cuenta de Mercado Pago o mediante transferencia bancaria con un 10% de descuento.',
      ),
      FaqItem(
        category: _catPagos,
        question: '�Puedo pagar en cuotas?',
        answer: 'Sí, ofrecemos hasta 3 cuotas sin inter�s con bancos seleccionados a trav�s de Mercado Pago y promociones bancarias vigentes que podés ver al momento de abonar.',
      ),
      FaqItem(
        category: _catPagos,
        question: '�Cómo solicito mi factura A?',
        answer: 'Durante el proceso de checkout podés ingresar tu CUIT y razón social para que nuestro sistema emita autom�ticamente la factura tipo A.',
      ),
      FaqItem(
        category: _catCambios,
        question: '�Cu�l es el plazo para realizar un cambio?',
        answer: 'Ten�s hasta 30 días corridos desde que recibiste el producto para solicitar un cambio por talle, color o modelo, siempre que el producto está sin uso y en su empaque original.',
      ),
      FaqItem(
        category: _catCambios,
        question: '�Qué costo tiene realizar un cambio?',
        answer: 'El primer cambio por talle o falla de f�brica es totalmente gratuito. Para cambios posteriores o devoluciones por arrepentimiento, el cliente asume el costo de envío.',
      ),
      FaqItem(
        category: _catCambios,
        question: '�Cómo gestiono una devolución?',
        answer: 'Pod�s iniciar la devolución directamente desde la app en "Mis Compras" o contactando a nuestro soporte. Te enviaremos una etiqueta de correo para despachar el paquete de retorno sin cargo.',
      ),
      FaqItem(
        category: _catCancelaciones,
        question: '�Puedo cancelar un pedido antes de recibirlo?',
        answer: 'Sí, siempre y cuando el pedido no haya sido despachado. Pod�s solicitar la cancelación inmediata desde tu panel de control o por soporte de WhatsApp.',
      ),
      FaqItem(
        category: _catCancelaciones,
        question: '�Cuánto demora en acreditarse mi reembolso?',
        answer: 'Una vez aprobada la devolución o cancelación, el reembolso se procesa de inmediato. Si pagaste con dinero en Mercado Pago se acredita al instante; si fue con tarjeta de crédito, puede demorar entre 2 y 10 días h�biles dependiendo del banco emisor.',
      ),
    ];
    _filteredFaqs = List.from(_faqs);

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _updateFilters();
      });
    });

    _searchFocusNode.addListener(() {
      setState(() {
        _showSuggestions = _searchFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _updateFilters() {
    if (_searchQuery.trim().isEmpty) {
      if (_selectedCategory == null) {
        _filteredFaqs = List.from(_faqs);
      } else {
        _filteredFaqs = _faqs.where((f) => f.category == _selectedCategory).toList();
      }
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredFaqs = _faqs.where((f) {
        final matchesQuery = f.question.toLowerCase().contains(query) || f.answer.toLowerCase().contains(query);
        final matchesCategory = _selectedCategory == null || f.category == _selectedCategory;
        return matchesQuery && matchesCategory;
      }).toList();
    }
  }

  void _selectCategoryFilter(String? category) {
    setState(() {
      if (_selectedCategory == category) {
        _selectedCategory = null; // Toggle off
      } else {
        _selectedCategory = category;
        _searchFocusNode.unfocus();
        _showSuggestions = false;
      }
      _updateFilters();
    });
  }

  void _selectSuggestion(FaqItem faq) {
    setState(() {
      _searchController.text = faq.question;
      _searchQuery = faq.question;
      _showSuggestions = false;
      _searchFocusNode.unfocus();
      // Expand target FAQ and collapse others
      for (var f in _faqs) {
        f.isExpanded = (f.question == faq.question);
      }
      _updateFilters();
    });
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = "";
      _showSuggestions = false;
      _updateFilters();
    });
  }

  Future<void> _launchWhatsApp() async {
    final url = Uri.parse("https://wa.me/5491122334455?text=Hola,%20necesito%20ayuda%20con%20una%20compra%20en%20CapitánYA");
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: const Color(0xFF001A33),
      appBar: AppBar(
        backgroundColor: const Color(0xFF001A33),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Icon(Icons.anchor_rounded, color: Color(0xFF00E676), size: 24),
            const SizedBox(width: 8),
            Text(
              'CENTRO DE AYUDA',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: GestureDetector(
        onTap: () {
          _searchFocusNode.unfocus();
          setState(() {
            _showSuggestions = false;
          });
        },
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 1. CABECERA CON BUSCADOR
              _buildHeaderSearchSection(isMobile),

              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16.0 : MediaQuery.of(context).size.width * 0.15,
                  vertical: 32.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. GRILLA DE ACCESOS R�PIDOS
                    _buildQuickAccessGrid(isMobile),
                    const SizedBox(height: 48),

                    // Encabezado de la lista FAQ
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedCategory == null
                              ? 'PREGUNTAS FRECUENTES'
                              : 'PREGUNTAS SOBRE ${_selectedCategory!.toUpperCase()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        if (_selectedCategory != null || _searchQuery.isNotEmpty)
                          SafeTextIconButton(
  onPressed: () {
                              setState(() {
                                _selectedCategory = null;
                                _clearSearch();
                              });
                            },
  icon: Icons.refresh_rounded,
  iconSize: 16,
  iconColor: const Color(0xFF00E676),
  label: 'VER TODAS',
  textStyle: TextStyle(color: Color(0xFF00E676), fontSize: 12, fontWeight: FontWeight.bold),
),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 3. ACORDE�N DE FAQ DINºMICO
                    _buildFaqAccordion(),

                    const SizedBox(height: 54),

                    // 4. BOTÓN DE ESCAPE
                    _buildEscapeBanner(isMobile),
                  ],
                ),
              ),

              // Footer oscuro integrado para coherencia visual
              _buildSimpleFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSearchSection(bool isMobile) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF001A33),
            Color(0xFF002D59),
          ],
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 20.0,
        vertical: isMobile ? 32.0 : 54.0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            children: [
              Text(
                '�Cómo podemos ayudarte hoy, chamigo?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: isMobile ? 20 : 28,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Navegá entre las dudas comunes de compras, pagos y despachos.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: isMobile ? 12 : 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Buscador con sugerencias
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _searchFocusNode.hasFocus 
                            ? const Color(0xFF00E676) 
                            : Colors.white24,
                        width: 1.5,
                      ),
                      boxShadow: _searchFocusNode.hasFocus
                          ? [
                              BoxShadow(
                                color: const Color(0xFF00E676).withOpacity(0.15),
                                blurRadius: 12,
                                spreadRadius: 1,
                              )
                            ]
                          : [],
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '�Qué pasa con tu compra? Buscá tu duda acá...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 22),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                                onPressed: _clearSearch,
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),

                  // Dropdown de sugerencias autom�ticas
                  if (_showSuggestions && _searchQuery.trim().isNotEmpty)
                    Positioned(
                      top: 58,
                      left: 0,
                      right: 0,
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 280),
                        decoration: BoxDecoration(
                          color: const Color(0xFF002547),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: ListView(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              children: _faqs
                                  .where((f) =>
                                      f.question.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                                      f.answer.toLowerCase().contains(_searchQuery.toLowerCase()))
                                  .map((faq) => InkWell(
                                        onTap: () => _selectSuggestion(faq),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                          child: Row(
                                            children: [
                                              Icon(
                                                faq.category == _catEnvios
                                                    ? Icons.local_shipping_outlined
                                                    : faq.category == _catPagos
                                                        ? Icons.credit_card_rounded
                                                        : faq.category == _catCambios
                                                            ? Icons.loop_rounded
                                                            : Icons.error_outline_rounded,
                                                color: const Color(0xFF00E676),
                                                size: 16,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  faq.question,
                                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 10),
                                            ],
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAccessGrid(bool isMobile) {
    final double spacing = isMobile ? 12.0 : 18.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ACCESOS R�PIDOS',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final double width = (constraints.maxWidth - (isMobile ? spacing : spacing * 3)) / (isMobile ? 2 : 4);
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                _buildQuickCard(
                  title: 'Mi Envío / Seguimiento',
                  subtitle: 'Estado de entrega Andreani',
                  icon: Icons.local_shipping_outlined,
                  category: _catEnvios,
                  width: width,
                ),
                _buildQuickCard(
                  title: 'Pagos y Facturaci�n',
                  subtitle: 'Mercado Pago y Factura A',
                  icon: Icons.credit_card_rounded,
                  category: _catPagos,
                  width: width,
                ),
                _buildQuickCard(
                  title: 'Cambios y Devoluciones',
                  subtitle: 'Plazos y costos de envío',
                  icon: Icons.loop_rounded,
                  category: _catCambios,
                  width: width,
                ),
                _buildQuickCard(
                  title: 'Cancelaciones y Reembolsos',
                  subtitle: 'Arrepentimiento y plazos bancarios',
                  icon: Icons.error_outline_rounded,
                  category: _catCancelaciones,
                  width: width,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String category,
    required double width,
  }) {
    final isSelected = _selectedCategory == category;

    bool isHovered = false;
    return StatefulBuilder(
      builder: (context, setCardState) {
        return MouseRegion(
          onEnter: (_) => setCardState(() => isHovered = true),
          onExit: (_) => setCardState(() => isHovered = false),
          child: InkWell(
            onTap: () => _selectCategoryFilter(category),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: width,
              height: 130,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF00E676).withOpacity(0.08)
                    : Colors.white.withOpacity(isHovered ? 0.04 : 0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF00E676)
                      : const Color(0xFF00E676).withOpacity(isHovered ? 0.4 : 0.15),
                  width: isSelected ? 1.8 : 1.0,
                ),
                boxShadow: isHovered || isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00E676).withOpacity(isSelected ? 0.12 : 0.06),
                          blurRadius: 10,
                          spreadRadius: 1,
                        )
                      ]
                    : [],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    icon,
                    color: isSelected || isHovered ? const Color(0xFF00E676) : Colors.white70,
                    size: 26,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFaqAccordion() {
    if (_filteredFaqs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded, color: Colors.white38, size: 40),
            const SizedBox(height: 12),
            Text(
              'No encontramos resultados para tu búsqueda.',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _clearSearch,
              child: const Text('Limpiar búsqueda', style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredFaqs.length,
      itemBuilder: (context, index) {
        final faq = _filteredFaqs[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(faq.isExpanded ? 0.04 : 0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: faq.isExpanded 
                  ? const Color(0xFF00E676).withOpacity(0.5) 
                  : Colors.white.withOpacity(0.08),
              width: faq.isExpanded ? 1.5 : 1.0,
            ),
            boxShadow: faq.isExpanded
                ? [
                    BoxShadow(
                      color: const Color(0xFF00E676).withOpacity(0.05),
                      blurRadius: 10,
                    )
                  ]
                : [],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              hoverColor: Colors.transparent,
            ),
            child: ExpansionTile(
              initiallyExpanded: faq.isExpanded,
              onExpansionChanged: (expanded) {
                setState(() {
                  faq.isExpanded = expanded;
                });
              },
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: faq.isExpanded 
                      ? const Color(0xFF00E676).withOpacity(0.1) 
                      : Colors.white.withOpacity(0.04),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  faq.category == _catEnvios
                      ? '??'
                      : faq.category == _catPagos
                          ? '??'
                          : faq.category == _catCambios
                              ? '??'
                              : '?',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              title: Text(
                faq.question,
                style: TextStyle(
                  color: faq.isExpanded ? const Color(0xFF00E676) : Colors.white,
                  fontSize: 13.5,
                  fontWeight: faq.isExpanded ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
              trailing: Icon(
                faq.isExpanded 
                    ? Icons.keyboard_arrow_up_rounded 
                    : Icons.keyboard_arrow_down_rounded,
                color: faq.isExpanded ? const Color(0xFF00E676) : Colors.white54,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 20.0),
                  child: Text(
                    faq.answer,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEscapeBanner(bool isMobile) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF002547).withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF00E676).withOpacity(0.25),
          width: 1.5,
        ),
      ),
      padding: EdgeInsets.all(isMobile ? 20.0 : 32.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.support_agent_rounded, color: Color(0xFF00E676), size: 28),
              SizedBox(width: 8),
              Text(
                'SOPORTE 24/7',
                style: TextStyle(
                  color: Color(0xFF00E676),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '�No encontraste lo que buscabas?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Charlá con un tripulante del equipo de soporte en tiempo real.',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SafeElevatedIconButton(
  onPressed: _launchWhatsApp,
  icon: Icons.chat_bubble_outline_rounded,
  iconSize: 18,
  label: 'HABLAR CON SOPORTE',
  textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
  style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
              elevation: 4,
            ),
),
        ],
      ),
    );
  }

  Widget _buildSimpleFooter() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      child: Column(
        children: [
          const Icon(Icons.anchor_rounded, color: Colors.white30, size: 28),
          const SizedBox(height: 8),
          Text(
            'EL GUIA YA � Tienda Oficial',
            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}

class FaqItem {
  final String category;
  final String question;
  final String answer;
  bool isExpanded;

  FaqItem({
    required this.category,
    required this.question,
    required this.answer,
    this.isExpanded = false,
  });
}
