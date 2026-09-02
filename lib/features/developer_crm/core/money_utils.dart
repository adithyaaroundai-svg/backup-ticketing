import 'package:intl/intl.dart';

final NumberFormat _inr = NumberFormat.currency(locale: 'en_IN', symbol: '\u20b9', decimalDigits: 2);

String fmtMoney(num? value) => _inr.format(value ?? 0);
