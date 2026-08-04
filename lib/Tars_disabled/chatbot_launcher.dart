import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/animation.dart';

import 'api_service.dart';
import 'copilotwidget.dart';

const String kTarsDefaultApiBaseUrl = 'http://localhost:8000';
const String kTarsApiBaseUrl = String.fromEnvironment(
  'TARS_API_BASE_URL',
  defaultValue: kTarsDefaultApiBaseUrl,
);

Future<void> showChatbotDialog(
  BuildContext context, {
  String? focusedTicketId,
}) {
  final overlay =
      Overlay.maybeOf(context, rootOverlay: true) ??
      Navigator.of(context, rootNavigator: true).overlay;
  if (overlay == null) {
    return Future.value();
  }
  final apiService = ApiService(baseUrl: kTarsApiBaseUrl);
  final completer = Completer<void>();
  late final OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => Stack(
      children: [
        const IgnorePointer(ignoring: true, child: SizedBox.expand()),
        Positioned(
          bottom: 32,
          right: 32,
          child: _FloatingChatbotPanel(
            apiService: apiService,
            focusedTicketId: focusedTicketId,
            onClose: () {
              overlayEntry.remove();
              if (!completer.isCompleted) {
                completer.complete();
              }
            },
          ),
        ),
      ],
    ),
  );

  overlay.insert(overlayEntry);
  return completer.future;
}

class _FloatingChatbotPanel extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onClose;
  final String? focusedTicketId;

  const _FloatingChatbotPanel({
    required this.apiService,
    required this.onClose,
    this.focusedTicketId,
  });

  @override
  State<_FloatingChatbotPanel> createState() => _FloatingChatbotPanelState();
}

class _FloatingChatbotPanelState extends State<_FloatingChatbotPanel>
    with SingleTickerProviderStateMixin {
  static const _animationDuration = Duration(milliseconds: 300);
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  late final Animation<double> _opacityAnimation;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _animationDuration,
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.25, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _opacityAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  Future<void> _handleClose() async {
    if (_isClosing) return;
    _isClosing = true;
    await _controller.reverse();
    widget.onClose();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: SlideTransition(
        position: _offsetAnimation,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: CopilotWidget(
            apiService: widget.apiService,
            focusedTicketId: widget.focusedTicketId,
            onClose: _handleClose,
          ),
        ),
      ),
    );
  }
}
