/**
 * connection_service.dart — Servizio di connessione al server
 *
 * Supporta due modalità:
 * 1. TCP diretto (locale, stessa Wi-Fi) — socket raw
 * 2. HTTP POST (remoto, via Ngrok) — richieste HTTP con JSON
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'protocol.dart';

/// Risultato di una connessione
class ConnectionResult {
  final bool success;
  final String message;

  ConnectionResult(this.success, this.message);
}

/// Risultato di un comando
class CommandResult {
  final bool success;
  final String message;

  CommandResult(this.success, this.message);
}

/// Tipo di connessione
enum ConnectionMode { tcp, http, unknown }

class ConnectionService {
  // ---- Stato ----
  ConnectionMode _mode = ConnectionMode.unknown;
  bool _connected = false;
  String _password = '';
  String _host = '';
  int _port = 5555;

  // ---- TCP ----
  Socket? _tcpSocket;
  StreamSubscription? _tcpSubscription;
  String _tcpBuffer = '';
  Completer<String>? _tcpResponseCompleter;
  Timer? _tcpTimeout;

  // ---- HTTP ----
  String? _httpBaseUrl;

  // ---- Getter ----
  bool get isConnected => _connected;
  ConnectionMode get mode => _mode;
  String get host => _host;
  int get port => _port;
  String get connectionDisplay =>
      _mode == ConnectionMode.http ? '$_host (remoto)' : '$_host:$_port (locale)';
  String get password => _password;

  /// Rileva se un indirizzo è HTTP (Ngrok) o TCP (locale)
  static ConnectionMode detectMode(String address) {
    final addr = address.trim().toLowerCase();
    if (addr.contains('ngrok') || addr.startsWith('http')) {
      return ConnectionMode.http;
    }
    return ConnectionMode.tcp;
  }

  /// Parsing indirizzo: restituisce (host, port)
  static (String, int) parseAddress(String address, {int defaultPort = 5555}) {
    String addr = address.trim();
    if (addr.startsWith('http://')) addr = addr.substring(7);
    if (addr.startsWith('https://')) addr = addr.substring(8);
    if (addr.endsWith('/')) addr = addr.substring(0, addr.length - 1);

    if (addr.contains(':')) {
      final parts = addr.split(':');
      final host = parts[0];
      final port = int.tryParse(parts[1]) ?? defaultPort;
      return (host, port);
    }
    return (addr, defaultPort);
  }

  /// Si connette al server
  Future<ConnectionResult> connect({
    required String address,
    required String password,
  }) async {
    _password = password;
    _mode = detectMode(address);

    if (_mode == ConnectionMode.http) {
      return _connectHttp(address);
    } else {
      final (host, port) = parseAddress(address);
      return _connectTcp(host, port);
    }
  }

  /// Disconnette
  Future<void> disconnect() async {
    if (_mode == ConnectionMode.tcp) {
      await _disconnectTcp();
    }
    _connected = false;
    _mode = ConnectionMode.unknown;
  }

  /// Invia un comando e attende la risposta
  Future<CommandResult> sendCommand(String command) async {
    if (!_connected) {
      return CommandResult(false, 'Non connesso');
    }
    return _sendCommand(command);
  }

  /// Invia un comando — bypassa il controllo di connessione
  Future<CommandResult> _sendCommand(String command) async {
    try {
      if (_mode == ConnectionMode.http) {
        return await _sendCommandHttp(command);
      } else {
        return await _sendCommandTcp(command);
      }
    } catch (e) {
      return CommandResult(false, 'Errore: $e');
    }
  }

  /// Invia un comando senza attendere risposta (fire & forget per mouse)
  void sendCommandFast(String command) {
    if (!_connected) return;

    try {
      if (_mode == ConnectionMode.tcp && _tcpSocket != null) {
        _tcpSocket!.write('$command\n');
      }
    } catch (_) {}
  }

  // ==============================================================
  // TCP
  // ==============================================================

  Future<ConnectionResult> _connectTcp(String host, int port) async {
    try {
      _host = host;
      _port = port;

      _tcpSocket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );

      _tcpBuffer = '';
      _tcpResponseCompleter = Completer<String>();

      _tcpSubscription = _tcpSocket!.listen(
        (data) {
          _tcpBuffer += utf8.decode(data);
          while (_tcpBuffer.contains('\n')) {
            final line = _tcpBuffer.substring(0, _tcpBuffer.indexOf('\n'));
            _tcpBuffer = _tcpBuffer.substring(_tcpBuffer.indexOf('\n') + 1);
            _onTcpResponse(line.trim());
          }
        },
        onError: (error) {
          if (_tcpResponseCompleter != null && !_tcpResponseCompleter!.isCompleted) {
            _tcpResponseCompleter!.completeError(error);
          }
          _connected = false;
        },
        onDone: () {
          _connected = false;
        },
      );

      // Autenticazione — usiamo _sendCommand direttamente, senza il check isConnected
      final authResult = await _sendCommand(Protocol.authCommand(_password));
      if (!authResult.success) {
        await _disconnectTcp();
        return ConnectionResult(false, authResult.message);
      }

      _connected = true;
      return ConnectionResult(true, '✅ Connesso a $host:$port');
    } on SocketException catch (e) {
      return ConnectionResult(false, '❌ Impossibile connettersi: $e');
    } on TimeoutException {
      return ConnectionResult(false, '❌ Timeout di connessione');
    } catch (e) {
      return ConnectionResult(false, '❌ Errore: $e');
    }
  }

  void _onTcpResponse(String line) {
    if (_tcpResponseCompleter != null && !_tcpResponseCompleter!.isCompleted) {
      _tcpResponseCompleter!.complete(line);
    }
  }

  Future<CommandResult> _sendCommandTcp(String command) async {
    if (_tcpSocket == null) {
      return CommandResult(false, 'Socket non disponibile');
    }

    _tcpResponseCompleter = Completer<String>();

    _tcpSocket!.write('$command\n');

    _tcpTimeout?.cancel();
    _tcpTimeout = Timer(const Duration(seconds: 5), () {
      if (_tcpResponseCompleter != null && !_tcpResponseCompleter!.isCompleted) {
        _tcpResponseCompleter!.complete('ERR:Timeout');
      }
    });

    try {
      final response = await _tcpResponseCompleter!.future;
      _tcpTimeout?.cancel();

      if (response.startsWith('OK')) {
        return CommandResult(true, response);
      } else {
        return CommandResult(false, response);
      }
    } catch (e) {
      _tcpTimeout?.cancel();
      return CommandResult(false, 'Errore: $e');
    }
  }

  Future<void> _disconnectTcp() async {
    _tcpTimeout?.cancel();
    _tcpSubscription?.cancel();
    try {
      _tcpSocket?.destroy();
    } catch (_) {}
    _tcpSocket = null;
    _tcpSubscription = null;
    _connected = false;
  }

  // ==============================================================
  // HTTP (Ngrok)
  // ==============================================================

  Future<ConnectionResult> _connectHttp(String address) async {
    try {
      String url = address.trim();
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }
      if (url.endsWith('/')) url = url.substring(0, url.length - 1);

      _httpBaseUrl = url;
      _host = url;

      // Test di connessione con ping — usiamo _sendCommand direttamente
      final pingResult = await _sendCommand(Protocol.pingCommand());
      if (!pingResult.success) {
        return ConnectionResult(false, '❌ Server non raggiungibile: ${pingResult.message}');
      }

      // Autenticazione
      final authResult = await _sendCommand(Protocol.authCommand(_password));
      if (!authResult.success) {
        return ConnectionResult(false, authResult.message);
      }

      _connected = true;
      return ConnectionResult(true, '✅ Connesso a $url (tramite Ngrok)');
    } catch (e) {
      return ConnectionResult(false, '❌ Errore di connessione HTTP: $e');
    }
  }

  Future<CommandResult> _sendCommandHttp(String command) async {
    if (_httpBaseUrl == null) {
      return CommandResult(false, 'URL non configurato');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_httpBaseUrl/command'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'auth': _password,
              'command': command,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'ok') {
          return CommandResult(true, data['detail'] ?? 'OK');
        } else {
          return CommandResult(false, data['detail'] ?? 'Errore sconosciuto');
        }
      } else if (response.statusCode == 403) {
        return CommandResult(false, 'ERR:Autenticazione fallita');
      } else {
        return CommandResult(false, 'ERR:HTTP ${response.statusCode}');
      }
    } on SocketException {
      return CommandResult(false, 'ERR:Server non raggiungibile');
    } on TimeoutException {
      return CommandResult(false, 'ERR:Timeout richiesta');
    } catch (e) {
      return CommandResult(false, 'ERR:$e');
    }
  }
}
