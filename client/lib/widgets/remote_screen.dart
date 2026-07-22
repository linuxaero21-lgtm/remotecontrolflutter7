/**
 * remote_screen.dart — Schermata principale con streaming + controllo
 *
 * Mostra lo schermo del PC in tempo reale e permette di:
 * - Trascinare il dito sullo schermo per muovere il mouse
 * - Tap per click sinistro
 * - Pulsanti: click destro, tastiera, disconnetti
 * - Doppio tap per doppio click
 */

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../services/connection_service.dart';
import '../services/protocol.dart';

class RemoteScreen extends StatefulWidget {
  final ConnectionService connectionService;
  final String streamHost;
  final int streamPort;
  final String password;

  const RemoteScreen({
    super.key,
    required this.connectionService,
    required this.streamHost,
    required this.streamPort,
    required this.password,
  });

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen>
    with WidgetsBindingObserver {
  // ---- WebSocket stream ----
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Uint8List? _currentFrame;
  bool _streamConnected = false;
  bool _connecting = true;
  String? _errorMessage;
  double _fps = 10.0;

  // ---- Tocco ----
  DateTime _lastMoveTime = DateTime.now();
  static const Duration _moveDebounce = Duration(milliseconds: 30);
  bool _isDragging = false;

  // ---- UI ----
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disconnect();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _disconnect();
    } else if (state == AppLifecycleState.resumed) {
      _connect();
    }
  }

  // ==============================================================
  // WebSocket (stream schermo)
  // ==============================================================

  Future<void> _connect() async {
    if (_connecting || _streamConnected) return;

    setState(() {
      _connecting = true;
      _errorMessage = null;
    });

    try {
      final wsUrl = 'ws://${widget.streamHost}:${widget.streamPort}';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Autenticazione
      _channel!.sink.add(jsonEncode({"auth": widget.password}));

      _subscription = _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message as String);
            if (data['type'] == 'info') {
              setState(() {
                _fps = data['fps'] ?? 10.0;
                _streamConnected = true;
                _connecting = false;
              });
            } else if (data['type'] == 'frame') {
              final bytes = base64Decode(data['data'] as String);
              if (mounted) {
                setState(() => _currentFrame = bytes);
              }
            } else if (data['error'] != null) {
              setState(() {
                _errorMessage = data['error'];
                _streamConnected = false;
                _connecting = false;
              });
            }
          } catch (_) {}
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Errore stream: $error';
              _streamConnected = false;
              _connecting = false;
            });
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _streamConnected = false;
              _connecting = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Impossibile connettersi allo stream: $e';
          _connecting = false;
        });
      }
    }
  }

  void _disconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    if (mounted) {
      setState(() {
        _streamConnected = false;
        _connecting = false;
      });
    }
  }

  // ==============================================================
  // Controllo touch sullo schermo
  // ==============================================================

  void _onPointerMove(double localDx, double localDy, Size size) {
    final now = DateTime.now();
    if (now.difference(_lastMoveTime) < _moveDebounce) return;
    _lastMoveTime = now;
    _isDragging = true;

    final pctX = (localDx / size.width * 100).clamp(0.0, 100.0);
    final pctY = (localDy / size.height * 100).clamp(0.0, 100.0);

    widget.connectionService
        .sendCommandFast(Protocol.mouseCommand(pctX, pctY));
  }

  void _onTapDown() {
    _isDragging = false;
  }

  void _onTapUp() {
    if (!_isDragging) {
      HapticFeedback.lightImpact();
      widget.connectionService
          .sendCommand(Protocol.clickCommand(Protocol.clickLeft));
    }
    _isDragging = false;
  }

  void _onDoubleTap() {
    widget.connectionService
        .sendCommand(Protocol.clickCommand(Protocol.clickDouble));
  }

  // ==============================================================
  // Pulsanti
  // ==============================================================

  void _rightClick() {
    HapticFeedback.mediumImpact();
    widget.connectionService
        .sendCommand(Protocol.clickCommand(Protocol.clickRight));
  }

  void _toggleKeyboard() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _KeyboardSheet(connectionService: widget.connectionService),
    );
  }

  // ==============================================================
  // Build
  // ==============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // --- Schermo PC ---
            if ((_currentFrame != null) || _connecting)
              GestureDetector(
                onTapDown: (_) => _onTapDown(),
                onTapUp: (_) => _onTapUp(),
                onDoubleTap: _onDoubleTap,
                onLongPress: _rightClick,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Listener(
                      onPointerMove: (event) {
                        if (!_streamConnected) return;
                        _onPointerMove(
                          event.localPosition.dx,
                          event.localPosition.dy,
                          Size(constraints.maxWidth, constraints.maxHeight),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.black,
                        child: _currentFrame != null
                            ? Image.memory(
                                _currentFrame!,
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                              )
                            : const Center(child: CircularProgressIndicator()),
                      ),
                    );
                  },
                ),
              )

            // --- Schermata di connessione ---
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_errorMessage != null) ...[
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _connect,
                        child: const Text('Riprova'),
                      ),
                    ] else ...[
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 16),
                      const Text('Connessione allo stream...',
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ],
                ),
              ),

            // --- Overlay info (in alto) ---
            Positioned(
              top: 8,
              left: 8,
              child: Row(
                children: [
                  _badge(_streamConnected ? '🟢 Live' : '🔴 Offline'),
                  const SizedBox(width: 4),
                  if (_streamConnected)
                    _badge('${_fps.toStringAsFixed(0)} fps'),
                  const SizedBox(width: 4),
                  _badge(
                      '${widget.connectionService.host}:${widget.streamPort}'),
                ],
              ),
            ),

            // --- Pulsante toggle controlli ---
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => setState(() => _showControls = !_showControls),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _showControls ? '✕' : '☰',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
            ),

            // --- Pulsanti controllo (in basso) ---
            if (_showControls && _streamConnected)
              Positioned(
                bottom: 20,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ctrlButton(Icons.touch_app, 'Click Sin.', _onTapUp, Colors.green),
                    const SizedBox(width: 8),
                    _ctrlButton(
                        Icons.touch_app_outlined, 'Destro', _rightClick, Colors.red),
                    const SizedBox(width: 8),
                    _ctrlButton(Icons.double_arrow, 'Doppio', _onDoubleTap, Colors.orange),
                    const SizedBox(width: 8),
                    _ctrlButton(Icons.keyboard, 'Tastiera', _toggleKeyboard, Colors.blue),
                  ],
                ),
              ),

            // --- Pulsante disconnetti ---
            if (_streamConnected)
              Positioned(
                bottom: 76,
                right: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(Icons.power_settings_new,
                        color: Colors.white, size: 22),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 10)),
    );
  }

  Widget _ctrlButton(IconData icon, String label, VoidCallback onTap, Color color) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 2),
              Text(label,
                  style:
                      const TextStyle(color: Colors.white, fontSize: 9)),
            ],
          ),
        ),
      ),
    );
  }
}

