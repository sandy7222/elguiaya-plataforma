import 'package:flutter/material.dart';
import 'package:El Guia YA_master/services/dynamic_skill_system.dart';
import 'package:El Guia YA_master/widgets/afip_config_card.dart';

class AfipBillingSkill extends DynamicSystemSkill {
  @override
  String get id => 'afip_billing';

  @override
  String get name => 'Facturación AFIP';

  @override
  IconData get icon => Icons.receipt_long_rounded;

  @override
  Widget buildConfigCard(BuildContext context) {
    return const AfipConfigCard();
  }
}
