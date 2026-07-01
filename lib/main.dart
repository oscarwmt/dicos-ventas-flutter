import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config/api_config.dart';
import 'models/cliente.dart';
import 'services/api_service.dart';
import 'tabs/vender_tab.dart';
import 'tabs/ventas_tab.dart';
import 'services/session_manager.dart';
import 'screens/crear_cliente_screen.dart';
import 'tabs/dashboard_tab.dart';

void main() {
  runApp(const DicosVentasApp());
}

class DicosVentasApp extends StatelessWidget {
  const DicosVentasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DICOS Ventas',
      debugShowCheckedModeBanner: false,
      navigatorKey: SessionManager.navigatorKey,
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8B2B2B)),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  bool _logged = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    setState(() {
      _logged = token != null && token.isNotEmpty;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return _logged ? const HomeScreen() : const LoginScreen();
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  String _error = '';

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': _usernameController.text.trim(),
          'password': _passwordController.text.trim(),
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(data['error'] ?? 'Credenciales inválidas');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token'] ?? '');
      await prefs.setInt('uid', data['uid'] ?? 0);
      await prefs.setString('name', data['name'] ?? 'Vendedor');

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF8B2B2B),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo_dicos.jpg',
                  height: 120,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 12),
                const Text(
                  'DICOS Ventas',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Usuario',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(_error, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD41C1C),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Ingresar',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  final List<Widget> _pantallas = const [
    DashboardTab(),
    ClientesTab(),
    VenderTab(),
    Center(child: Text('Pantalla CRM (En construcción)')),
    VentasTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pantallas[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFD41C1C),
        unselectedItemColor: Colors.grey,
        onTap: (value) {
          setState(() {
            _index = value;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Clientes'),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Vender',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.task_alt), label: 'CRM'),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Ventas',
          ),
        ],
      ),
    );
  }
}

class InicioTab extends StatefulWidget {
  const InicioTab({super.key});

  @override
  State<InicioTab> createState() => _InicioTabState();
}

class _InicioTabState extends State<InicioTab> {
  String _name = 'Vendedor';

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString('name') ?? 'Vendedor';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B2B2B),
        automaticallyImplyLeading: false,
        title: Text(
          'Hola, $_name',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: const [
          _InicioCard(title: 'Nueva Venta', icon: Icons.shopping_cart),
          _InicioCard(title: 'Clientes', icon: Icons.people),
          _InicioCard(title: 'Mis Ventas', icon: Icons.receipt_long),
          _InicioCard(title: 'CRM', icon: Icons.task_alt),
        ],
      ),
    );
  }
}

class _InicioCard extends StatelessWidget {
  final String title;
  final IconData icon;

  const _InicioCard({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 44, color: const Color(0xFF8B2B2B)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class ClientesTab extends StatefulWidget {
  const ClientesTab({super.key});

  @override
  State<ClientesTab> createState() => _ClientesTabState();
}

class _ClientesTabState extends State<ClientesTab> {
  List<Cliente> _clientes = [];
  List<Cliente> _filtrados = [];
  bool _loading = true;
  String _error = '';
  final _buscarController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarClientes();
    _buscarController.addListener(_filtrar);
  }

  @override
  void dispose() {
    _buscarController.dispose();
    super.dispose();
  }

  Future<void> _cargarClientes() async {
    try {
      final data = await ApiService.get('clientes');
      final lista = (data['clientes'] ?? []) as List;

      setState(() {
        _clientes = lista.map((e) => Cliente.fromJson(e)).toList();
        _filtrados = _clientes;
        _loading = false;
        _error = '';
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _filtrar() {
    final q = _buscarController.text.toLowerCase().trim();

    setState(() {
      _filtrados = _clientes.where((c) {
        return c.nombre.toLowerCase().contains(q) ||
            c.rut.toLowerCase().contains(q) ||
            c.ciudad.toLowerCase().contains(q);
      }).toList();
    });
  }

  Color _estadoColor(Cliente c) {
    if (c.bloqueado) return Colors.red;
    if (c.fichaIncompleta) return Colors.orange;
    return Colors.green;
  }

  String _estadoTexto(Cliente c) {
    if (c.bloqueado) return 'Bloqueado';
    if (c.fichaIncompleta) return 'Ficha incompleta';
    return 'Activo';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B2B2B),
        automaticallyImplyLeading: false,
        title: const Text(
          'Clientes',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF8B2B2B),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo'),
        onPressed: () async {
          final creado = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CrearClienteScreen()),
          );

          if (creado == true) {
            await _cargarClientes();
          }
        },
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B2B2B)),
            )
          : _error.isNotEmpty
          ? Center(child: Text(_error))
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _buscarController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar cliente',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _cargarClientes,
                    child: ListView.separated(
                      itemCount: _filtrados.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: Colors.grey.shade200),
                      itemBuilder: (context, index) {
                        final c = _filtrados[index];

                        return ListTile(
                          tileColor: Colors.white,
                          leading: CircleAvatar(
                            backgroundColor: _estadoColor(c),
                            foregroundColor: Colors.white,
                            child: Text(
                              c.nombre.isEmpty
                                  ? '?'
                                  : c.nombre[0].toUpperCase(),
                            ),
                          ),
                          title: Text(
                            c.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('${c.rut} · ${c.ciudad}'),
                          trailing: Text(
                            _estadoTexto(c),
                            style: TextStyle(
                              color: _estadoColor(c),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
