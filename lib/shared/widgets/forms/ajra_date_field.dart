import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'ajra_text_field.dart';

class AjraDateField extends StatefulWidget {
  final String label;
  final String? hint;
  final DateTime? initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onDateSelected;
  final String? Function(String?)? validator;

  const AjraDateField({
    super.key,
    required this.label,
    this.hint = 'JJ/MM/AAAA',
    this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onDateSelected,
    this.validator,
  });

  @override
  State<AjraDateField> createState() => _AjraDateFieldState();
}

class _AjraDateFieldState extends State<AjraDateField> {
  late final TextEditingController _controller;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _controller = TextEditingController(
      text: _selectedDate != null
          ? DateFormat('dd/MM/yyyy', 'fr_FR').format(_selectedDate!)
          : '',
    );
  }

  @override
  void didUpdateWidget(covariant AjraDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDate != _selectedDate) {
      _selectedDate = widget.initialDate;
      _controller.text = _selectedDate != null
          ? DateFormat('dd/MM/yyyy', 'fr_FR').format(_selectedDate!)
          : '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? widget.initialDate ?? DateTime.now(),
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      locale: const Locale('fr', 'FR'),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _controller.text = DateFormat('dd/MM/yyyy', 'fr_FR').format(picked);
      });
      widget.onDateSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AjraTextField(
      controller: _controller,
      label: widget.label,
      hint: widget.hint,
      readOnly: true,
      onTap: _pickDate,
      suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
      validator: widget.validator,
    );
  }
}
