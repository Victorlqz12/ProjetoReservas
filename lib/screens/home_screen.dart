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
  final _scrollController = ScrollController();
  final _buscaCtrl = TextEditingController();
  late final Stream<List<Reserva>> _stream;
  DateTime _focusedDay = DateTime.now();
  int? _mesFiltro;
  int _anoFiltro = DateTime.now().year;
  bool _buscando = false;
  String _termoBusca = '';

  @override
  void initState() {
    super.initState();
    _stream = _service.streamReservas();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _buscaCtrl.dispose();
    super.dispose();
  }

  void _abrirBusca() => setState(() => _buscando = true);

  void _fecharBusca() {
    setState(() {
      _buscando = false;
      _termoBusca = '';
      _buscaCtrl.clear();
    });
  }

  List<Reserva> _filtrarPorMes(List<Reserva> reservas) {
    final inicioFiltro = _mesFiltro != null
        ? DateTime(_anoFiltro, _mesFiltro!, 1)
        : DateTime(_anoFiltro, 1, 1);
    final fimFiltro = _mesFiltro != null
        ? DateTime(_anoFiltro, _mesFiltro! + 1, 0)
        : DateTime(_anoFiltro, 12, 31);
    return reservas
        .where((r) => !r.dataInicio.isAfter(fimFiltro) && !r.dataFim.isBefore(inicioFiltro))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        title: _buscando
            ? TextField(
                controller: _buscaCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  hintText: 'Buscar por nome...',
                  hintStyle: TextStyle(color: Colors.white60),
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _termoBusca = v),
              )
            : const Text(
                'Aluguel Sítio',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
        centerTitle: !_buscando,
        actions: [
          _buscando
              ? IconButton(icon: const Icon(Icons.close), onPressed: _fecharBusca)
              : IconButton(icon: const Icon(Icons.search), onPressed: _abrirBusca),
        ],
      ),
      body: StreamBuilder<List<Reserva>>(
        stream: _stream,
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

          if (_buscando) {
            final termo = _termoBusca.toLowerCase().trim();
            final resultados = termo.isEmpty
                ? <Reserva>[]
                : reservas
                    .where((r) => r.nomeLocatario.toLowerCase().contains(termo))
                    .toList();
            return ListView(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                if (termo.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.search, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Digite o nome do locatário.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                else if (resultados.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.person_search, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Nenhuma reserva encontrada.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                else ...[
                  _SectionTitle(title: '${resultados.length} resultado${resultados.length == 1 ? '' : 's'}'),
                  ...resultados.map((r) => _ReservaCard(
                        reserva: r,
                        onTap: () => _abrirDetalhe(r, reservas),
                      )),
                ],
              ],
            );
          }

          final proximas = _filtrarPorMes(reservas.where((r) => !r.isPast).toList());
          final passadas = _filtrarPorMes(reservas.where((r) => r.isPast).toList());
          final semResultados = reservas.isNotEmpty && proximas.isEmpty && passadas.isEmpty;

          return ListView(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              _StatusBanner(reservaAtiva: reservaAtiva),
              _Calendario(
                focusedDay: _focusedDay,
                datasBloqueadas: datasBloqueadas,
                onPageChanged: (d) => setState(() => _focusedDay = d),
              ),
              _FiltroMes(
                mesSelecionado: _mesFiltro,
                anoSelecionado: _anoFiltro,
                onMesSelecionado: (mes) => setState(() => _mesFiltro = mes),
                onAnoAlterado: (ano) => setState(() {
                  _anoFiltro = ano;
                  _mesFiltro = null;
                }),
              ),
              _ResumoFinanceiro(reservas: [...proximas, ...passadas]),
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
              if (semResultados)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Nenhuma reserva neste mês.',
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
          daysOfWeekHeight: 32,
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            leftChevronIcon: Icon(Icons.chevron_left, size: 28),
            rightChevronIcon: Icon(Icons.chevron_right, size: 28),
          ),
          daysOfWeekStyle: const DaysOfWeekStyle(
            weekdayStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
            weekendStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red),
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

class _FiltroMes extends StatelessWidget {
  final int? mesSelecionado;
  final int anoSelecionado;
  final void Function(int?) onMesSelecionado;
  final void Function(int) onAnoAlterado;

  const _FiltroMes({
    required this.mesSelecionado,
    required this.anoSelecionado,
    required this.onMesSelecionado,
    required this.onAnoAlterado,
  });

  static const _meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => onAnoAlterado(anoSelecionado - 1),
              ),
              Text(
                '$anoSelecionado',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => onAnoAlterado(anoSelecionado + 1),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('Todos', mesSelecionado == null, () => onMesSelecionado(null)),
                ...List.generate(12, (i) => _chip(
                  _meses[i],
                  mesSelecionado == i + 1,
                  () => onMesSelecionado(mesSelecionado == i + 1 ? null : i + 1),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selecionado, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selecionado ? const Color(0xFF2E7D32) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selecionado ? const Color(0xFF2E7D32) : Colors.grey.shade300,
            ),
            boxShadow: selecionado
                ? [BoxShadow(color: const Color(0xFF2E7D32).withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))]
                : [],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selecionado ? Colors.white : Colors.black87,
              fontWeight: selecionado ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
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

class _ResumoFinanceiro extends StatelessWidget {
  final List<Reserva> reservas;

  const _ResumoFinanceiro({required this.reservas});

  @override
  Widget build(BuildContext context) {
    if (reservas.isEmpty) return const SizedBox.shrink();

    double totalRecebido = 0;
    double totalAReceber = 0;

    for (final r in reservas) {
      switch (r.statusPagamento) {
        case 'pago_total':
          totalRecebido += r.valor;
          break;
        case 'entrada':
          totalRecebido += r.valorEntrada;
          totalAReceber += r.valorRestante;
          break;
        default:
          totalAReceber += r.valor;
      }
    }

    final fmt = NumberFormat('#,##0.00', 'pt_BR');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            children: [
              _ItemResumo(
                label: 'Reservas',
                valor: '${reservas.length}',
                icon: Icons.calendar_month,
                cor: const Color(0xFF1565C0),
              ),
              _Divisor(),
              _ItemResumo(
                label: 'Recebido',
                valor: 'R\$ ${fmt.format(totalRecebido)}',
                icon: Icons.check_circle_outline,
                cor: const Color(0xFF2E7D32),
              ),
              _Divisor(),
              _ItemResumo(
                label: 'A receber',
                valor: 'R\$ ${fmt.format(totalAReceber)}',
                icon: Icons.hourglass_empty,
                cor: Colors.orange.shade700,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemResumo extends StatelessWidget {
  final String label;
  final String valor;
  final IconData icon;
  final Color cor;

  const _ItemResumo({
    required this.label,
    required this.valor,
    required this.icon,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: cor, size: 22),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cor),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _Divisor extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40, color: Colors.grey.shade200);
  }
}

class _BadgePagamento extends StatelessWidget {
  final Reserva reserva;

  const _BadgePagamento({required this.reserva});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String label;
    final Color cor;

    switch (reserva.statusPagamento) {
      case 'pago_total':
        icon = Icons.check_circle;
        label = 'Pago';
        cor = const Color(0xFF2E7D32);
        break;
      case 'entrada':
        icon = Icons.payments_outlined;
        label = 'Entrada';
        cor = const Color(0xFF1565C0);
        break;
      default:
        icon = Icons.hourglass_empty;
        label = 'Pendente';
        cor = Colors.orange.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: cor),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: cor, fontWeight: FontWeight.bold),
          ),
        ],
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
                    Row(
                      children: [
                        Text(
                          'R\$ ${NumberFormat('#,##0.00', 'pt_BR').format(reserva.valor)}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _BadgePagamento(reserva: reserva),
                      ],
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
