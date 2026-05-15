import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/reserva.dart';
import '../services/firestore_service.dart';

class FormReservaScreen extends StatefulWidget {
  final Reserva? reserva;
  final List<Reserva>? todasReservas;

  const FormReservaScreen({super.key, this.reserva, this.todasReservas});

  @override
  State<FormReservaScreen> createState() => _FormReservaScreenState();
}

class _FormReservaScreenState extends State<FormReservaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = FirestoreService();

  late final TextEditingController _nomeCtrl;
  late final TextEditingController _telCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _valorCtrl;
  late final TextEditingController _entradaCtrl;
  late final TextEditingController _obsCtrl;

  DateTime? _dataInicio;
  DateTime? _dataFim;
  String _statusPagamento = 'pendente';
  bool _salvando = false;

  final _fmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    final r = widget.reserva;
    _nomeCtrl = TextEditingController(text: r?.nomeLocatario ?? '');
    _telCtrl = TextEditingController(text: r?.telefone ?? '');
    _emailCtrl = TextEditingController(text: r?.email ?? '');
    _valorCtrl = TextEditingController(
      text: r != null ? r.valor.toStringAsFixed(2).replaceAll('.', ',') : '',
    );
    _entradaCtrl = TextEditingController(
      text: (r != null && r.valorEntrada > 0)
          ? r.valorEntrada.toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );
    _obsCtrl = TextEditingController(text: r?.observacoes ?? '');
    _dataInicio = r?.dataInicio;
    _dataFim = r?.dataFim;
    _statusPagamento = r?.statusPagamento ?? 'pendente';
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _telCtrl.dispose();
    _emailCtrl.dispose();
    _valorCtrl.dispose();
    _entradaCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  int get _numeroDias {
    if (_dataInicio == null || _dataFim == null) return 0;
    return _dataFim!.difference(_dataInicio!).inDays + 1;
  }

  Future<void> _escolherData({required bool isInicio}) async {
    final hoje = DateTime.now();
    final inicial = isInicio
        ? (_dataInicio ?? hoje)
        : (_dataFim ?? _dataInicio ?? hoje);

    final picked = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF2E7D32),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked == null) return;

    setState(() {
      if (isInicio) {
        _dataInicio = picked;
        if (_dataFim != null && _dataFim!.isBefore(picked)) {
          _dataFim = null;
        }
      } else {
        _dataFim = picked;
      }
    });
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dataInicio == null) {
      _mostrarErro('Selecione a data de entrada.');
      return;
    }
    if (_dataFim == null) {
      _mostrarErro('Selecione a data de saída.');
      return;
    }
    if (_dataFim!.isBefore(_dataInicio!)) {
      _mostrarErro('A data de saída deve ser igual ou depois da entrada.');
      return;
    }

    final valorStr = _valorCtrl.text.replaceAll('.', '').replaceAll(',', '.');
    final valor = double.tryParse(valorStr) ?? 0;

    final entradaStr = _entradaCtrl.text.replaceAll('.', '').replaceAll(',', '.');
    final valorEntrada = _statusPagamento == 'entrada'
        ? (double.tryParse(entradaStr) ?? 0)
        : 0.0;

    if (_statusPagamento == 'entrada') {
      if (valorEntrada <= 0) {
        _mostrarErro('Informe o valor da entrada.');
        return;
      }
      if (valorEntrada >= valor) {
        _mostrarErro('O valor da entrada deve ser menor que o valor total.\nSe foi pago tudo, selecione "Pago integralmente".');
        return;
      }
    }

    final todas = widget.todasReservas ?? await _service.getReservas();
    if (_service.hasOverlap(todas, _dataInicio!, _dataFim!, widget.reserva?.id)) {
      _mostrarErro(
        'Já existe uma reserva nessas datas.\nVerifique o calendário e escolha outras datas.',
      );
      return;
    }

    setState(() => _salvando = true);

    try {
      if (widget.reserva == null) {
        await _service.addReserva(Reserva(
          nomeLocatario: _nomeCtrl.text.trim(),
          telefone: _telCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          dataInicio: _dataInicio!,
          dataFim: _dataFim!,
          valor: valor,
          valorEntrada: valorEntrada,
          statusPagamento: _statusPagamento,
          observacoes: _obsCtrl.text.trim(),
        ));
      } else {
        await _service.updateReserva(widget.reserva!.copyWith(
          nomeLocatario: _nomeCtrl.text.trim(),
          telefone: _telCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          dataInicio: _dataInicio,
          dataFim: _dataFim,
          valor: valor,
          valorEntrada: valorEntrada,
          statusPagamento: _statusPagamento,
          observacoes: _obsCtrl.text.trim(),
        ));
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _salvando = false);
      _mostrarErro('Erro ao salvar. Tente novamente.');
    }
  }

  void _mostrarErro(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Atenção', style: TextStyle(fontSize: 20)),
          ],
        ),
        content: Text(msg, style: const TextStyle(fontSize: 17)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(fontSize: 17)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.reserva != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        title: Text(
          editando ? 'Editar Reserva' : 'Nova Reserva',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Campo(
                label: 'Nome do locatário *',
                controller: _nomeCtrl,
                icon: Icons.person,
                hint: 'Ex: João da Silva',
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 16),
              _Campo(
                label: 'Telefone (opcional)',
                controller: _telCtrl,
                icon: Icons.phone,
                hint: 'Ex: (11) 99999-9999',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _Campo(
                label: 'E-mail (opcional)',
                controller: _emailCtrl,
                icon: Icons.email,
                hint: 'Ex: joao@email.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              const _LabelText(text: 'Datas da reserva *'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _BotaoData(
                      label: 'Entrada',
                      data: _dataInicio,
                      fmt: _fmt,
                      onTap: () => _escolherData(isInicio: true),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward, color: Colors.grey),
                  ),
                  Expanded(
                    child: _BotaoData(
                      label: 'Saída',
                      data: _dataFim,
                      fmt: _fmt,
                      onTap: () => _escolherData(isInicio: false),
                    ),
                  ),
                ],
              ),
              if (_dataInicio != null && _dataFim != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2E7D32)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_today, color: Color(0xFF2E7D32), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Duração: $_numeroDias ${_numeroDias == 1 ? 'dia' : 'dias'}',
                        style: const TextStyle(
                          fontSize: 17,
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _Campo(
                label: 'Valor total (R\$) *',
                controller: _valorCtrl,
                icon: Icons.attach_money,
                hint: 'Ex: 1500,00',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe o valor';
                  final n = double.tryParse(v.replaceAll(',', '.'));
                  if (n == null || n <= 0) return 'Valor inválido';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const _LabelText(text: 'Situação do pagamento *'),
              const SizedBox(height: 10),
              Row(
                children: [
                  _ChipPagamento(
                    label: 'Pendente',
                    icon: Icons.hourglass_empty,
                    selecionado: _statusPagamento == 'pendente',
                    cor: Colors.orange,
                    onTap: () => setState(() {
                      _statusPagamento = 'pendente';
                      _entradaCtrl.clear();
                    }),
                  ),
                  const SizedBox(width: 8),
                  _ChipPagamento(
                    label: 'Entrada paga',
                    icon: Icons.payments_outlined,
                    selecionado: _statusPagamento == 'entrada',
                    cor: const Color(0xFF1565C0),
                    onTap: () => setState(() => _statusPagamento = 'entrada'),
                  ),
                  const SizedBox(width: 8),
                  _ChipPagamento(
                    label: 'Pago total',
                    icon: Icons.check_circle_outline,
                    selecionado: _statusPagamento == 'pago_total',
                    cor: const Color(0xFF2E7D32),
                    onTap: () => setState(() {
                      _statusPagamento = 'pago_total';
                      _entradaCtrl.clear();
                    }),
                  ),
                ],
              ),
              if (_statusPagamento == 'entrada') ...[
                const SizedBox(height: 16),
                _Campo(
                  label: 'Valor da entrada (R\$) *',
                  controller: _entradaCtrl,
                  icon: Icons.arrow_downward,
                  hint: 'Ex: 500,00',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))],
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder(
                  valueListenable: _entradaCtrl,
                  builder: (_, value, child) {
                    final totalStr = _valorCtrl.text.replaceAll('.', '').replaceAll(',', '.');
                    final entStr = _entradaCtrl.text.replaceAll('.', '').replaceAll(',', '.');
                    final total = double.tryParse(totalStr) ?? 0;
                    final entrada = double.tryParse(entStr) ?? 0;
                    final restante = total - entrada;
                    if (entrada <= 0 || restante < 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1565C0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.arrow_forward, color: Color(0xFF1565C0), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Restante a receber: R\$ ${NumberFormat('#,##0.00', 'pt_BR').format(restante)}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF1565C0),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 16),
              _Campo(
                label: 'Observações (opcional)',
                controller: _obsCtrl,
                icon: Icons.notes,
                hint: 'Ex: entrada às 14h, 4 pessoas...',
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _salvando ? null : _salvar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _salvando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save, size: 24),
                  label: Text(
                    _salvando ? 'Salvando...' : 'Salvar Reserva',
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabelText extends StatelessWidget {
  final String text;

  const _LabelText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
    );
  }
}

class _Campo extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final int maxLines;
  final TextCapitalization textCapitalization;

  const _Campo({
    required this.label,
    required this.controller,
    required this.icon,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      style: const TextStyle(fontSize: 17),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 16),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 15),
        prefixIcon: Icon(icon, color: const Color(0xFF2E7D32)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _BotaoData extends StatelessWidget {
  final String label;
  final DateTime? data;
  final DateFormat fmt;
  final VoidCallback onTap;

  const _BotaoData({
    required this.label,
    required this.data,
    required this.fmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: data != null ? const Color(0xFF2E7D32) : Colors.grey.shade400,
            width: data != null ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: data != null ? const Color(0xFF2E7D32) : Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: data != null ? const Color(0xFF2E7D32) : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  data != null ? fmt.format(data!) : 'Selecionar',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: data != null ? Colors.black87 : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipPagamento extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selecionado;
  final Color cor;
  final VoidCallback onTap;

  const _ChipPagamento({
    required this.label,
    required this.icon,
    required this.selecionado,
    required this.cor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selecionado ? cor.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selecionado ? cor : Colors.grey.shade300,
              width: selecionado ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selecionado ? cor : Colors.grey, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selecionado ? FontWeight.bold : FontWeight.normal,
                  color: selecionado ? cor : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
