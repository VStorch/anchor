import 'package:flutter/material.dart';

import '../utils/money.dart';

class MoneyField extends StatefulWidget {
  const MoneyField({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.label = 'Valor',
    this.autofocus = false,
  });

  final double initialValue;
  final ValueChanged<double> onChanged;
  final String label;
  final bool autofocus;

  @override
  State<MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<MoneyField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue > 0 ? formatMoney(widget.initialValue) : '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: [MoneyInputFormatter()],
      style: Theme.of(
        context,
      ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: r'R$ 0,00',
      ),
      onChanged: (value) => widget.onChanged(parseMoney(value)),
    );
  }
}
