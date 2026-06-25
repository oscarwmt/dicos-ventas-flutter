import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CrearClienteScreen extends StatefulWidget {
  const CrearClienteScreen({super.key});

  @override
  State<CrearClienteScreen> createState() => _CrearClienteScreenState();
}

class _CrearClienteScreenState extends State<CrearClienteScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombreController = TextEditingController();
  final _rutController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  final _direccionController = TextEditingController();
  final _ciudadController = TextEditingController();

  final _contactoNombreController = TextEditingController();
  final _contactoTelefonoController = TextEditingController();
  final _contactoEmailController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _replicarContacto = false;
  String _error = '';

  List<Map<String, dynamic>> _regiones = [];
  List<Map<String, dynamic>> _comunas = [];
  List<Map<String, dynamic>> _sectores = [];
  List<Map<String, dynamic>> _actividades = [];
  List<Map<String, dynamic>> _comunasFiltradas = [];

  Map<String, dynamic>? _regionSeleccionada;
  Map<String, dynamic>? _comunaSeleccionada;
  Map<String, dynamic>? _sectorSeleccionado;
  Map<String, dynamic>? _actividadSeleccionada;

  @override
  void initState() {
    super.initState();
    _cargarDatosFormulario();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _rutController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _direccionController.dispose();
    _ciudadController.dispose();
    _contactoNombreController.dispose();
    _contactoTelefonoController.dispose();
    _contactoEmailController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosFormulario() async {
    try {
      final data = await ApiService.get('clientes/datos-formulario');

      if (!mounted) return;

      setState(() {
        _regiones = List<Map<String, dynamic>>.from(data['regiones'] ?? []);
        _comunas = List<Map<String, dynamic>>.from(data['comunas'] ?? []);
        _sectores = List<Map<String, dynamic>>.from(data['sectores'] ?? []);
        _actividades = List<Map<String, dynamic>>.from(
          data['actividades'] ?? [],
        );
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

  String? _obligatorio(String? value) {
    if (value == null || value.trim().isEmpty) return 'Campo obligatorio';
    return null;
  }

  String _limpiarRut(String value) {
    return value.replaceAll('.', '').replaceAll(' ', '').toUpperCase();
  }

  void _formatearRut() {
    final limpio = _limpiarRut(_rutController.text);
    if (limpio.isEmpty) return;

    final partes = limpio.split('-');
    final cuerpo = partes[0].replaceAll(RegExp(r'[^0-9]'), '');
    final dv = partes.length > 1
        ? partes[1].replaceAll(RegExp(r'[^0-9K]'), '')
        : '';

    if (cuerpo.isEmpty) return;

    final invertido = cuerpo.split('').reversed.toList();
    final buffer = StringBuffer();

    for (int i = 0; i < invertido.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write('.');
      buffer.write(invertido[i]);
    }

    final formateadoCuerpo = buffer.toString().split('').reversed.join();
    final formateado = dv.isEmpty ? formateadoCuerpo : '$formateadoCuerpo-$dv';

    _rutController.value = TextEditingValue(
      text: formateado,
      selection: TextSelection.collapsed(offset: formateado.length),
    );
  }

  bool _rutValido(String rut) {
    final limpio = _limpiarRut(rut);
    if (!limpio.contains('-')) return false;

    final partes = limpio.split('-');
    if (partes.length != 2) return false;

    final cuerpo = partes[0].replaceAll('.', '');
    final dv = partes[1].toUpperCase();

    if (cuerpo.isEmpty || dv.isEmpty) return false;

    int suma = 0;
    int multiplo = 2;

    for (int i = cuerpo.length - 1; i >= 0; i--) {
      suma += int.parse(cuerpo[i]) * multiplo;
      multiplo = multiplo == 7 ? 2 : multiplo + 1;
    }

    final resto = suma % 11;
    final resultado = 11 - resto;

    String dvEsperado;
    if (resultado == 11) {
      dvEsperado = '0';
    } else if (resultado == 10) {
      dvEsperado = 'K';
    } else {
      dvEsperado = resultado.toString();
    }

    return dv == dvEsperado;
  }

  String? _validarRut(String? value) {
    if (value == null || value.trim().isEmpty) return 'Campo obligatorio';
    if (!_rutValido(value)) return 'RUT inválido';
    return null;
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

  void _replicarDatosContacto(bool value) {
    setState(() {
      _replicarContacto = value;

      if (value) {
        _contactoNombreController.text = _nombreController.text.trim();
        _contactoTelefonoController.text = _telefonoController.text.trim();
        _contactoEmailController.text = _emailController.text.trim();
      } else {
        _contactoNombreController.clear();
        _contactoTelefonoController.clear();
        _contactoEmailController.clear();
      }
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_regionSeleccionada == null ||
        _comunaSeleccionada == null ||
        _sectorSeleccionado == null ||
        _actividadSeleccionada == null) {
      _mostrarError('Debes seleccionar región, comuna, sector y actividad.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final payload = {
        'nombre': _nombreController.text.trim(),
        'rut': _rutController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'email': _emailController.text.trim(),
        'direccion': _direccionController.text.trim(),
        'ciudad': _ciudadController.text.trim(),
        'comuna_id': _comunaSeleccionada!['id'],
        'sector_id': _sectorSeleccionado!['id'],
        'actividad': _nombreItem(_actividadSeleccionada),
        'contacto_nombre': _contactoNombreController.text.trim(),
        'contacto_telefono': _contactoTelefonoController.text.trim(),
        'contacto_email': _contactoEmailController.text.trim(),
      };

      await ApiService.post('clientes', payload);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cliente creado correctamente'),
          backgroundColor: Colors.green,
        ),
      );

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
            'Nuevo Cliente',
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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nuevo Cliente',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Pago contado · Sin crédito',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('Datos de facturación'),
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Razón social *'),
              validator: _obligatorio,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rutController,
              decoration: const InputDecoration(labelText: 'RUT *'),
              validator: _validarRut,
              onChanged: (_) => _formatearRut(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telefonoController,
              decoration: const InputDecoration(
                labelText: 'Teléfono empresa *',
              ),
              keyboardType: TextInputType.phone,
              validator: _obligatorio,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email facturación *',
              ),
              keyboardType: TextInputType.emailAddress,
              validator: _obligatorio,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _direccionController,
              decoration: const InputDecoration(labelText: 'Dirección *'),
              validator: _obligatorio,
            ),
            const SizedBox(height: 12),

            _selector(
              label: 'Actividad comercial *',
              value: _actividadSeleccionada,
              onTap: () async {
                final item = await _buscarSeleccion(
                  titulo: 'Buscar actividad',
                  items: _actividades,
                );
                if (item == null) return;
                setState(() => _actividadSeleccionada = item);
              },
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
                if (_regionSeleccionada == null) {
                  _mostrarError('Primero selecciona una región.');
                  return;
                }

                final item = await _buscarSeleccion(
                  titulo: 'Buscar comuna',
                  items: _comunasFiltradas,
                );
                if (item == null) return;
                setState(() {
                  _comunaSeleccionada = item;
                  _ciudadController.text = _nombreItem(item);
                });
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ciudadController,
              decoration: const InputDecoration(labelText: 'Ciudad *'),
              validator: _obligatorio,
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
            CheckboxListTile(
              value: _replicarContacto,
              onChanged: (value) => _replicarDatosContacto(value ?? false),
              title: const Text('Mismos datos del titular'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            TextFormField(
              controller: _contactoNombreController,
              decoration: const InputDecoration(labelText: 'Nombre contacto *'),
              validator: _obligatorio,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactoTelefonoController,
              decoration: const InputDecoration(
                labelText: 'Teléfono contacto *',
              ),
              keyboardType: TextInputType.phone,
              validator: _obligatorio,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactoEmailController,
              decoration: const InputDecoration(labelText: 'Email contacto *'),
              keyboardType: TextInputType.emailAddress,
              validator: _obligatorio,
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
                        'Guardar cliente',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
