import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  bool _loading = true;
  String _error = '';
  String _name = 'Vendedor';

  Map<String, dynamic> _clientes = {};
  Map<String, dynamic> _ventas = {};

  @override
  void initState() {
    super.initState();
    _cargarDashboard();
  }

  Future<void> _cargarDashboard() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final data = await ApiService.get('dashboard/');

      if (!mounted) return;

      setState(() {
        _name = prefs.getString('name') ?? 'Vendedor';
        _clientes = Map<String, dynamic>.from(data['clientes'] ?? {});
        _ventas = Map<String, dynamic>.from(data['ventas'] ?? {});
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _money(dynamic value) {
    final n = value is num ? value.round() : 0;
    final s = n.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < s.length; i++) {
      final pos = s.length - i;
      buffer.write(s[i]);
      if (pos > 1 && pos % 3 == 1) buffer.write('.');
    }

    return '\$${buffer.toString()}';
  }

  String _num(dynamic value) {
    if (value is num) return value.round().toString();
    return '0';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B2B2B),
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo_dicos.jpg',
              height: 38,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Hola, $_name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B2B2B)),
            )
          : _error.isNotEmpty
          ? Center(child: Text(_error))
          : RefreshIndicator(
              onRefresh: _cargarDashboard,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Resumen comercial',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Indicadores de tu cartera y ventas actuales',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),

                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.25,
                    children: [
                      _DashCard(
                        title: 'Clientes',
                        value: _num(_clientes['asignados']),
                        subtitle: 'Asignados',
                        icon: Icons.people,
                      ),
                      _DashCard(
                        title: 'Con venta',
                        value: _num(_clientes['con_venta_semana']),
                        subtitle: 'Esta semana',
                        icon: Icons.person_pin_circle,
                      ),
                      _DashCard(
                        title: 'Ventas semana',
                        value: _money(_ventas['semana']),
                        subtitle: '${_num(_ventas['notas_semana'])} notas',
                        icon: Icons.trending_up,
                      ),
                      _DashCard(
                        title: 'Ventas mes',
                        value: _money(_ventas['mes']),
                        subtitle: '${_num(_ventas['notas_mes'])} notas',
                        icon: Icons.calendar_month,
                      ),
                      _DashCard(
                        title: 'Ticket promedio',
                        value: _money(_ventas['ticket_promedio']),
                        subtitle: 'Semana actual',
                        icon: Icons.receipt_long,
                      ),
                      _DashCard(
                        title: 'Bloqueados',
                        value: _num(_clientes['bloqueados']),
                        subtitle: 'Con riesgo',
                        icon: Icons.warning_amber,
                        danger: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'Alertas comerciales',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),

                  _AlertCard(
                    icon: Icons.assignment_late,
                    title: 'Fichas incompletas',
                    value: '${_num(_clientes['fichas_incompletas'])} clientes',
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 10),
                  _AlertCard(
                    icon: Icons.block,
                    title: 'Clientes bloqueados',
                    value: '${_num(_clientes['bloqueados'])} clientes',
                    color: Colors.red,
                  ),
                ],
              ),
            ),
    );
  }
}

class _DashCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final bool danger;

  const _DashCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.red : const Color(0xFF8B2B2B);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _AlertCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
