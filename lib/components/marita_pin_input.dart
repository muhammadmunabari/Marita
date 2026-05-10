import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design_system/marita_design_system.dart';

class MaritaPinInput extends StatefulWidget {
  final int length;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onCompleted;
  final TextEditingController? controller;

  const MaritaPinInput({
    super.key,
    this.length = 6,
    this.onChanged,
    this.onCompleted,
    this.controller,
  });

  @override
  State<MaritaPinInput> createState() => _MaritaPinInputState();
}

class _MaritaPinInputState extends State<MaritaPinInput> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_handleChange);
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_handleChange);
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _handleChange() {
    final text = _controller.text;
    if (widget.onChanged != null) {
      widget.onChanged!(text);
    }
    if (text.length == widget.length && widget.onCompleted != null) {
      widget.onCompleted!();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        children: [
          // Invisible TextField to capture input
          Positioned.fill(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: widget.length,
              autofocus: true,
              showCursor: false,
              enableInteractiveSelection: false,
              cursorColor: Colors.transparent,
              style: const TextStyle(color: Colors.transparent),
              decoration: const InputDecoration(
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                counterText: '',
                filled: false,
              ),
            ),
          ),
          // Visible custom PIN boxes
          Positioned.fill(
            child: IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(widget.length, (index) {
                  final textLength = _controller.text.length;
                  final isFocused = _focusNode.hasFocus &&
                      (index == textLength || (index == widget.length - 1 && textLength == widget.length));
                  final hasValue = index < textLength;
                  final char = hasValue ? _controller.text[index] : '';

                  return Container(
                    width: 48,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.maritaColors.backgroundPrimary,
                      borderRadius: MaritaRadius.borderMedium,
                      border: Border.all(
                        color: isFocused
                            ? context.maritaColors.interactivePrimary
                            : context.maritaColors.borderPrimary,
                        width: isFocused ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      char,
                      style: context.maritaTypography.titleLarge.copyWith(
                        color: context.maritaColors.contentPrimary,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
