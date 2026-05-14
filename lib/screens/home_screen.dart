import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/reserva.dart';
import '../services/firestore_service.dart';
import 'form_reserva_screen.dart';
import 'detalhe_reserva_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = FirestoreService();
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        title: const Text(
          '🏡 Sítio - Reservas',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Reserva>>(
        stream: _service.streamReservas(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF2E7D32)),
                  SizedBox(height: 16),
                  Text('Carregando...', style: TextStyle(fontSize: 18)),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erro ao carregar dados.\nVerifique sua conexão.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, color: Colors.red),
                ),
              ),
            );
          }

          final reservas = snapshot.data ?? [];

          Reserva? reservaAtiva;
          for (final r in reservas) {
            if (r.isAtiva) {
              reservaAtiva = r;
              break;
            }
          }

          final Set<DateTime> datasBloqueadas = {};
          for (final r in reservas) {
            DateTime d = DateTime(r.dataInicio.year, r.dataInicio.month, r.dataInicio.day);
            final fim = DateTime(r.dataFim.year, r.dataFim.month, r.dataFim.day);
            while (!d.isAfter(fim)) {
              datasBloqueadas.add(d);
              d = d.add(const Duration(days: 1));
            }
          }

          final proximas = reservas.where((r) => !r.isPast).toList();
          final passadas = reservas.where((r) => r.isPast).toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              _StatusBanner(reservaAtiva: reservaAtiva),
              _Calendario(
                focusedDay: _focusedDay,
                datasBloqueadas: datasBloqueadas,
                onPageChanged: (d) => setState(() => _focusedDay = d),
              ),
              if (proximas.isNotEmpty) ...[
                const _SectionTitle(title: 'Próximas Reservas'),
                ...proximas.map((r) => _ReservaCard(
                      reserva: r,
                      onTap: () => _abrirDetalhe(r, reservas),
                    )),
              ],
              if (passadas.isNotEmpty) ...[
                const _SectionTitle(title: 'Reservas Passadas'),
                ...passadas.map((r) => _ReservaCard(
                      reserva: r,
                      onTap: () => _abrirDetalhe(r, reservas),
                    )),
              ],
              if (reservas.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.event_available, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Nenhuma reserva ainda.\nToque no botão abaixo para adicionar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FormReservaScreen()),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 28),
        label: const Text(
          'Nova Reserva',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _abrirDetalhe(Reserva r, List<Reserva> todas) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetalheReservaScreen(reserva: r, todasReservas: todas)),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final Reserva? reservaAtiva;

  const _StatusBanner({this.reservaAtiva});

  @override
  Widget build(BuildContext context) {
    final ocupado = reservaAtiva != null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ocupado ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            ocupado ? Icons.home : Icons.check_circle,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 8),
          Text(
            ocupado ? 'OCUPADO HOJE' : 'DISPONÍVEL HOJE',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          if (ocupado) ...[
            const SizedBox(height: 8),
            Text(
              reservaAtiva!.nomeLocatario,
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
            Text(
              '${DateFormat('dd/MM').format(reservaAtiva!.dataInicio)} até ${DateFormat('dd/MM/yyyy').format(reservaAtiva!.dataFim)}',
              style: const TextStyle(color: Colors.white70, fontSize: 17),
            ),
          ],
        ],
      ),
    );
  }
}

class _Calendario extends StatelessWidget {
  final DateTime focusedDay;
  final Set<DateTime> datasBloqueadas;
  final void Function(DateTime) onPageChanged;

  const _Calendario({
    required this.focusedDay,
    required this.datasBloqueadas,
    required this.onPageChanged,
  });

  bool _isOcupado(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return datasBloqueadas.contains(d);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: TableCalendar(
          locale: 'pt_BR',
          firstDay: DateTime(2020),
          lastDay: DateTime(2030),
          focusedDay: focusedDay,
          onPageChanged: onPageChanged,
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            leftChevronIcon: Icon(Icons.chevron_left, size: 28),
            rightChevronIcon: Icon(Icons.chevron_right, size: 28),
          ),
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: const Color(0xFF1565C0).withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
            todayTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            defaultTextStyle: const TextStyle(fontSize: 15),
            weekendTextStyle: const TextStyle(fontSize: 15, color: Colors.red),
          ),
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (ctx, day, focusedDay) {
              if (_isOcupado(day)) {
                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF9A9A),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${day.day}',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFFC62828),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }
              return null;
            },
            todayBuilder: (ctx, day, focusedDay) {
              final ocupadoHoje = _isOcupado(day);
              return Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: ocupadoHoje ? const Color(0xFFC62828) : const Color(0xFF1565C0),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${day.day}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF424242),
        ),
      ),
    );
  }
}

class _ReservaCard extends StatelessWidget {
  final Reserva reserva;
  final VoidCallback onTap;

  const _ReservaCard({required this.reserva, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    Color statusColor;
    String statusLabel;

    if (reserva.isAtiva) {
      statusColor = const Color(0xFFC62828);
      statusLabel = 'HOJE';
    } else if (reserva.isFutura) {
      statusColor = const Color(0xFF1565C0);
      statusLabel = 'FUTURO';
    } else {
      statusColor = Colors.grey;
      statusLabel = 'PASSADO';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 70,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            reserva.nomeLocatario,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: statusColor),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${fmt.format(reserva.dataInicio)} → ${fmt.format(reserva.dataFim)}  (${reserva.numeroDias} dias)',
                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'R\$ ${NumberFormat('#,##0.00', 'pt_BR').format(reserva.valor)}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
