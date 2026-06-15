import 'package:flutter/material.dart';
import '../models/cliente.dart';
import '../models/producto.dart';
import '../models/carrito_item.dart';
import '../models/sucursal.dart';
import '../services/api_service.dart';
import '../screens/completar_ficha_screen.dart';

class VenderTab extends StatefulWidget {
  const VenderTab({super.key});

  @override
  State<VenderTab> createState() => _VenderTabState();
}

class _VenderTabState extends State<VenderTab> {
  List<Cliente> _clientes = [];
  List<Producto> _productos = [];
  List<Producto> _filtrados = [];
  List<CarritoItem> _carrito = [];
  List<Sucursal> _sucursales = [];

  Cliente? _clienteSeleccionado;
  Sucursal? _sucursalSeleccionada;

  bool _cargandoClientes = true;
  bool _cargandoProductos = false;
  bool _soloStock = false;
  bool _vistaLista = false;

  String _error = '';
  String _categoria = '';
  String _marca = '';

  final TextEditingController _buscarController = TextEditingController();
  final TextEditingController _notaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarClientes();
    _buscarController.addListener(_aplicarFiltros);
  }

  @override
  void dispose() {
    _buscarController.dispose();
    _notaController.dispose();
    super.dispose();
  }

  Future<void> _cargarClientes() async {
    try {
      final data = await ApiService.get('clientes');
      final lista = (data['clientes'] ?? []) as List;

      if (!mounted) return;

      setState(() {
        _clientes = lista.map((e) => Cliente.fromJson(e)).toList();
        _cargandoClientes = false;
        _error = '';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Error cargando clientes: $e';
        _cargandoClientes = false;
      });
    }
  }

  Future<void> _seleccionarCliente(Cliente cliente) async {
    setState(() {
      _clienteSeleccionado = cliente;
      _sucursalSeleccionada = null;
      _sucursales = [];
      _productos = [];
      _filtrados = [];
      _carrito = [];
      _categoria = '';
      _marca = '';
      _soloStock = false;
      _notaController.clear();
      _buscarController.clear();
      _error = '';
    });

    if (cliente.fichaIncompleta) {
      final actualizado = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => CompletarFichaScreen(cliente: cliente),
        ),
      );

      if (actualizado == true) {
        setState(() {
          _cargandoClientes = true;
        });

        await _cargarClientes();

        final clienteActualizado = _clientes.firstWhere(
          (c) => c.id == cliente.id,
          orElse: () => cliente,
        );

        if (!mounted) return;
        await _seleccionarCliente(clienteActualizado);
      }

      return;
    }

    // MEJORA 3 (Actualizada): Lanzar el cuadro de deudas como un Pop-Up
    if (cliente.bloqueado) {
      await _mostrarAlertaBloqueo(cliente);
    }

    await _cargarSucursales(cliente);

    // Solo mostramos selector de sucursal automático si NO está bloqueado
    if (!cliente.bloqueado) {
      await _mostrarSelectorSucursal();
    }

    await _cargarProductos(cliente);
  }

  // MÉTODO NUEVO: Muestra el pop-up financiero que el vendedor debe cerrar
  Future<void> _mostrarAlertaBloqueo(Cliente cliente) async {
    await showDialog(
      context: context,
      barrierDismissible: false, // Obliga a tocar el botón para cerrarlo
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFD41C1C),
                size: 30,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'CLIENTE BLOQUEADO',
                  style: TextStyle(
                    color: Color(0xFFD41C1C),
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Este cliente presenta problemas de pago.\nSolo puedes realizarle cotizaciones.',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'ESTADO DE CUENTA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
              const Divider(height: 16),
              _filaFinanciera(
                'Límite Autorizado:',
                _money(cliente.limiteCredito.toDouble()),
              ),
              const SizedBox(height: 8),
              _filaFinanciera(
                'Deuda Total Vigente:',
                _money(cliente.deudaActual.toDouble()),
                esAlerta: cliente.deudaActual >= cliente.limiteCredito,
              ),
              const SizedBox(height: 8),
              _filaFinanciera(
                'Monto Vencido:',
                _money(cliente.montoVencido.toDouble()),
                esCritico: cliente.montoVencido > 0,
              ),
              const Divider(height: 16),
              Text(
                'Motivo: ${cliente.razonBloqueo.isNotEmpty ? cliente.razonBloqueo : "Registra problemas de pago"}',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD41C1C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Entendido, continuar cotizando',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cargarSucursales(Cliente cliente) async {
    try {
      final data = await ApiService.get('clientes/${cliente.id}/sucursales');
      final lista = (data['sucursales'] ?? []) as List;

      if (!mounted) return;

      setState(() {
        _sucursales = lista.map((e) => Sucursal.fromJson(e)).toList();
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _sucursales = [];
        _sucursalSeleccionada = null;
      });
    }
  }

  Future<void> _mostrarSelectorSucursal() async {
    if (_clienteSeleccionado == null) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.red.shade50,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            child: Wrap(
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const Text(
                  'Seleccionar Dirección de Entrega',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  '¿Dónde se despachará este pedido?',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.home, color: Color(0xFF8B2B2B)),
                  title: const Text(
                    'Dirección Principal',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _clienteSeleccionado!.direccion.isEmpty
                        ? _clienteSeleccionado!.ciudad
                        : _clienteSeleccionado!.direccion,
                  ),
                  onTap: () {
                    setState(() => _sucursalSeleccionada = null);
                    Navigator.pop(context);
                  },
                ),
                ..._sucursales.map(
                  (s) => ListTile(
                    leading: const Icon(
                      Icons.location_on,
                      color: Color(0xFF8B2B2B),
                    ),
                    title: Text(
                      s.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      [
                        s.direccion,
                        s.ciudad,
                      ].where((x) => x.trim().isNotEmpty).join(' · '),
                    ),
                    onTap: () {
                      setState(() => _sucursalSeleccionada = s);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _cargarProductos(Cliente cliente) async {
    try {
      setState(() {
        _cargandoProductos = true;
        _error = '';
      });

      String endpoint = 'productos?1=1';
      if (cliente.listaPreciosId != null) {
        endpoint += '&pricelist_id=${cliente.listaPreciosId}';
      }

      final data = await ApiService.get(endpoint);
      final lista = (data['productos'] ?? []) as List;

      if (!mounted) return;

      setState(() {
        _productos = lista.map((e) => Producto.fromJson(e)).toList();
        _filtrados = _productos;
        _cargandoProductos = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Error cargando productos: $e';
        _cargandoProductos = false;
      });
    }
  }

  void _aplicarFiltros() {
    final q = _buscarController.text.toLowerCase().trim();

    setState(() {
      _filtrados = _productos.where((p) {
        final coincideTexto =
            p.nombre.toLowerCase().contains(q) ||
            p.codigo.toLowerCase().contains(q);
        final coincideCategoria =
            _categoria.isEmpty || p.categoria == _categoria;
        final coincideMarca = _marca.isEmpty || p.marca == _marca;
        final coincideStock = !_soloStock || p.stockReal > 0;

        return coincideTexto &&
            coincideCategoria &&
            coincideMarca &&
            coincideStock;
      }).toList();
    });
  }

  void _agregarCarrito(Producto producto) {
    if (producto.stockReal <= 0) return;

    final index = _carrito.indexWhere((x) => x.producto.id == producto.id);

    setState(() {
      if (index >= 0) {
        _carrito[index].cantidad++;
      } else {
        _carrito.add(CarritoItem(producto: producto));
      }
    });
  }

  void _quitarCarrito(CarritoItem item) {
    setState(() {
      item.cantidad--;
      if (item.cantidad <= 0) {
        _carrito.removeWhere((x) => x.producto.id == item.producto.id);
      }
    });
  }

  double get _totalCarrito => _carrito.fold(0, (sum, item) => sum + item.total);

  int get _cantidadCarrito =>
      _carrito.fold(0, (sum, item) => sum + item.cantidad);

  String _money(double valor) {
    final entero = valor.round().toString();
    final buffer = StringBuffer();

    for (int i = 0; i < entero.length; i++) {
      final pos = entero.length - i;
      buffer.write(entero[i]);
      if (pos > 1 && pos % 3 == 1) buffer.write('.');
    }

    return '\$${buffer.toString()}';
  }

  Color _obtenerColorFondoStock(double stock) {
    if (stock <= 0) return Colors.red.shade50;
    if (stock < 5) return Colors.amber.shade50;
    return Colors.green.shade50;
  }

  Color _obtenerColorBordeStock(double stock) {
    if (stock <= 0) return Colors.red.shade200;
    if (stock < 5) return Colors.amber.shade300;
    return Colors.green.shade200;
  }

  Future<void> _confirmarVenta() async {
    if (_clienteSeleccionado == null || _carrito.isEmpty) return;

    try {
      final payload = {
        'partner_id': _clienteSeleccionado!.id,
        'partner_shipping_id':
            _sucursalSeleccionada?.id ?? _clienteSeleccionado!.id,
        'lineas': _carrito.map((e) => e.toVentaJson()).toList(),
        'nota': _notaController.text.trim(),
        'forzar_contado': false,
      };

      final respuesta = await ApiService.post('ventas', payload);

      if (!mounted) return;

      final folio = respuesta['folio'] ?? '';
      final tipo = respuesta['tipo'] ?? '';
      final total = (respuesta['total'] ?? 0).toDouble();

      setState(() {
        _carrito.clear();
      });

      Navigator.pop(context);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VentaOkScreen(
            folio: folio,
            total: total,
            cliente: _clienteSeleccionado!.nombre,
            despacho: _sucursalSeleccionada?.nombre ?? 'Dirección Principal',
            esCotizacion: tipo != 'sale',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error al grabar'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    }
  }

  void _mostrarCarrito() {
    final esCotizacion = _clienteSeleccionado?.bloqueado == true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.78,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Carrito',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _carrito.isEmpty
                            ? const Center(child: Text('Carrito vacío'))
                            : ListView.separated(
                                itemCount: _carrito.length,
                                separatorBuilder: (_, _) => const Divider(),
                                itemBuilder: (context, index) {
                                  final item = _carrito[index];

                                  return ListTile(
                                    title: Text(
                                      item.producto.nombre,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      _money(item.producto.precioBruto),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          onPressed: () {
                                            _quitarCarrito(item);
                                            setModalState(() {});
                                          },
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                          ),
                                        ),
                                        Text(
                                          '${item.cantidad}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () {
                                            _agregarCarrito(item.producto);
                                            setModalState(() {});
                                          },
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: TextStyle(fontSize: 18)),
                          Text(
                            _money(_totalCarrito),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _notaController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Nota / observación',
                          hintText: 'Ej: Entregar en bodega norte',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: esCotizacion
                                ? Colors.orange.shade800
                                : const Color(0xFFD41C1C),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _carrito.isEmpty ? null : _confirmarVenta,
                          child: Text(
                            esCotizacion
                                ? 'Generar Cotización'
                                : 'Confirmar nota de venta',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<String> get _categorias {
    final set = _productos
        .map((p) => p.categoria)
        .where((x) => x.isNotEmpty)
        .toSet()
        .toList();
    set.sort();
    return set;
  }

  List<String> get _marcas {
    final set = _productos
        .map((p) => p.marca)
        .where((x) => x.isNotEmpty)
        .toSet()
        .toList();
    set.sort();
    return set;
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoClientes) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B2B2B)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        toolbarHeight: 74,
        backgroundColor: const Color(0xFF8B2B2B),
        automaticallyImplyLeading: false,
        title: const Text(
          'Nueva Nota de Venta',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _buildClienteCompacto(),
          // Se eliminó el cuadro de alerta inline de aquí para mantenerlo limpio
          if (_clienteSeleccionado != null &&
              !_clienteSeleccionado!.fichaIncompleta &&
              !_clienteSeleccionado!.bloqueado)
            _buildDireccionCompacta(),
          if (_clienteSeleccionado != null &&
              !_clienteSeleccionado!.fichaIncompleta)
            _buildFiltrosCompactos(),
          Expanded(child: _buildProductos()),
          _buildBarraCarrito(),
        ],
      ),
    );
  }

  Widget _buildClienteCompacto() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: DropdownButtonFormField<int>(
        isExpanded: true,
        initialValue: _clienteSeleccionado?.id,
        decoration: const InputDecoration(
          isDense: true,
          labelText: 'Cliente',
          prefixIcon: Icon(Icons.people),
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        items: _clientes.map((c) {
          return DropdownMenuItem<int>(
            value: c.id,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    c.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (c.bloqueado)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD41C1C),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'BLOQUEADO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
        onChanged: (id) {
          if (id == null) return;
          final cliente = _clientes.firstWhere((c) => c.id == id);
          _seleccionarCliente(cliente);
        },
      ),
    );
  }

  Widget _filaFinanciera(
    String etiqueta,
    String valor, {
    bool esAlerta = false,
    bool esCritico = false,
  }) {
    Color colorTexto = Colors.black87;
    FontWeight pesoTexto = FontWeight.w600;

    if (esAlerta) colorTexto = Colors.orange.shade800;
    if (esCritico) {
      colorTexto = const Color(0xFFD41C1C);
      pesoTexto = FontWeight.w900;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          etiqueta,
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: 14,
            fontWeight: pesoTexto,
            color: colorTexto,
          ),
        ),
      ],
    );
  }

  Widget _buildDireccionCompacta() {
    if (_clienteSeleccionado == null) return const SizedBox.shrink();

    final bool esPrincipal = _sucursalSeleccionada == null;

    final String titulo = esPrincipal
        ? 'Dirección Principal'
        : _sucursalSeleccionada!.nombre;

    final String direccion = esPrincipal
        ? (_clienteSeleccionado!.direccion.isNotEmpty
              ? _clienteSeleccionado!.direccion
              : _clienteSeleccionado!.ciudad)
        : _sucursalSeleccionada!.direccion;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: InkWell(
        onTap: () async {
          await _mostrarSelectorSucursal();
          if (mounted) setState(() {});
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_shipping, color: Color(0xFF1A237E)),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Entrega: ',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: '$titulo · $direccion',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Cambiar',
                style: TextStyle(
                  color: Color(0xFF8B2B2B),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltrosCompactos() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        children: [
          TextField(
            controller: _buscarController,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Buscar producto',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _categoria,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Categoría',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Todas')),
                    ..._categorias.map(
                      (c) => DropdownMenuItem(value: c, child: Text(c)),
                    ),
                  ],
                  onChanged: (v) {
                    _categoria = v ?? '';
                    _aplicarFiltros();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _marca,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Marca',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Todas')),
                    ..._marcas.map(
                      (m) => DropdownMenuItem(value: m, child: Text(m)),
                    ),
                  ],
                  onChanged: (v) {
                    _marca = v ?? '';
                    _aplicarFiltros();
                  },
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFF8B2B2B),
                  title: const Text(
                    'Solo stock',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  value: _soloStock,
                  onChanged: (v) {
                    setState(() {
                      _soloStock = v ?? false;
                    });
                    _aplicarFiltros();
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),

              IconButton(
                tooltip: 'Vista grilla',
                icon: Icon(
                  Icons.grid_view,
                  color: !_vistaLista ? const Color(0xFFD41C1C) : Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _vistaLista = false;
                  });
                },
              ),

              IconButton(
                tooltip: 'Vista lista',
                icon: Icon(
                  Icons.view_list,
                  color: _vistaLista ? const Color(0xFFD41C1C) : Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _vistaLista = true;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductos() {
    if (_clienteSeleccionado == null) {
      return const Center(
        child: Text('Selecciona un cliente para cargar el catálogo.'),
      );
    }

    if (_clienteSeleccionado!.fichaIncompleta) {
      return const Center(
        child: Text('Debes actualizar la ficha del cliente antes de vender.'),
      );
    }

    if (_cargandoProductos) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B2B2B)),
      );
    }

    if (_error.isNotEmpty) {
      return Center(child: Text(_error));
    }

    if (_filtrados.isEmpty) {
      return const Center(child: Text('Sin productos encontrados.'));
    }

    if (_vistaLista) {
      return _buildListaProductos();
    }

    return GridView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _filtrados.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.86,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final p = _filtrados[index];
        final sinStock = p.stockReal <= 0;

        return Opacity(
          opacity: sinStock ? 0.45 : 1,
          child: Container(
            decoration: BoxDecoration(
              color: _obtenerColorFondoStock(p.stockReal),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _obtenerColorBordeStock(p.stockReal)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Center(
                    child: Icon(
                      Icons.inventory_2,
                      size: 44,
                      color: Colors.brown.shade300,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(9, 6, 9, 2),
                  child: Text(
                    p.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  child: Text(
                    '${p.codigo} · Stock: ${p.stockReal.round()}',
                    style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(9, 4, 6, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_money(p.precioBruto)} x ${p.unidad}',
                          style: const TextStyle(
                            color: Color(0xFFD41C1C),
                            fontWeight: FontWeight.w900,
                            fontSize: 12.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      sinStock
                          ? const Text(
                              'Sin stock',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.grey,
                              ),
                            )
                          : IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              onPressed: () => _agregarCarrito(p),
                              icon: const Icon(
                                Icons.add_circle,
                                color: Color(0xFFD41C1C),
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildListaProductos() {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _filtrados.length,
      itemBuilder: (context, index) {
        final p = _filtrados[index];
        final sinStock = p.stockReal <= 0;

        return Card(
          color: _obtenerColorFondoStock(p.stockReal),
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: _obtenerColorBordeStock(p.stockReal)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: Icon(
              Icons.inventory_2,
              color: sinStock ? Colors.grey : const Color(0xFFD41C1C),
            ),
            title: Text(
              p.nombre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('${p.codigo} · Stock: ${p.stockReal.round()}'),
            trailing: SizedBox(
              width: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _money(p.precioBruto),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  if (!sinStock)
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle,
                        color: Color(0xFFD41C1C),
                      ),
                      onPressed: () => _agregarCarrito(p),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBarraCarrito() {
    final esCotizacion = _clienteSeleccionado?.bloqueado == true;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('$_cantidadCarrito productos'),
              const Spacer(),
              Text(
                _money(_totalCarrito),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: esCotizacion
                    ? Colors.orange.shade800
                    : const Color(0xFFD41C1C),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _cantidadCarrito == 0 ? null : _mostrarCarrito,
              child: Text(
                esCotizacion
                    ? 'Ver carrito (Cotización)'
                    : 'Ver carrito y confirmar',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ... [La clase VentaOkScreen queda exactamente igual en el mismo archivo] ...
class VentaOkScreen extends StatelessWidget {
  final String folio;
  final double total;
  final String cliente;
  final String despacho;
  final bool esCotizacion;

  const VentaOkScreen({
    super.key,
    required this.folio,
    required this.total,
    required this.cliente,
    required this.despacho,
    required this.esCotizacion,
  });

  String _money(double valor) {
    final entero = valor.round().toString();
    final buffer = StringBuffer();

    for (int i = 0; i < entero.length; i++) {
      final pos = entero.length - i;
      buffer.write(entero[i]);
      if (pos > 1 && pos % 3 == 1) buffer.write('.');
    }

    return '\$${buffer.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                esCotizacion ? Icons.description : Icons.check_circle,
                size: 92,
                color: esCotizacion ? Colors.orange : Colors.green,
              ),
              const SizedBox(height: 24),
              Text(
                esCotizacion
                    ? '¡Cotización registrada!'
                    : '¡Nota de Venta Confirmada!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                folio,
                style: const TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                _money(total),
                style: const TextStyle(
                  fontSize: 34,
                  color: Color(0xFFD41C1C),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 30),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cliente', style: TextStyle(color: Colors.grey)),
                    Text(
                      cliente,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'Despacho: $despacho',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD41C1C),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Nueva nota de venta',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
