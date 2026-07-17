import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // LIBRERÍA GPS AÑADIDA
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

    if (cliente.bloqueado) {
      await _mostrarAlertaBloqueo(cliente);
    }

    await _cargarSucursales(cliente);

    if (!cliente.bloqueado) {
      await _mostrarSelectorSucursal();
    }

    await _cargarProductos(cliente);
  }

  Future<void> _mostrarAlertaBloqueo(Cliente cliente) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
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

  int _stockDisponible(Producto producto) {
    return producto.stockReal.floor();
  }

  void _mostrarStockMaximo(Producto producto) {
    if (!mounted) return;

    final stock = _stockDisponible(producto);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Stock disponible: $stock unidad${stock == 1 ? '' : 'es'}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  bool _agregarCarrito(Producto producto) {
    final stockDisponible = _stockDisponible(producto);

    if (stockDisponible <= 0) return false;

    final index = _carrito.indexWhere((x) => x.producto.id == producto.id);
    final cantidadActual = index >= 0 ? _carrito[index].cantidad : 0;

    if (cantidadActual >= stockDisponible) {
      _mostrarStockMaximo(producto);
      return false;
    }

    setState(() {
      if (index >= 0) {
        _carrito[index].cantidad++;
      } else {
        _carrito.add(CarritoItem(producto: producto));
      }
    });

    return true;
  }

  Future<bool> _confirmarEliminarProducto(CarritoItem item) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar producto'),
          content: Text(
            '¿Deseas eliminar "${item.producto.nombre}" del carrito?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD41C1C),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    return confirmar == true;
  }

  Future<bool> _quitarCarrito(CarritoItem item) async {
    if (item.cantidad <= 1) {
      final confirmar = await _confirmarEliminarProducto(item);

      if (!confirmar) return false;

      if (!mounted) return false;

      setState(() {
        _carrito.removeWhere((x) => x.producto.id == item.producto.id);
      });

      return true;
    }

    setState(() {
      item.cantidad--;
    });

    return true;
  }

  double get _totalCarrito => _carrito.fold(0, (sum, item) => sum + item.total);

  int get _cantidadCarrito =>
      _carrito.fold(0, (sum, item) => sum + item.cantidad);

  int _cantidadProducto(Producto producto) {
    final index = _carrito.indexWhere((e) => e.producto.id == producto.id);

    if (index < 0) return 0;

    return _carrito[index].cantidad;
  }

  Widget _buildControlProducto(Producto producto, {bool compacto = true}) {
    final sinStock = producto.stockReal <= 0;
    final cantidad = _cantidadProducto(producto);

    late final Widget contenido;

    if (sinStock) {
      contenido = const Text(
        'Sin stock',
        key: ValueKey('sin_stock'),
        style: TextStyle(fontSize: 10.5, color: Colors.grey),
      );
    } else if (cantidad == 0) {
      contenido = IconButton(
        key: ValueKey('agregar_${producto.id}'),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        onPressed: () => _agregarCarrito(producto),
        icon: const Icon(Icons.add_circle, color: Color(0xFFD41C1C)),
      );
    } else {
      contenido = AnimatedContainer(
        key: ValueKey('cantidad_${producto.id}'),
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: compacto ? 4 : 6,
          vertical: compacto ? 2 : 4,
        ),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.red.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () async {
                final item = _carrito.firstWhere(
                  (e) => e.producto.id == producto.id,
                );
                await _quitarCarrito(item);
              },
              child: AnimatedScale(
                duration: const Duration(milliseconds: 120),
                scale: 1,
                child: Icon(
                  Icons.remove_circle,
                  color: Colors.red.shade700,
                  size: compacto ? 21 : 24,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: compacto ? 7 : 9),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: Text(
                  '$cantidad',
                  key: ValueKey('contador_${producto.id}_$cantidad'),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: compacto ? 13 : 15,
                  ),
                ),
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: cantidad >= _stockDisponible(producto)
                  ? () => _mostrarStockMaximo(producto)
                  : () => _agregarCarrito(producto),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 120),
                scale: 1,
                child: Icon(
                  Icons.add_circle,
                  color: cantidad >= _stockDisponible(producto)
                      ? Colors.grey
                      : const Color(0xFFD41C1C),
                  size: compacto ? 21 : 24,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: contenido,
    );
  }

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

  // GPS Silencioso para Visitas y Ventas
  Future<Position?> _obtenerUbicacionSilenciosa() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null; // GPS apagado

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      // Tiempo límite de 5 segundos para no dejar al vendedor esperando
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (e) {
      return null;
    }
  }

  // Modificación Fase 1 y 3: Confirmar Venta con GPS Silencioso
  Future<void> _confirmarVenta(String actionType) async {
    if (_clienteSeleccionado == null || _carrito.isEmpty) return;

    // --- INICIO BLOQUEO DE PANTALLA ---
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFD41C1C)),
        ),
      ),
    );
    // --- FIN BLOQUEO ---

    try {
      // 1. CAPTURA DE GPS SILENCIOSA
      double? lat;
      double? lng;
      try {
        final position = await _obtenerUbicacionSilenciosa();
        if (position != null) {
          lat = position.latitude;
          lng = position.longitude;
        }
      } catch (_) {}

      // 2. INYECTAMOS COORDENADAS AL PAYLOAD
      final payload = {
        'partner_id': _clienteSeleccionado!.id,
        'partner_shipping_id':
            _sucursalSeleccionada?.id ?? _clienteSeleccionado!.id,
        'lineas': _carrito.map((e) => e.toVentaJson()).toList(),
        'nota': _notaController.text.trim(),
        'forzar_contado': false,
        'action': actionType,
        'lat': lat,
        'lng': lng,
      };

      final respuesta = await ApiService.post('ventas', payload);

      if (!mounted) return;

      final folio = respuesta['folio'] ?? '';
      final tipo = respuesta['tipo'] ?? '';
      final total = (respuesta['total'] ?? 0).toDouble();

      // 3. GUARDAMOS LOS NOMBRES TEMPORALMENTE
      final nombreCliente = _clienteSeleccionado!.nombre;
      final nombreDespacho =
          _sucursalSeleccionada?.nombre ?? 'Dirección Principal';

      // 4. RESETEAMOS TODO EL ESTADO PARA UNA NUEVA VENTA LIMPIA
      setState(() {
        _clienteSeleccionado = null;
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
      });

      // 5. CERRAMOS LA RUEDA DE CARGA Y EL MODAL
      Navigator.pop(context);
      Navigator.pop(context);

      // 6. ENVIAMOS LAS VARIABLES TEMPORALES A LA PANTALLA DE ÉXITO
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VentaOkScreen(
            folio: folio,
            total: total,
            cliente: nombreCliente,
            despacho: nombreDespacho,
            esCotizacion: tipo != 'sale',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      Navigator.pop(context);

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

  // --- NUEVAS FUNCIONES PARA VISITAS SIN VENTA ---
  void _mostrarModalSinVenta() {
    // 1. Actualizamos el valor por defecto para que coincida exactamente
    String motivoSeleccionado = 'Local Cerrado';
    final TextEditingController obsController = TextEditingController();

    // 2. Alineamos la lista exacta de motivos con Odoo Studio
    final List<String> motivos = [
      'Local Cerrado',
      'Sin Capacidad de Compra (sin dinero)',
      'Cliente Bloqueado',
      'Tiene Stock suficiente',
      'No está el encargado de compras',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Registrar Visita sin Venta',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: motivoSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Motivo principal',
                    border: OutlineInputBorder(),
                  ),
                  // Usamos la versión de IsDense para evitar que textos largos rompan el diseño
                  isExpanded: true,
                  items: motivos
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(
                            m,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setModalState(() => motivoSeleccionado = v!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: obsController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Observaciones (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade800,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Cierra el modal
                      _registrarVisitaSinVenta(
                        motivoSeleccionado,
                        obsController.text.trim(),
                      );
                    },
                    child: const Text(
                      'Guardar Visita y Ubicación',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _registrarVisitaSinVenta(
    String motivo,
    String observaciones,
  ) async {
    if (_clienteSeleccionado == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator(color: Colors.grey)),
      ),
    );

    try {
      double? lat;
      double? lng;
      try {
        final position = await _obtenerUbicacionSilenciosa();
        if (position != null) {
          lat = position.latitude;
          lng = position.longitude;
        }
      } catch (_) {}

      final payload = {
        'partner_id': _clienteSeleccionado!.id,
        'motivo': motivo,
        'observaciones': observaciones,
        'latitud': lat,
        'longitud': lng,
      };

      await ApiService.post('visitas', payload);

      if (!mounted) return;
      Navigator.pop(context); // Cierra la rueda

      // Limpia todo para el siguiente cliente
      setState(() {
        _clienteSeleccionado = null;
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
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Visita registrada exitosamente en Odoo',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error'),
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
                                          onPressed: () async {
                                            final actualizado =
                                                await _quitarCarrito(item);
                                            if (actualizado) {
                                              setModalState(() {});
                                            }
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
                                            final actualizado = _agregarCarrito(
                                              item.producto,
                                            );
                                            if (actualizado) {
                                              setModalState(() {});
                                            }
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
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFF8B2B2B),
                                  ),
                                  foregroundColor: const Color(0xFF8B2B2B),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: _carrito.isEmpty
                                    ? null
                                    : () => _confirmarVenta('draft'),
                                icon: const Icon(Icons.save_outlined),
                                label: const Text(
                                  'Borrador',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: esCotizacion
                                      ? Colors.orange.shade800
                                      : const Color(0xFFD41C1C),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: _carrito.isEmpty
                                    ? null
                                    : () => _confirmarVenta('confirm'),
                                child: Text(
                                  esCotizacion
                                      ? 'Cotización'
                                      : 'Confirmar Venta',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
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
        toolbarHeight: 56,
        backgroundColor: const Color(0xFF8B2B2B),
        automaticallyImplyLeading: false,
        title: const Text(
          'Nueva Nota de Venta',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildClienteCompacto(),
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
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
      child: Autocomplete<Cliente>(
        displayStringForOption: (Cliente c) => c.nombre,
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<Cliente>.empty();
          }
          final q = textEditingValue.text.toLowerCase().trim();

          return _clientes
              .where((c) {
                return c.nombre.toLowerCase().contains(q) ||
                    c.rut.toLowerCase().contains(q);
              })
              .take(15);
        },
        onSelected: (Cliente cliente) {
          _seleccionarCliente(cliente);
          FocusScope.of(context).unfocus();
        },
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          // --- CLAVE PARA LIMPIAR EL TEXTO ---
          if (_clienteSeleccionado == null) {
            controller.clear();
          } else if (controller.text.isEmpty) {
            controller.text = _clienteSeleccionado!.nombre;
          }

          return TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Buscar Cliente (Nombre o RUT)',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _clienteSeleccionado != null
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _clienteSeleccionado = null;
                          _productos = [];
                          _filtrados = [];
                          _carrito = [];
                          _sucursales = [];
                        });
                        controller.clear();
                        focusNode.requestFocus();
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: 250,
                  maxWidth: MediaQuery.of(context).size.width - 20,
                ),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (context, index) {
                    final c = options.elementAt(index);
                    return InkWell(
                      onTap: () => onSelected(c),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                c.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
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
                      ),
                    );
                  },
                ),
              ),
            ),
          );
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
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
      child: InkWell(
        onTap: () async {
          await _mostrarSelectorSucursal();
          if (mounted) setState(() {});
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.local_shipping,
                color: Color(0xFF1A237E),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$titulo · $direccion',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Cambiar',
                style: TextStyle(
                  color: Color(0xFF8B2B2B),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
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
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 44,
            child: TextField(
              controller: _buscarController,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Buscar producto',
                prefixIcon: Icon(Icons.search, size: 20),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _categoria,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Categoría',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
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
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _marca,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Marca',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
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
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Solo productos con stock',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      _soloStock = !_soloStock;
                    });
                    _aplicarFiltros();
                  },
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: _soloStock
                          ? const Color(0xFF8B2B2B)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _soloStock
                            ? const Color(0xFF8B2B2B)
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Icon(
                      Icons.inventory,
                      size: 20,
                      color: _soloStock ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              IconButton(
                tooltip: 'Vista grilla',
                visualDensity: VisualDensity.compact,
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
                visualDensity: VisualDensity.compact,
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
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      itemCount: _filtrados.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.02,
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
                      size: 34,
                      color: Colors.brown.shade300,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 1),
                  child: Text(
                    p.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${p.codigo} · Stock: ${p.stockReal.round()}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 5, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_money(p.precioBruto)} x ${p.unidad}',
                          style: const TextStyle(
                            color: Color(0xFFD41C1C),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildControlProducto(p),
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
              width: 145,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _money(p.precioBruto),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  _buildControlProducto(p, compacto: false),
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
    final bool clienteSeleccionado = _clienteSeleccionado != null;

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

          if (clienteSeleccionado && _cantidadCarrito == 0)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.location_off_outlined),
                label: const Text(
                  'Registrar Visita Sin Venta',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _mostrarModalSinVenta,
              ),
            )
          else
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
