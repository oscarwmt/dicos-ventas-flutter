class Cliente {
  final int id;
  final String nombre;
  final String rut;
  final String ciudad;
  final String telefono;
  final String email;
  final String direccion;
  final int? comunaId;
  final int? sectorId;
  final String actividad;
  final bool tieneContacto;
  final String plazoPago;
  final int limiteCredito;
  final int deudaActual;
  final int montoVencido;
  final bool bloqueado;
  final String razonBloqueo;
  final int? listaPreciosId;

  Cliente({
    required this.id,
    required this.nombre,
    required this.rut,
    required this.ciudad,
    required this.telefono,
    required this.email,
    required this.direccion,
    required this.comunaId,
    required this.sectorId,
    required this.actividad,
    required this.tieneContacto,
    required this.plazoPago,
    required this.limiteCredito,
    required this.deudaActual,
    required this.montoVencido,
    required this.bloqueado,
    required this.razonBloqueo,
    required this.listaPreciosId,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? 'Sin nombre',
      rut: json['rut'] ?? '',
      ciudad: json['ciudad'] ?? '',
      telefono: json['telefono'] ?? '',
      email: json['email'] ?? '',
      direccion: json['direccion'] ?? '',
      comunaId: json['comuna_id'],
      sectorId: json['sector_id'],
      actividad: json['actividad'] ?? '',
      tieneContacto: json['tiene_contacto'] ?? false,
      plazoPago: json['plazo_pago'] ?? 'Contado',
      limiteCredito: json['limite_credito'] ?? 0,
      deudaActual: json['deuda_actual'] ?? 0,
      montoVencido: json['monto_vencido'] ?? 0,
      bloqueado: json['bloqueado'] ?? false,
      razonBloqueo: json['razon_bloqueo'] ?? '',
      listaPreciosId: json['lista_precios_id'],
    );
  }

  bool get fichaIncompleta {
    return telefono.trim().isEmpty ||
        email.trim().isEmpty ||
        direccion.trim().isEmpty ||
        comunaId == null ||
        sectorId == null ||
        actividad.trim().isEmpty ||
        !tieneContacto;
  }
}
