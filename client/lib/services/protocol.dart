/**
 * protocol.dart — Protocollo di comunicazione
 *
 * Definisce i comandi e le costanti del protocollo
 * usato per comunicare con il server.
 */

class Protocol {
  // ---- Comandi ----
  static const String cmdAuth = 'AUTH';
  static const String cmdMouse = 'MOUSE';
  static const String cmdClick = 'CLICK';
  static const String cmdKey = 'KEY';
  static const String cmdScroll = 'SCROLL';
  static const String cmdPing = 'PING';

  // ---- Tipi di click ----
  static const String clickLeft = 'LEFT';
  static const String clickRight = 'RIGHT';
  static const String clickMiddle = 'MIDDLE';
  static const String clickDouble = 'DOUBLE';

  /// Costruisce un comando di autenticazione
  static String authCommand(String password) => '$cmdAuth:$password';

  /// Costruisce un comando di movimento mouse (percentuali 0-100)
  static String mouseCommand(double pctX, double pctY) =>
      '$cmdMouse:${pctX.toStringAsFixed(1)}:${pctY.toStringAsFixed(1)}';

  /// Costruisce un comando di click
  static String clickCommand(String type) => '$cmdClick:$type';

  /// Costruisce un comando di digitazione testo
  static String keyCommand(String text) => '$cmdKey:$text';

  /// Costruisce un comando di scroll
  static String scrollCommand(int dx, int dy) => '$cmdScroll:$dx:$dy';

  /// Costruisce un comando ping
  static String pingCommand() => cmdPing;
}
