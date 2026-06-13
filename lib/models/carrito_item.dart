import 'producto.dart';

class CarritoItem {
  final Producto producto;
  int cantidad;

  CarritoItem({
    required this.producto,
    this.cantidad = 1,
  });

  double get total => producto.precioBruto * cantidad;

  Map<String, dynamic> toVentaJson() {
    return {
      'product_id': producto.id,
      'cantidad': cantidad,
      'precio': producto.precioNeto,
    };
  }
}
