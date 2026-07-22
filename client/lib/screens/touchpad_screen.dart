/**
 * touchpad_screen.dart — Schermata principale di controllo
 *
 * Contiene:
 * - Touchpad virtuale per movimento mouse
 * - Pulsanti click sinistro, destro, doppio
 * - Pulsante tastiera
 * - Stato connessione
 */

import 'package:flutter/material.dart';

import '../services/connection_service.dart';
import '../services/protocol.dart';
import '../widgets/control_buttons.dart';
import '../widgets/remote_screen.dart';
import '../widgets/virtual_touchpad.dart';
import 'login_screen.dart';

class TouchpadScreen extends StatefulWidget {
  final ConnectionService connectionService;

  const TouchpadScreen({super.key, required this.connectionService});

  @override
  State<TouchpadScreen> createState() => _TouchpadScreenState();
}

class _TouchpadScreenState extends State<TouchpadScreen>
    with WidgetsBindingObserver {
  final _textController = TextEditingController();
  bool _sending = false;
  String? _lastStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Pausa
    }
  }

  // ==============================================================
  // Azioni touchpad
  // ==============================================================

  void _onMouseMove(double pctX, double pctY) {
    final cmd = Protocol.mouseCommand(pctX, pctY);
    widget.connectionService.sendCommandFast(cmd);
  }

  void _onLeftClick() {
    setState(() => _lastStatus = 'Click sinistro');
    widget.connectionService
        .sendCommand(Protocol.clickCommand(Protocol.clickLeft))
        .then((result) {
      if (mounted) {
        setState(() {
          _lastStatus =
              result.success ? 'Click sinistro ✓' : 'Errore: ${result.message}';
        });
      }
    });
  }

  void _onRightClick() {
    setState(() => _lastStatus = 'Click destro');
    widget.connectionService
        .sendCommand(Protocol.clickCommand(Protocol.clickRight))
        .then((result) {
      if (mounted) {
        setState(() {
          _lastStatus =
              result.success ? 'Click destro ✓' : 'Errore: ${result.message}';
        });
      }
    });
  }

  void _onDoubleClick() {
    setState(() => _lastStatus = 'Doppio click');
    widget.connectionService
        .sendCommand(Protocol.clickCommand(Protocol.clickDouble))
        .then((result) {
      if (mounted) {
        setState(() {
          _lastStatus =
              result.success ? 'Doppio click ✓' : 'Errore: ${result.message}';
        });
      }
    });
  }

  // ==============================================================
  // Tastiera
  // ==============================================================

  void _openKeyboard() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Digita sul PC',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _textController,
                autofocus: true,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Scrivi qui il testo da inviare...',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sending ? null : _sendText,
                  ),
                ),
                onSubmitted: (_) => _sendText(),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  _specialKey(ctx, 'Invio', '\n'),
                  const SizedBox(width: 8),
                  _specialKey(ctx, 'Tab', '\t'),
                  const SizedBox(width: 8),
                  _specialKey(ctx, 'Spazio', ' '),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _lastStatus ?? '',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _specialKey(BuildContext ctx, String label, String char) {
    return Material(
      color: Colors.grey.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          final current = _textController.text;
          _textController.text = current + char;
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: _textController.text.length),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  void _sendText() async {
    final text = _textController.text;
    if (text.isEmpty) return;

    setState(() => _sending = true);
    _lastStatus = 'Invio testo...';

    final result = await widget.connectionService
        .sendCommand(Protocol.keyCommand(text));

    if (mounted) {
      setState(() {
        _sending = false;
        _lastStatus = result.success
            ? '✅ Testo inviato (${text.length} car.)'
            : '❌ ${result.message}';
      });

      if (result.success) {
        _textController.clear();
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) setState(() => _lastStatus = null);
        });
      }
    }
  }

  // ==============================================================
  // Disconnessione
  // ==============================================================

  void _disconnect() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnetti'),
        content: const Text('Sei sicuro di volerti disconnettere?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnetti'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await widget.connectionService.disconnect();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = widget.connectionService.isConnected;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _disconnect();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Remote Control', style: TextStyle(fontSize: 18)),
              Text(
                widget.connectionService.connectionDisplay,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          centerTitle: false,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.circle,
                size: 12,
                color: connected ? Colors.green : Colors.red,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.monitor),
              onPressed: connected
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RemoteScreen(
                            connectionService: widget.connectionService,
                            streamHost: widget.connectionService.host,
                            streamPort: widget.connectionService.port + 2,
                            password: widget.connectionService.password,
                          ),
                        ),
                      );
                    }
                  : null,
              tooltip: 'Schermo PC',
            ),
            IconButton(
              icon: const Icon(Icons.link_off),
              onPressed: _disconnect,
              tooltip: 'Disconnetti',
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: VirtualTouchpad(
                    onMove: _onMouseMove,
                    onTap: _onLeftClick,
                    onSecondaryTap: _onRightClick,
                    enabled: connected,
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: ControlButtons(
                  onLeftClick: _onLeftClick,
                  onRightClick: _onRightClick,
                  onDoubleClick: _onDoubleClick,
                  onOpenKeyboard: _openKeyboard,
                  enabled: connected,
                ),
              ),

              if (connected)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Row(
                    children: [
                      Icon(Icons.swipe_up_alt,
                          size: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.5)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ScrollBar(
                          onScroll: (dy) {
                            widget.connectionService.sendCommand(
                                Protocol.scrollCommand(0, dy));
                          },
                        ),
                      ),
                    ],
                  ),
                ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: connected
                      ? Colors.green.withValues(alpha: 0.05)
                      : Colors.red.withValues(alpha: 0.05),
                  border: Border(
                    top: BorderSide(
                      color: connected
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.red.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      connected ? Icons.check_circle : Icons.error,
                      size: 14,
                      color: connected ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      connected
                          ? (_lastStatus ?? 'Connesso — trascina per muovere il mouse')
                          : 'Disconnesso',
                      style: TextStyle(
                        fontSize: 12,
                        color: connected ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget per lo scroll verticale
class _ScrollBar extends StatefulWidget {
  final Function(int dy) onScroll;

  const _ScrollBar({required this.onScroll});

  @override
  State<_ScrollBar> createState() => _ScrollBarState();
}

class _ScrollBarState extends State<_ScrollBar> {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Listener(
          onPointerMove: (event) {
            final delta = event.delta;
            if (delta.dy.abs() > delta.dx.abs()) {
              int scrollAmount = delta.dy < 0 ? 1 : -1;
              scrollAmount *= (delta.dy.abs() / 5).ceil().clamp(1, 5);
              widget.onScroll(scrollAmount);
            }
          },
          child: Row(
            children: [
              const SizedBox(width: 8),
              Icon(Icons.keyboard_arrow_up,
                  size: 18,
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.5)),
              Expanded(child: Container()),
              Icon(Icons.keyboard_arrow_down,
                  size: 18,
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.5)),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
