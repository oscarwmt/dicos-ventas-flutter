import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/cliente.dart';
import '../services/api_service.dart';

class CompletarFichaScreen extends StatefulWidget {
  final Cliente cliente;

  const CompletarFichaScreen({super.key, required this.cliente});

  @override
  State<CompletarFichaScreen> createState() => _CompletarFichaScreenState();
}

class _CompletarFichaScreenState extends State<CompletarFichaScreen> {
  final _formKey = GlobalKey<FormState>();

  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  final _direccionController = TextEditingController();
  final _actividadController = TextEditingController();
  final _contactoNombreController = TextEditingController();
  final _contactoTelefonoController = TextEditingController();
  final _contactoEmailController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String _error = '';

  List<Map<String, dynamic>> _regiones = [];
  List<Map<String, dynamic>> _comunas = [];
  List<Map<String, dynamic>> _sectores = [];
  List<Map<String, dynamic>> _comunasFiltradas = [];

  Map<String, dynamic>? _regionSeleccionada;
  Map<String, dynamic>? _comunaSeleccionada;
  Map<String, dynamic>? _sectorSeleccionado;

  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _telefonoController.text = widget.cliente.telefono;
    _emailController.text = widget.cliente.email;
    _direccionController.text = widget.cliente.direccion;
    _actividadController.text = widget.cliente.actividad;
    _cargarDatosFormulario();
  }

  @override
  void dispose() {
    _telefonoController.dispose();
    _emailController.dispose();
    _direccionController.dispose();
    _actividadController.dispose();
    _contactoNombreController.dispose();
    _contactoTelefonoController.dispose();
    _contactoEmailController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosFormulario() async {
    try {
      final data = await ApiService.get('clientes/datos-formulario');

      final regiones = List<Map<String, dynamic>>.from(data['regiones'] ?? []);
      final comunas = List<Map<String, dynamic>>.from(data['comunas'] ?? []);
      final sectores = List<Map<String, dynamic>>.from(data['sectores'] ?? []);

      Map<String, dynamic>? comunaInicial;
      Map<String, dynamic>? regionInicial;
      Map<String, dynamic>? sectorInicial;

      for (final comuna in comunas) {
        if (comuna['id'] == widget.cliente.comunaId) {
          comunaInicial = comuna;
          break;
        }
      }

      if (comunaInicial != null) {
        for (final region in regiones) {
          if (region['id'] == comunaInicial['region_id']) {
            regionInicial = region;
            break;
          }
        }
      }

      for (final sector in sectores) {
        if (sector['id'] == widget.cliente.sectorId) {
          sectorInicial = sector;
          break;
        }
      }

      final comunasFiltradas = regionInicial == null
          ? <Map<String, dynamic>>[]
          : comunas
                .where((c) => c['region_id'] == regionInicial!['id'])
                .toList();

      if (!mounted) return;

      setState(() {
        _regiones = regiones;
        _comunas = comunas;
        _sectores = sectores;
        _regionSeleccionada = regionInicial;
        _comunaSeleccionada = comunaInicial;
        _sectorSeleccionado = sectorInicial;
        _comunasFiltradas = comunasFiltradas;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error cargando datos del formulario: $e';
        _isLoading = false;
      });
    }
  }

  String _nombreItem(Map<String, dynamic>? item) {
    if (item == null) return '';
    return (item['name'] ?? item['display_name'] ?? '').toString();
  }

  Future<Map<String, dynamic>?> _buscarSeleccion({
    required String titulo,
    required List<Map<String, dynamic>> items,
  }) async {
    final controller = TextEditingController();
    List<Map<String, dynamic>> filtrados = List.from(items);

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
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
                  height: MediaQuery.of(context).size.height * 0.75,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          labelText: 'Buscar',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) {
                          final q = value.toLowerCase().trim();
                          setModalState(() {
                            filtrados = items.where((item) {
                              return _nombreItem(
                                item,
                              ).toLowerCase().contains(q);
                            }).toList();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: filtrados.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = filtrados[index];
                            return ListTile(
                              title: Text(_nombreItem(item)),
                              onTap: () => Navigator.pop(context, item),
                            );
                          },
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

  Future<void> _capturarGps() async {
    try {
      final servicioActivo = await Geolocator.isLocationServiceEnabled();
      if (!servicioActivo) throw Exception('El GPS está desactivado.');

      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        throw Exception('Permiso de ubicación denegado.');
      }

      final pos = await Geolocator.getCurrentPosition();

      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (e) {
      _mostrarError(e.toString());
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_comunaSeleccionada == null || _sectorSeleccionado == null) {
      _mostrarError('Debes seleccionar comuna y sector.');
      return;
    }

    if (_lat == null || _lng == null) {
      _mostrarError('Debes capturar GPS antes de guardar.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final payload = {
        'telefono': _telefonoController.text.trim(),
        'email': _emailController.text.trim(),
        'direccion': _direccionController.text.trim(),
        'comuna_id': _comunaSeleccionada!['id'],
        'sector_id': _sectorSeleccionado!['id'],
        'actividad': _actividadController.text.trim(),
        'contacto_nombre': _contactoNombreController.text.trim(),
        'contacto_telefono': _contactoTelefonoController.text.trim(),
        'contacto_email': _contactoEmailController.text.trim(),
        'lat': _lat,
        'lng': _lng,
      };

      await ApiService.put('clientes/${widget.cliente.id}', payload);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _mostrarError(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  String? _obligatorio(String? value) {
    if (value == null || value.trim().isEmpty) return 'Campo obligatorio';
    return null;
  }

  Widget _selector({
    required String label,
    required Map<String, dynamic>? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.search),
        ),
        child: Text(
          value == null ? 'Seleccionar...' : _nombreItem(value),
          style: TextStyle(
            color: value == null ? Colors.grey : Colors.black,
            fontWeight: value == null ? FontWeight.normal : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF8B2B2B)),
        ),
      );
    }

    if (_error.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF8B2B2B),
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'FICHA INCOMPLETA',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(child: Text(_error)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B2B2B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'FICHA INCOMPLETA',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.cliente.nombre,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: const Text(
                'Por favor completa los datos pendientes para poder continuar.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),

            _section('Datos de empresa'),
            TextFormField(
              controller: _telefonoController,
              decoration: const InputDecoration(labelText: 'Teléfono *'),
              validator: _obligatorio,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email *'),
              validator: _obligatorio,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _direccionController,
              decoration: const InputDecoration(labelText: 'Dirección *'),
              validator: _obligatorio,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _actividadController,
              decoration: const InputDecoration(
                labelText: 'Actividad comercial *',
              ),
              validator: _obligatorio,
            ),

            const SizedBox(height: 20),
            _section('Ubicación'),
            _selector(
              label: 'Región *',
              value: _regionSeleccionada,
              onTap: () async {
                final item = await _buscarSeleccion(
                  titulo: 'Buscar región',
                  items: _regiones,
                );
                if (item == null) return;
                setState(() {
                  _regionSeleccionada = item;
                  _comunaSeleccionada = null;
                  _comunasFiltradas = _comunas
                      .where((c) => c['region_id'] == item['id'])
                      .toList();
                });
              },
            ),
            const SizedBox(height: 12),
            _selector(
              label: 'Comuna *',
              value: _comunaSeleccionada,
              onTap: () async {
                final item = await _buscarSeleccion(
                  titulo: 'Buscar comuna',
                  items: _comunasFiltradas,
                );
                if (item == null) return;
                setState(() => _comunaSeleccionada = item);
              },
            ),
            const SizedBox(height: 12),
            _selector(
              label: 'Sector *',
              value: _sectorSeleccionado,
              onTap: () async {
                final item = await _buscarSeleccion(
                  titulo: 'Buscar sector',
                  items: _sectores,
                );
                if (item == null) return;
                setState(() => _sectorSeleccionado = item);
              },
            ),

            const SizedBox(height: 20),
            _section('Contacto principal'),
            TextFormField(
              controller: _contactoNombreController,
              decoration: const InputDecoration(labelText: 'Nombre contacto *'),
              validator: widget.cliente.tieneContacto ? null : _obligatorio,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactoTelefonoController,
              decoration: const InputDecoration(
                labelText: 'Teléfono contacto *',
              ),
              validator: widget.cliente.tieneContacto ? null : _obligatorio,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactoEmailController,
              decoration: const InputDecoration(labelText: 'Email contacto *'),
              validator: widget.cliente.tieneContacto ? null : _obligatorio,
            ),

            const SizedBox(height: 20),
            _section('GPS'),
            OutlinedButton.icon(
              onPressed: _capturarGps,
              icon: const Icon(Icons.my_location),
              label: Text(
                _lat == null
                    ? 'Capturar ubicación'
                    : 'GPS capturado: ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD41C1C),
                  foregroundColor: Colors.white,
                ),
                onPressed: _isSaving ? null : _guardar,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Guardar y continuar',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Colors.grey,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
