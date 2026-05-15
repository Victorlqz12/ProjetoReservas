import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reserva.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;
  static const _col = 'reservas';

  Stream<List<Reserva>> streamReservas() {
    return _db
        .collection(_col)
        .orderBy('dataInicio')
        .snapshots()
        .map((s) => s.docs.map(Reserva.fromFirestore).toList());
  }

  Future<List<Reserva>> getReservas() async {
    final snap = await _db.collection(_col).orderBy('dataInicio').get();
    return snap.docs.map(Reserva.fromFirestore).toList();
  }

  Future<void> addReserva(Reserva r) => _db.collection(_col).add(r.toFirestore());

  Future<void> updateReserva(Reserva r) =>
      _db.collection(_col).doc(r.id).update(r.toFirestore());

  Future<void> deleteReserva(String id) => _db.collection(_col).doc(id).delete();

  static Future<bool> temInternet() async {
    try {
      final result = await InternetAddress.lookup('firestore.googleapis.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  bool hasOverlap(List<Reserva> lista, DateTime inicio, DateTime fim, String? excludeId) {
    for (final r in lista) {
      if (r.id == excludeId) continue;
      final rInicio = DateTime(r.dataInicio.year, r.dataInicio.month, r.dataInicio.day);
      final rFim = DateTime(r.dataFim.year, r.dataFim.month, r.dataFim.day);
      final novoInicio = DateTime(inicio.year, inicio.month, inicio.day);
      final novoFim = DateTime(fim.year, fim.month, fim.day);
      if (novoInicio.isBefore(rFim.add(const Duration(days: 1))) &&
          novoFim.isAfter(rInicio.subtract(const Duration(days: 1)))) {
        return true;
      }
    }
    return false;
  }
}
