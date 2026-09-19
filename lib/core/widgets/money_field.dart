import 'package:flutter/material.dart';

import '../utils/money.dart';

class MoneyField extends StatefulWidget {
  const MoneyField({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.label = 'Valor',
    this.autofocus = false,
    this.allowNegative = false,
    this.hint = r'R$ 0,00',
  });

  final double initialValue;
  final ValueChanged<double> onChanged;
  final String label;
  final bool autofocus;
  final bool allowNegative;
  final String hint;

  @override
  State<MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<MoneyField> {
  late final TextEditingController _controller = TextEditingController(
    text: _initialText,
  );

  String get _initialText {
    final value = widget.allowNegative
        ? widget.initialValue
        : widget.initialValue.abs();
    return value == 0 ? '' : formatMoneyInput(value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleSign() {
    final text = _controller.text;
    final toggled = text.startsWith('-') ? text.substring(1) : '-$text';
    _controller.value = TextEditingValue(
      text: toggled,
      selection: TextSelection.collapsed(offset: toggled.length),
    );
    widget.onChanged(parseMoney(toggled));
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        MoneyInputFormatter(allowNegative: widget.allowNegative),
      ],
      style: Theme.of(
        context,
      ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        suffixIcon: widget.allowNegative
            ? IconButton(
                tooltip: 'Trocar sinal',
                onPressed: _toggleSign,
                icon: const Text('±', style: TextStyle(fontSize: 22)),
              )
            : null,
      ),
      onChanged: (value) => widget.onChanged(parseMoney(value)),
    );
  }
}
