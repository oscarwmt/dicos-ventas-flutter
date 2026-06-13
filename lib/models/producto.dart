class Producto {
  final int id;
  final String nombre;
  final String codigo;
  final double precioBruto;
  final double precioNeto;
  final double stockReal;
  final String unidad;
  final String categoria;
  final String marca;

  Producto({
    required this.id,
    required this.nombre,
    required this.codigo,
    required this.precioBruto,
    required this.precioNeto,
    required this.stockReal,
    required this.unidad,
    required this.categoria,
    required this.marca,
  });

  factory Producto.fromJson(Map<String, dynamic> json) {
    return Producto(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? '',
      codigo: json['codigo'] ?? '',
      precioBruto: (json['precio_bruto'] ?? 0).toDouble(),
      precioNeto: (json['precio_neto'] ?? 0).toDouble(),
      stockReal: (json['stock_real'] ?? 0).toDouble(),
      unidad: json['unidad'] ?? 'Unidad',
      categoria: json['categoria'] ?? 'Sin Categoría',
      marca: json['marca'] ?? 'Sin Marca',
    );
  }
}
