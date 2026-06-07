
import os

file_path = r'c:\Users\sandy\OneDrive\Documentos\capitangemini\lib\screens\bienvenida_definitiva_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Buscamos la llamada al footer y le inyectamos el Modo Obra
if '_buildFooter(),' in content and '_buildModoObraSection(),' not in content:
    content = content.replace(
        '_buildFooter(),',
        '_buildFooter(),\n                  const SizedBox(height: 32),\n                  _buildModoObraSection(),'
    )

# Agregamos la implementación al final de la clase (antes de la última llave)
implementation = """
  Widget _buildModoObraSection() {
    return Column(
      children: [
        const Row(
          children: [
            Expanded(child: Divider(color: Colors.white24)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('MODO OBRA 🚧', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ),
            Expanded(child: Divider(color: Colors.white24)),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildBypassButton(
                icon: Icons.engineering,
                label: 'DASHBOARD\\nCAPITÁN',
                color: Colors.orangeAccent,
                onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildBypassButton(
                icon: Icons.shopping_cart,
                label: 'PORTAL\\nPESCADOR',
                color: Colors.cyanAccent,
                onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const PortalPescadorScreen()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBypassButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }
"""

if '_buildModoObraSection()' not in content:
    # Insertamos antes de la última llave de cierre de la clase _BienvenidaDefinitivaScreenState
    last_brace_index = content.rfind('}')
    content = content[:last_brace_index] + implementation + content[last_brace_index:]

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Modo Obra inyectado con éxito.")
