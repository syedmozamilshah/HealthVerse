import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../color/colors.dart';

class ReusableDropDown extends ConsumerStatefulWidget {
  final List<String> list;
  final void Function(String value, WidgetRef ref) onChanged;
  final String? hintText;
  final String? initialValue;

  const ReusableDropDown({
    super.key,
    required this.list,
    required this.onChanged,
    this.hintText,
    this.initialValue,
  });

  @override
  ConsumerState<ReusableDropDown> createState() => _ReusableDropDownState();
}

class _ReusableDropDownState extends ConsumerState<ReusableDropDown> {
  late String dropDownValue;

  @override
  void initState() {
    super.initState();
    dropDownValue = widget.initialValue ?? widget.list.first;
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: dropDownValue,
        icon: const Icon(Icons.arrow_drop_down, color: tealColor),
        elevation: 8,
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(8),
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
        ),
        items: widget.list.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: (String? value) {
          if (value != null) {
            setState(() {
              dropDownValue = value;
            });
            widget.onChanged(value, ref);
          }
        },
      ),
    );
  }
}
