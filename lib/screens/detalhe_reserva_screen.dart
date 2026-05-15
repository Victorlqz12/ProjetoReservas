import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/reserva.dart';
import '../services/firestore_service.dart';
import 'form_reserva_screen.dart';

class DetalheReservaScreen extends StatelessWidget {
  final Reserva reserva;
  final List<Reserva> todasReservas;

  const DetalheReservaScreen({
    super.key,
    required this.reserva,
    required this.todasReservas,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final fmtValor = NumberFormat('#,##0.00', 'pt_BR');

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (reserva.isAtiva) {
      statusColor = const Color(0xFFC62828);
      statusLabel = 'OCUPADO HOJE';
      statusIcon = Icons.home;
    } else if (reserva.isFutura) {
      statusColor = const Color(0xFF1565C0);
      statusLabel = 'RESERVA FUTURA';
      statusIcon = Icons.schedule;
    } else {
      statusColor = Colors.grey.shade600;
      statusLabel = 'RESERVA PASSADA';
      statusIcon = Icons.history;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        title: Text(
          reserva.nomeLocatario,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(statusIcon, color: Colors.white, size: 26),
                  const SizedBox(width: 10),
                  Text(
                    statusLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Secao(
              titulo: 'Locatário',
              children: [
                _InfoRow(icon: Icons.person, label: 'Nome', valor: reserva.nomeLocatario),
                _InfoRow(icon: Icons.phone, label: 'Telefone', valor: reserva.telefone),
                if (reserva.email.isNotEmpty)
                  _InfoRow(icon: Icons.email, label: 'E-mail', valor: reserva.email),
              ],
            ),
            const SizedBox(height: 12),
            _Secao(
              titulo: 'Período',
              children: [
                _InfoRow(
                  icon: Icons.login,
                  label: 'Entrada',
                  valor: fmt.format(reserva.dataInicio),
                ),
                _InfoRow(
                  icon: Icons.logout,
                  label: 'Saída',
                  valor: fmt.format(reserva.dataFim),
                ),
                _InfoRow(
                  icon: Icons.calendar_today,
                  label: 'Duração',
                  valor: '${reserva.numeroDias} ${reserva.numeroDias == 1 ? 'dia' : 'dias'}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Secao(
              titulo: 'Pagamento',
              children: [
                _InfoRow(
                  icon: Icons.attach_money,
                  label: 'Valor Total',
                  valor: 'R\$ ${fmtValor.format(reserva.valor)}',
                  destaque: true,
                ),
                if (reserva.statusPagamento == 'pago_total')
                  _InfoRow(
                    icon: Icons.check_circle,
                    label: 'Status',
                    valor: 'Pago integralmente',
                    cor: const Color(0xFF2E7D32),
                  )
                else if (reserva.statusPagamento == 'entrada') ...[
                  _InfoRow(
                    icon: Icons.payments_outlined,
                    label: 'Entrada recebida',
                    valor: 'R\$ ${fmtValor.format(reserva.valorEntrada)}',
                    cor: const Color(0xFF1565C0),
                  ),
                  _InfoRow(
                    icon: Icons.arrow_forward,
                    label: 'Restante a receber',
                    valor: 'R\$ ${fmtValor.format(reserva.valorRestante)}',
                    cor: Colors.orange.shade800,
                  ),
                ] else
                  _InfoRow(
                    icon: Icons.hourglass_empty,
                    label: 'Status',
                    valor: 'Pagamento pendente',
                    cor: Colors.orange.shade800,
                  ),
              ],
            ),
            if (reserva.observacoes.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Secao(
                titulo: 'Observações',
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Text(
                      reserva.observacoes,
                      style: const TextStyle(fontSize: 17, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            if (reserva.telefone.isNotEmpty)
              _BotaoAcao(
                label: 'Ligar para ${reserva.nomeLocatario.split(' ').first}',
                icon: Icons.phone,
                cor: const Color(0xFF1565C0),
                onTap: () => _ligar(context, reserva.telefone),
              ),
            const SizedBox(height: 10),
            _BotaoAcao(
              label: 'Editar Reserva',
              icon: Icons.edit,
              cor: const Color(0xFF2E7D32),
              onTap: () async {
                final resultado = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FormReservaScreen(
                      reserva: reserva,
                      todasReservas: todasReservas,
                    ),
                  ),
                );
                if (resultado == true && context.mounted) {
                  Navigator.pop(context);
                }
              },
            ),
            const SizedBox(height: 10),
            _BotaoAcao(
              label: 'Excluir Reserva',
              icon: Icons.delete_outline,
              cor: const Color(0xFFC62828),
              outlined: true,
              onTap: () => _confirmarExclusao(context),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Future<void> _ligar(BuildContext context, String telefone) async {
    final numero = telefone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$numero');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o discador.')),
        );
      }
    }
  }

  Future<void> _confirmarExclusao(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Excluir Reserva', style: TextStyle(fontSize: 20)),
          ],
        ),
        content: Text(
          'Tem certeza que deseja excluir a reserva de "${reserva.nomeLocatario}"?\n\nEssa ação não pode ser desfeita.',
          style: const TextStyle(fontSize: 17),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(fontSize: 17)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Excluir',
              style: TextStyle(fontSize: 17, color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true && context.mounted) {
      final temInternet = await FirestoreService.temInternet();
      if (!context.mounted) return;
      if (!temInternet) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sem conexão com a internet. Conecte-se e tente novamente.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      await FirestoreService().deleteReserva(reserva.id!);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

class _Secao extends StatelessWidget {
  final String titulo;
  final List<Widget> children;

  const _Secao({required this.titulo, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valor;
  final bool destaque;
  final Color? cor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.valor,
    this.destaque = false,
    this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 22, color: cor ?? const Color(0xFF2E7D32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: destaque ? 20 : 17,
                    fontWeight: (destaque || cor != null) ? FontWeight.bold : FontWeight.normal,
                    color: cor ?? (destaque ? const Color(0xFF2E7D32) : Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BotaoAcao extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color cor;
  final VoidCallback onTap;
  final bool outlined;

  const _BotaoAcao({
    required this.label,
    required this.icon,
    required this.cor,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: cor,
                side: BorderSide(color: cor, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(icon, size: 22),
              label: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            )
          : ElevatedButton.icon(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: cor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(icon, size: 22),
              label: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
    );
  }
}
