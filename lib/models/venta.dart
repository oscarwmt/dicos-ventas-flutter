class Venta {
  final int id;
  final String nombre;
  final String cliente;
  final String fecha;
  final String fechaRaw;
  final double total;
  final String estado;
  final int lineas;
  final String invoiceStatus;

  Venta({
    required this.id,
    required this.nombre,
    required this.cliente,
    required this.fecha,
    required this.fechaRaw,
    required this.total,
    required this.estado,
    required this.lineas,
    required this.invoiceStatus,
  });

  bool get estaFacturada => invoiceStatus == 'invoiced';

  factory Venta.fromJson(Map<String, dynamic> json) {
    return Venta(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? '',
      cliente: json['cliente'] ?? 'Desconocido',
      fecha: json['fecha'] ?? '',
      fechaRaw: json['fecha_raw'] ?? '',
      total: (json['total'] ?? 0.0).toDouble(),
      estado: json['estado'] ?? '',
      lineas: json['lineas'] ?? 0,
      invoiceStatus: json['invoice_status'] ?? 'no',
    );
  }
}
