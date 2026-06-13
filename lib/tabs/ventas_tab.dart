import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/venta.dart';

class VentasTab extends StatefulWidget {
  const VentasTab({super.key});

  @override
  State<VentasTab> createState() => _VentasTabState();
}

class _VentasTabState extends State<VentasTab> {
  List<Venta> _ventas = [];
  List<Venta> _filtradas = [];
  bool _isLoading = true;
  String _error = '';
  String _filtroTiempo = 'todas';
  final TextEditingController _clienteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarVentas();
    _clienteController.addListener(_aplicarFiltros);
  }

  @override
  void dispose() {
    _clienteController.dispose();
    super.dispose();
  }

  Future<void> _cargarVentas() async {
    try {
      final data = await ApiService.get('ventas');
      final lista = (data['ventas'] ?? []) as List;

      if (mounted) {
        setState(() {
          _ventas = lista.map((v) => Venta.fromJson(v)).toList();
          _filtradas = _ventas;
          _isLoading = false;
          _error = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error cargando ventas: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _aplicarFiltros() {
    final texto = _clienteController.text.toLowerCase().trim();
    final ahora = DateTime.now();

    List<Venta> resultado = _ventas.where((venta) {
      final coincideCliente = venta.cliente.toLowerCase().contains(texto);

      bool coincideFecha = true;
      final fecha = DateTime.tryParse(venta.fechaRaw);

      if (fecha != null) {
        if (_filtroTiempo == 'hoy') {
          coincideFecha =
              fecha.year == ahora.year &&
              fecha.month == ahora.month &&
              fecha.day == ahora.day;
        } else if (_filtroTiempo == 'semana') {
          final inicioSemana = ahora.subtract(Duration(days: ahora.weekday - 1));
          coincideFecha = fecha.isAfter(
            DateTime(inicioSemana.year, inicioSemana.month, inicioSemana.day),
          );
        } else if (_filtroTiempo == 'mes') {
          coincideFecha = fecha.year == ahora.year && fecha.month == ahora.month;
        }
      }

      return coincideCliente && coincideFecha;
    }).toList();

    setState(() {
      _filtradas = resultado;
    });
  }

  double get _totalFiltrado {
    return _filtradas.fold(0, (sum, venta) => sum + venta.total);
  }

  String _formatearMonto(double valor) {
    final entero = valor.round().toString();
    final buffer = StringBuffer();

    for (int i = 0; i < entero.length; i++) {
      final posicion = entero.length - i;
      buffer.write(entero[i]);
      if (posicion > 1 && posicion % 3 == 1) {
        buffer.write('.');
      }
    }

    return '\$${buffer.toString()}';
  }

  Color _estadoColor(String estado) {
    if (estado == 'sale') return Colors.green;
    if (estado == 'draft') return Colors.orange;
    if (estado == 'cancel') return Colors.red;
    return Colors.grey;
  }

  String _estadoTexto(String estado) {
    if (estado == 'sale') return 'Confirmada';
    if (estado == 'draft') return 'Borrador';
    if (estado == 'cancel') return 'Cancelada';
    return estado;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B2B2B),
        automaticallyImplyLeading: false,
        title: const Text(
          'Mis Ventas',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B2B2B)),
      );
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(_error, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    return Column(
      children: [
        _buildFiltros(),
        _buildResumen(),
        Expanded(child: _buildLista()),
      ],
    );
  }

  Widget _buildFiltros() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _filtroTiempo,
            decoration: const InputDecoration(labelText: 'Periodo'),
            items: const [
              DropdownMenuItem(value: 'todas', child: Text('Todas las fechas')),
              DropdownMenuItem(value: 'hoy', child: Text('Hoy')),
              DropdownMenuItem(value: 'semana', child: Text('Esta semana')),
              DropdownMenuItem(value: 'mes', child: Text('Este mes')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _filtroTiempo = value);
              _aplicarFiltros();
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _clienteController,
            decoration: const InputDecoration(
              labelText: 'Buscar por cliente',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumen() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: _resumenCard(
              'Total ventas',
              _formatearMonto(_totalFiltrado),
              Icons.attach_money,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _resumenCard(
              'Notas emitidas',
              '${_filtradas.length}',
              Icons.receipt_long,
            ),
          ),
        ],
      ),
    );
  }

  Widget _resumenCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF8B2B2B)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLista() {
    if (_filtradas.isEmpty) {
      return const Center(
        child: Text('No hay ventas para este filtro.'),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarVentas,
      color: const Color(0xFF8B2B2B),
      child: ListView.separated(
        itemCount: _filtradas.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          final venta = _filtradas[index];

          return ListTile(
            tileColor: Colors.white,
            leading: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.receipt_long, color: Color(0xFF1A237E)),
            ),
            title: Text(
              venta.cliente,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('${venta.nombre} · ${venta.fecha} · ${venta.lineas} líneas'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatearMonto(venta.total),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  _estadoTexto(venta.estado),
                  style: TextStyle(
                    fontSize: 11,
                    color: _estadoColor(venta.estado),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
