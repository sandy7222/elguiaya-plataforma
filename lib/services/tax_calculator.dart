

class TaxCalculator {
  static const double IVA_RATE = 0.21;        // 21%
  static const double IIBB_RATE = 0.035;      // 3.5%
  
  static Map<String, double> calculateTaxes(double total) {
    // Calculo de impuestos desde el total
    final iva = total * IVA_RATE;
    final iibb = total * IIBB_RATE;
    
    // Neto gravado = Total - IVA - IIBB
    final netoGravado = total - iva - iibb;
    
    return {
      'total': total,
      'netoGravado': netoGravado,
      'iva': iva,
      'iibb': iibb,
    };
  }
  
  static Map<String, dynamic> consolidateInvoice({
    required String tripOfferId,
    required double tripOfferAmount,
    required List<Map<String, dynamic>> cartItems,
    required double shippingCost,
  }) {
    final total = tripOfferAmount + 
                  cartItems.fold(0.0, (sum, item) => sum + (item['subtotal'] ?? 0.0)) + 
                  shippingCost;
    
    final taxes = calculateTaxes(total);
    
    return {
      'tripOfferId': tripOfferId,
      'tripOfferAmount': tripOfferAmount,
      'cartItems': cartItems,
      'shippingCost': shippingCost,
      'total': total,
      'taxes': taxes,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }
}
