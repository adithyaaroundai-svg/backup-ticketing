import 'package:flutter/foundation.dart';

class TicketContextTracker {
  TicketContextTracker._();

  static final ValueNotifier<String?> _activeTicketIdNotifier =
      ValueNotifier<String?>(null);

  static String? get activeTicketId => _activeTicketIdNotifier.value;

  static ValueListenable<String?> get activeTicketIdListenable =>
      _activeTicketIdNotifier;

  static void setActiveTicketId(String? ticketId) {
    if (_activeTicketIdNotifier.value == ticketId) return;
    _activeTicketIdNotifier.value = ticketId;
  }
}