// ==============================================================
// Keyboard Sheet
// ==============================================================

class _KeyboardSheet extends StatefulWidget {
  final ConnectionService connectionService;
  const _KeyboardSheet({required this.connectionService});

  @override
  State<_KeyboardSheet> createState() => _KeyboardSheetState();
}

class _KeyboardSheetState extends State<_KeyboardSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() async {
    final text = _controller.text;
    if (text.isEmpty) return;

    setState(() => _sending = true);
    await widget.connectionService
        .sendCommand(Protocol.keyCommand(text));

    if (mounted) {
      setState(() => _sending = false);
      _controller.clear();
      if (widget.connectionService.mode == ConnectionMode.tcp) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              )),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Scrivi qui...',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: _sending
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                onPressed: _sending ? null : _send,
              ),
            ),
            onSubmitted: (_) => _send(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _specKey('Invio', '\n'),
              const SizedBox(width: 8),
              _specKey('Tab', '\t'),
              const SizedBox(width: 8),
              _specKey('Spazio', ' '),
              const SizedBox(width: 8),
              _specKey('❌ Cancella', ''),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _specKey(String label, String char) {
    return Material(
      color: Colors.grey.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          if (char.isEmpty) {
            _controller.clear();
          } else {
            final pos = _controller.selection.baseOffset;
            final text = _controller.text;
            _controller.text = '${text.substring(0, pos)}$char${text.substring(pos)}';
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: pos + char.length),
            );
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
