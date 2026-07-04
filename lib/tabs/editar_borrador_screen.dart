import 'package:flutter/material.dart';
import '../models/cliente.dart';
import '../models/producto.dart';
import '../models/carrito_item.dart';
import '../models/sucursal.dart';
import '../services/api_service.dart';
import 'vender_tab.dart';

class EditarBorradorScreen extends StatefulWidget {
  final int ventaId;

  const EditarBorradorScreen({super.key, required this.ventaId});

  @override
  State<EditarBorradorScreen> createState() => _EditarBorradorScreenState();
}

class _EditarBorradorScreenState extends State<EditarBorradorScreen> {
  List<Cliente> _clientes = [];
  List<Producto> _productos = [];
  List<Producto> _filtrados = [];
  List<CarritoItem> _carrito = [];
  List<Sucursal> _sucursales = [];

  Cliente? _clienteSeleccionado;
  Sucursal? _sucursalSeleccionada;

  bool _cargandoInicial = true;
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
    _inicializarBorrador();
    _buscarController.addListener(_aplicarFiltros);
  }

  @override
  void dispose() {
    _buscarController.dispose();
    _notaController.dispose();
    super.dispose();
  }

  Future<void> _inicializarBorrador() async {
    try {
      // 1. Obtener listado de clientes
      final clientesData = await ApiService.get('clientes');
      final listaClientes = (clientesData['clientes'] ?? []) as List;
      _clientes = listaClientes.map((e) => Cliente.fromJson(e)).toList();

      // 2. Obtener el detalle del borrador desde el Bypass de Node.js
      final borradorData = await ApiService.get('ventas?id=${widget.ventaId}');

      // PARSEO DEFENSIVO: Validamos que el partner_id no venga nulo
      final partnerIdRaw = borradorData['partner_id'];
      if (partnerIdRaw == null) {
        throw Exception(
          'El servidor no devolvió el partner_id. Respuesta completa: $borradorData',
        );
      }
      final int partnerId = partnerIdRaw is int
          ? partnerIdRaw
          : (int.tryParse(partnerIdRaw.toString()) ?? 0);

      // Parseo seguro para la sucursal de despacho
      final shippingIdRaw = borradorData['partner_shipping_id'];
      final int? shippingId = shippingIdRaw is int
          ? shippingIdRaw
          : int.tryParse(shippingIdRaw?.toString() ?? '');

      _notaController.text = borradorData['nota'] ?? '';
      final lineasGuardadas = (borradorData['lineas'] ?? []) as List;

      // 3. Buscar al cliente en la cartera
      final clienteEncontrado = _clientes.firstWhere(
        (c) => c.id == partnerId,
        orElse: () => throw Exception(
          'El cliente del borrador (ID: $partnerId) no está en tu cartera actual.',
        ),
      );

      setState(() {
        _clienteSeleccionado = clienteEncontrado;
      });

      // 4. Validar estado financiero actual
      if (clienteEncontrado.bloqueado) {
        await _mostrarAlertaBloqueo(clienteEncontrado);
      }

      // 5. Cargar Sucursales y Seleccionar la del borrador
      await _cargarSucursales(clienteEncontrado);
      if (shippingId != null && shippingId != partnerId) {
        try {
          _sucursalSeleccionada = _sucursales.firstWhere(
            (s) => s.id == shippingId,
          );
        } catch (_) {
          _sucursalSeleccionada = null;
        }
      }

      // 6. Cargar catálogo con los precios de este cliente
      await _cargarProductos(clienteEncontrado);

      // 7. Emparejar las líneas del borrador con el catálogo resguardando los tipos de datos
      _carrito = [];
      for (var linea in lineasGuardadas) {
        try {
          final productIdRaw = linea['product_id'];
          if (productIdRaw == null) continue;
          final int productId = productIdRaw is int
              ? productIdRaw
              : (int.tryParse(productIdRaw.toString()) ?? 0);

          final producto = _productos.firstWhere((p) => p.id == productId);
          double qty = (linea['cantidad'] ?? 0).toDouble();
          _carrito.add(CarritoItem(producto: producto)..cantidad = qty.toInt());
        } catch (_) {
          debugPrint(
            'Producto no encontrado en catálogo para el ID: ${linea['product_id']}',
          );
        }
      }

      setState(() {
        _cargandoInicial = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error abriendo el borrador: $e';
        _cargandoInicial = false;
      });
    }
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
                'La situación financiera de este cliente ha cambiado.\nSolo puedes actualizar la cotización, pero no confirmarla.',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
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

  Future<void> _cargarSucursales(Cliente cliente) async {
    try {
      final data = await ApiService.get('clientes/${cliente.id}/sucursales');
      final lista = (data['sucursales'] ?? []) as List;
      if (mounted) {
        setState(
          () => _sucursales = lista.map((e) => Sucursal.fromJson(e)).toList(),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _sucursales = []);
      }
    }
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
            '¿Deseas eliminar "${item.producto.nombre}" del borrador?',
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
    return index < 0 ? 0 : _carrito[index].cantidad;
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

  Future<void> _actualizarVenta(String actionType) async {
    if (_clienteSeleccionado == null || _carrito.isEmpty) return;

    try {
      final payload = {
        'id': widget
            .ventaId, // BYPASS: Enviamos el ID dentro del body para que Node lo detecte
        'lineas': _carrito.map((e) => e.toVentaJson()).toList(),
        'nota': _notaController.text.trim(),
        'forzar_contado': false,
        'action': actionType,
      };

      // Usamos el POST nativo de siempre, sin inventar rutas nuevas
      final respuesta = await ApiService.post('ventas', payload);

      if (!mounted) return;

      final folio = respuesta['folio'] ?? '';
      final tipo = respuesta['tipo'] ?? '';
      final total = (respuesta['total'] ?? 0).toDouble();

      Navigator.pop(context);

      await Navigator.pushReplacement(
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
          title: const Text('Error al procesar'),
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

  Widget _buildControlProducto(Producto producto, {bool compacto = true}) {
    final sinStock = producto.stockReal <= 0;
    final cantidad = _cantidadProducto(producto);

    late final Widget contenido;

    if (sinStock) {
      contenido = const Text(
        'Sin stock',
        style: TextStyle(fontSize: 10.5, color: Colors.grey),
      );
    } else if (cantidad == 0) {
      contenido = IconButton(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        onPressed: () => _agregarCarrito(producto),
        icon: const Icon(Icons.add_circle, color: Color(0xFFD41C1C)),
      );
    } else {
      contenido = Container(
        padding: EdgeInsets.symmetric(
          horizontal: compacto ? 4 : 6,
          vertical: compacto ? 2 : 4,
        ),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () async {
                final item = _carrito.firstWhere(
                  (e) => e.producto.id == producto.id,
                );
                await _quitarCarrito(item);
              },
              child: Icon(
                Icons.remove_circle,
                color: Colors.red.shade700,
                size: compacto ? 21 : 24,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: compacto ? 7 : 9),
              child: Text(
                '$cantidad',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: compacto ? 13 : 15,
                ),
              ),
            ),
            InkWell(
              onTap: cantidad >= _stockDisponible(producto)
                  ? () => _mostrarStockMaximo(producto)
                  : () => _agregarCarrito(producto),
              child: Icon(
                Icons.add_circle,
                color: cantidad >= _stockDisponible(producto)
                    ? Colors.grey
                    : const Color(0xFFD41C1C),
                size: compacto ? 21 : 24,
              ),
            ),
          ],
        ),
      );
    }
    return contenido;
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
                        'Editando Borrador',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _carrito.isEmpty
                            ? const Center(child: Text('Borrador vacío'))
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
                                            if (await _quitarCarrito(item)) {
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
                                            if (_agregarCarrito(
                                              item.producto,
                                            )) {
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
                          border: OutlineInputBorder(),
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
                                ),
                                onPressed: _carrito.isEmpty
                                    ? null
                                    : () => _actualizarVenta('draft'),
                                icon: const Icon(Icons.save_outlined),
                                label: const Text(
                                  'Actualizar Borrador',
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
                                ),
                                onPressed: _carrito.isEmpty
                                    ? null
                                    : () => _actualizarVenta('confirm'),
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
                onPressed: () => setState(() => _vistaLista = false),
              ),
              IconButton(
                tooltip: 'Vista lista',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.view_list,
                  color: _vistaLista ? const Color(0xFFD41C1C) : Colors.grey,
                ),
                onPressed: () => setState(() => _vistaLista = true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductos() {
    if (_cargandoProductos) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B2B2B)),
      );
    }

    if (_filtrados.isEmpty) {
      return const Center(child: Text('Sin productos encontrados.'));
    }

    if (_vistaLista) {
      return ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: _filtrados.length,
        itemBuilder: (context, index) {
          final p = _filtrados[index];
          return Card(
            color: _obtenerColorFondoStock(p.stockReal),
            child: ListTile(
              title: Text(p.nombre, maxLines: 2),
              subtitle: Text('Stock: ${p.stockReal.round()}'),
              trailing: SizedBox(
                width: 145,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(_money(p.precioBruto)),
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

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _filtrados.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.02,
      ),
      itemBuilder: (context, index) {
        final p = _filtrados[index];
        return Container(
          decoration: BoxDecoration(
            color: _obtenerColorFondoStock(p.stockReal),
            border: Border.all(color: _obtenerColorBordeStock(p.stockReal)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              const Expanded(
                child: Center(
                  child: Icon(Icons.inventory_2, size: 34, color: Colors.brown),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  p.nombre,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                'Stock: ${p.stockReal.round()}',
                style: const TextStyle(fontSize: 10),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _money(p.precioBruto),
                        style: const TextStyle(
                          color: Color(0xFFD41C1C),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildControlProducto(p),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoInicial) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF8B2B2B)),
        ),
      );
    }
    if (_error.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(backgroundColor: const Color(0xFF8B2B2B)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(_error),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        toolbarHeight: 56,
        backgroundColor: const Color(0xFF8B2B2B),
        title: const Text(
          'Editar Borrador',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cliente',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  _clienteSeleccionado?.nombre ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (_sucursalSeleccionada != null)
                  Text(
                    'Despacho: ${_sucursalSeleccionada!.nombre} - ${_sucursalSeleccionada!.direccion}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
              ],
            ),
          ),
          _buildFiltrosCompactos(),
          Expanded(child: _buildProductos()),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$_cantidadCarrito productos'),
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
                      backgroundColor: const Color(0xFFD41C1C),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _cantidadCarrito == 0 ? null : _mostrarCarrito,
                    child: const Text(
                      'Ver carrito y actualizar',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
