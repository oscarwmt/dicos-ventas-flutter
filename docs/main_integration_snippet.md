# Integración en main.dart

Asegura estos imports:

```dart
import 'tabs/vender_tab.dart';
import 'tabs/ventas_tab.dart';
```

En la lista de pantallas de HomeScreen:

```dart
final List<Widget> _pantallas = [
  const InicioTab(),
  const ClientesTab(),
  const VenderTab(),
  const Center(child: Text('Pantalla CRM (En construcción)')),
  const VentasTab(),
];
```
