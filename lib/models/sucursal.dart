class Sucursal {
  final int id;
  final String nombre;
  final String direccion;
  final String ciudad;
  final String tipo;

  Sucursal({
    required this.id,
    required this.nombre,
    required this.direccion,
    required this.ciudad,
    required this.tipo,
  });

  factory Sucursal.fromJson(Map<String, dynamic> json) {
    return Sucursal(
      id: json['id'] ?? 0,
      nombre: (json['name'] ?? '').toString(),
      direccion: (json['street'] ?? '').toString(),
      ciudad: json['city'] == false || json['city'] == null
          ? ''
          : json['city'].toString(),
      tipo: (json['type'] ?? '').toString(),
    );
  }
}
