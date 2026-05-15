import 'package:cloud_firestore/cloud_firestore.dart';

class Reserva {
  final String? id;
  final String nomeLocatario;
  final String telefone;
  final String email;
  final DateTime dataInicio;
  final DateTime dataFim;
  final double valor;
  final double valorEntrada;
  final String statusPagamento; // 'pendente', 'entrada', 'pago_total'
  final String observacoes;
  final DateTime criadoEm;

  Reserva({
    this.id,
    required this.nomeLocatario,
    required this.telefone,
    this.email = '',
    required this.dataInicio,
    required this.dataFim,
    required this.valor,
    this.valorEntrada = 0,
    this.statusPagamento = 'pendente',
    this.observacoes = '',
    DateTime? criadoEm,
  }) : criadoEm = criadoEm ?? DateTime.now();

  double get valorRestante => valor - valorEntrada;

  int get numeroDias => dataFim.difference(dataInicio).inDays + 1;

  bool get isAtiva {
    final hoje = _soData(DateTime.now());
    return !_soData(dataInicio).isAfter(hoje) && !_soData(dataFim).isBefore(hoje);
  }

  bool get isFutura => _soData(dataInicio).isAfter(_soData(DateTime.now()));

  bool get isPast => _soData(dataFim).isBefore(_soData(DateTime.now()));

  static DateTime _soData(DateTime d) => DateTime(d.year, d.month, d.day);

  factory Reserva.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Reserva(
      id: doc.id,
      nomeLocatario: data['nomeLocatario'] ?? '',
      telefone: data['telefone'] ?? '',
      email: data['email'] ?? '',
      dataInicio: (data['dataInicio'] as Timestamp).toDate(),
      dataFim: (data['dataFim'] as Timestamp).toDate(),
      valor: (data['valor'] ?? 0.0).toDouble(),
      valorEntrada: (data['valorEntrada'] ?? 0.0).toDouble(),
      statusPagamento: data['statusPagamento'] ?? 'pendente',
      observacoes: data['observacoes'] ?? '',
      criadoEm: (data['criadoEm'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'nomeLocatario': nomeLocatario,
        'telefone': telefone,
        'email': email,
        'dataInicio': Timestamp.fromDate(dataInicio),
        'dataFim': Timestamp.fromDate(dataFim),
        'valor': valor,
        'valorEntrada': valorEntrada,
        'statusPagamento': statusPagamento,
        'observacoes': observacoes,
        'criadoEm': Timestamp.fromDate(criadoEm),
      };

  Reserva copyWith({
    String? id,
    String? nomeLocatario,
    String? telefone,
    String? email,
    DateTime? dataInicio,
    DateTime? dataFim,
    double? valor,
    double? valorEntrada,
    String? statusPagamento,
    String? observacoes,
  }) {
    return Reserva(
      id: id ?? this.id,
      nomeLocatario: nomeLocatario ?? this.nomeLocatario,
      telefone: telefone ?? this.telefone,
      email: email ?? this.email,
      dataInicio: dataInicio ?? this.dataInicio,
      dataFim: dataFim ?? this.dataFim,
      valor: valor ?? this.valor,
      valorEntrada: valorEntrada ?? this.valorEntrada,
      statusPagamento: statusPagamento ?? this.statusPagamento,
      observacoes: observacoes ?? this.observacoes,
      criadoEm: criadoEm,
    );
  }
}
