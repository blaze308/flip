import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modern OTP input widget with enhanced UX
class ModernOtpInput extends StatefulWidget {
  final int length;
  final Function(String) onCompleted;
  final Function(String) onChanged;
  final bool autoFocus;
  final TextInputType keyboardType;
  final TextStyle? textStyle;
  final double fieldWidth;
  final double fieldHeight;
  final double spacing;
  final Color? fillColor;
  final Color? activeBorderColor;
  final Color? inactiveBorderColor;
  final Color? errorBorderColor;
  final Color? cursorColor;
  final BorderRadius? borderRadius;
  final bool hasError;
  final bool enabled;

  const ModernOtpInput({
    super.key,
    this.length = 6,
    required this.onCompleted,
    required this.onChanged,
    this.autoFocus = true,
    this.keyboardType = TextInputType.number,
    this.textStyle,
    this.fieldWidth = 50,
    this.fieldHeight = 60,
    this.spacing = 12,
    this.fillColor,
    this.activeBorderColor,
    this.inactiveBorderColor,
    this.errorBorderColor,
    this.cursorColor,
    this.borderRadius,
    this.hasError = false,
    this.enabled = true,
  });

  @override
  State<ModernOtpInput> createState() => _ModernOtpInputState();
}

class _ModernOtpInputState extends State<ModernOtpInput>
    with TickerProviderStateMixin {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  late List<AnimationController> _animationControllers;
  late List<Animation<double>> _scaleAnimations;
  late List<Animation<Color?>> _colorAnimations;

  int _currentIndex = 0;
  String _currentValue = '';

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeAnimations();

    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNodes[0].requestFocus();
      });
    }
  }

  void _initializeControllers() {
    _controllers = List.generate(
      widget.length,
      (index) => TextEditingController(),
    );

    _focusNodes = List.generate(widget.length, (index) => FocusNode());

    // Add listeners to focus nodes
    for (int i = 0; i < _focusNodes.length; i++) {
      _focusNodes[i].addListener(() {
        if (_focusNodes[i].hasFocus) {
          setState(() {
            _currentIndex = i;
          });
          _animationControllers[i].forward();
        } else {
          _animationControllers[i].reverse();
        }
      });
    }
  }

  void _initializeAnimations() {
    _animationControllers = List.generate(
      widget.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this,
      ),
    );

    _scaleAnimations =
        _animationControllers
            .map(
              (controller) => Tween<double>(begin: 1.0, end: 1.05).animate(
                CurvedAnimation(parent: controller, curve: Curves.easeInOut),
              ),
            )
            .toList();

    final activeColor = widget.activeBorderColor ?? const Color(0xFF4ECDC4);
    final inactiveColor = widget.inactiveBorderColor ?? Colors.grey.shade300;

    _colorAnimations =
        _animationControllers
            .map(
              (controller) => ColorTween(
                begin: inactiveColor,
                end: activeColor,
              ).animate(
                CurvedAnimation(parent: controller, curve: Curves.easeInOut),
              ),
            )
            .toList();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    for (var animationController in _animationControllers) {
      animationController.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (!widget.enabled) return;

    // Handle paste operation
    if (value.length > 1) {
      _handlePaste(value, index);
      return;
    }

    // Handle single character input
    if (value.isNotEmpty && RegExp(r'^[0-9]$').hasMatch(value)) {
      _controllers[index].text = value;
      _updateCurrentValue();

      // Move to next field
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else if (value.isEmpty) {
      // Handle backspace
      _controllers[index].text = '';
      _updateCurrentValue();

      // Move to previous field
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  void _handlePaste(String pastedText, int startIndex) {
    // Extract only digits from pasted text
    final digits = pastedText.replaceAll(RegExp(r'[^0-9]'), '');

    for (
      int i = 0;
      i < digits.length && (startIndex + i) < widget.length;
      i++
    ) {
      _controllers[startIndex + i].text = digits[i];
    }

    _updateCurrentValue();

    // Focus on the next empty field or the last field
    final nextIndex = (startIndex + digits.length).clamp(0, widget.length - 1);
    _focusNodes[nextIndex].requestFocus();
  }

  void _updateCurrentValue() {
    _currentValue = _controllers.map((c) => c.text).join();
    widget.onChanged(_currentValue);

    if (_currentValue.length == widget.length) {
      widget.onCompleted(_currentValue);
    }
  }

  void _onTap(int index) {
    if (!widget.enabled) return;

    _focusNodes[index].requestFocus();

    // Position cursor at the end
    _controllers[index].selection = TextSelection.fromPosition(
      TextPosition(offset: _controllers[index].text.length),
    );
  }

  void _clearAll() {
    if (!widget.enabled) return;

    for (var controller in _controllers) {
      controller.clear();
    }
    _currentValue = '';
    widget.onChanged(_currentValue);
    _focusNodes[0].requestFocus();

    // Add a subtle haptic feedback
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // Calculate responsive dimensions
            final availableWidth = constraints.maxWidth;
            final minFieldWidth = 35.0;
            final maxFieldWidth = widget.fieldWidth;
            final minSpacing = 2.0;
            final maxSpacing = widget.spacing;

            // Calculate optimal field width and spacing
            double calculatedFieldWidth;
            double calculatedSpacing;

            // Try to fit with maximum sizes first
            final idealTotalWidth =
                (maxFieldWidth * widget.length) +
                (maxSpacing * (widget.length - 1));

            if (idealTotalWidth <= availableWidth) {
              // Perfect fit with ideal sizes
              calculatedFieldWidth = maxFieldWidth;
              calculatedSpacing = maxSpacing;
            } else {
              // Need to scale down - prioritize field width over spacing
              final availableForSpacing =
                  availableWidth * 0.2; // 20% for spacing
              final availableForFields = availableWidth - availableForSpacing;

              calculatedFieldWidth = (availableForFields / widget.length).clamp(
                minFieldWidth,
                maxFieldWidth,
              );

              // Calculate remaining space for spacing
              final usedByFields = calculatedFieldWidth * widget.length;
              final remainingForSpacing = availableWidth - usedByFields;
              calculatedSpacing = (remainingForSpacing / (widget.length - 1))
                  .clamp(minSpacing, maxSpacing);
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.length, (index) {
                return Flexible(
                  child: Container(
                    width: calculatedFieldWidth,
                    margin: EdgeInsets.only(
                      left: index == 0 ? 0 : calculatedSpacing / 2,
                      right:
                          index == widget.length - 1
                              ? 0
                              : calculatedSpacing / 2,
                    ),
                    child: _buildOtpField(index, calculatedFieldWidth),
                  ),
                );
              }),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildClearButton(),
      ],
    );
  }

  Widget _buildOtpField(int index, [double? fieldWidth]) {
    final hasValue = _controllers[index].text.isNotEmpty;
    final isActive = _currentIndex == index;
    final effectiveWidth = fieldWidth ?? widget.fieldWidth;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _scaleAnimations[index],
        _colorAnimations[index],
      ]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimations[index].value,
          child: Container(
            width: effectiveWidth,
            height: widget.fieldHeight,
            decoration: BoxDecoration(
              color: widget.fillColor ?? Colors.grey.shade50,
              borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
              border: Border.all(
                color:
                    widget.hasError
                        ? (widget.errorBorderColor ?? Colors.red)
                        : (_colorAnimations[index].value ??
                            Colors.grey.shade300),
                width: isActive ? 2 : 1.5,
              ),
              boxShadow:
                  isActive
                      ? [
                        BoxShadow(
                          color: (widget.activeBorderColor ??
                                  const Color(0xFF4ECDC4))
                              .withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                      : null,
            ),
            child: Stack(
              children: [
                // Text field
                TextField(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  enabled: widget.enabled,
                  textAlign: TextAlign.center,
                  style:
                      widget.textStyle ??
                      TextStyle(
                        fontSize: (effectiveWidth * 0.4).clamp(16.0, 24.0),
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                  keyboardType: widget.keyboardType,
                  maxLength: 1,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    contentPadding: EdgeInsets.zero,
                  ),
                  cursorColor: widget.cursorColor ?? const Color(0xFF4ECDC4),
                  cursorWidth: 2,
                  cursorHeight: (effectiveWidth * 0.4).clamp(16.0, 24.0),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) => _onChanged(value, index),
                  onTap: () => _onTap(index),
                ),

                // Animated dot indicator when empty and focused
                if (!hasValue && isActive)
                  Positioned.fill(
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: isActive ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color:
                                widget.cursorColor ?? const Color(0xFF4ECDC4),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildClearButton() {
    final hasAnyValue = _controllers.any((c) => c.text.isNotEmpty);

    return AnimatedOpacity(
      opacity: hasAnyValue && widget.enabled ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: AnimatedScale(
        scale: hasAnyValue && widget.enabled ? 1.0 : 0.8,
        duration: const Duration(milliseconds: 200),
        child: GestureDetector(
          onTap: hasAnyValue ? _clearAll : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.clear_all, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Clear All',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Public method to clear all fields
  void clearAll() {
    _clearAll();
  }

  // Public method to get current value
  String get currentValue => _currentValue;

  // Public method to set error state
  void setError(bool hasError) {
    if (mounted) {
      setState(() {
        // The hasError parameter will be handled by the parent widget
      });
    }
  }
}

/// Enhanced OTP input with additional features
class EnhancedOtpInput extends StatefulWidget {
  final int length;
  final Function(String) onCompleted;
  final Function(String) onChanged;
  final String? errorText;
  final String? helperText;
  final bool autoFocus;
  final bool enabled;
  final Duration? autoSubmitDelay;

  const EnhancedOtpInput({
    super.key,
    this.length = 6,
    required this.onCompleted,
    required this.onChanged,
    this.errorText,
    this.helperText,
    this.autoFocus = true,
    this.enabled = true,
    this.autoSubmitDelay,
  });

  @override
  State<EnhancedOtpInput> createState() => _EnhancedOtpInputState();
}

class _EnhancedOtpInputState extends State<EnhancedOtpInput> {
  final GlobalKey<_ModernOtpInputState> _otpKey = GlobalKey();
  bool _hasError = false;

  @override
  void didUpdateWidget(EnhancedOtpInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorText != oldWidget.errorText) {
      setState(() {
        _hasError = widget.errorText != null;
      });
    }
  }

  void _onCompleted(String value) {
    if (widget.autoSubmitDelay != null) {
      Future.delayed(widget.autoSubmitDelay!, () {
        widget.onCompleted(value);
      });
    } else {
      widget.onCompleted(value);
    }
  }

  void _onChanged(String value) {
    // Clear error when user starts typing
    if (_hasError && value.isNotEmpty) {
      setState(() {
        _hasError = false;
      });
    }
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ModernOtpInput(
          key: _otpKey,
          length: widget.length,
          onCompleted: _onCompleted,
          onChanged: _onChanged,
          autoFocus: widget.autoFocus,
          enabled: widget.enabled,
          hasError: _hasError,
          activeBorderColor: const Color(0xFF4ECDC4),
          errorBorderColor: Colors.red.shade400,
          fillColor: widget.enabled ? Colors.white : Colors.grey.shade100,
        ),

        const SizedBox(height: 12),

        // Error or helper text
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child:
              _hasError && widget.errorText != null
                  ? Text(
                    widget.errorText!,
                    key: const ValueKey('error'),
                    style: TextStyle(
                      color: Colors.red.shade600,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  )
                  : widget.helperText != null
                  ? Text(
                    widget.helperText!,
                    key: const ValueKey('helper'),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    textAlign: TextAlign.center,
                  )
                  : const SizedBox.shrink(),
        ),
      ],
    );
  }

  // Public method to clear all fields
  void clearAll() {
    _otpKey.currentState?.clearAll();
  }

  // Public method to set error
  void setError(String? errorText) {
    setState(() {
      _hasError = errorText != null;
    });
  }
}
