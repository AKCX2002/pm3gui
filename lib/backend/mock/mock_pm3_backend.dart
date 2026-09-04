import 'dart:async';

import 'package:pm3gui/core/pm3/pm3_backend.dart';
import 'package:pm3gui/core/pm3/pm3_command.dart';
import 'package:pm3gui/core/pm3/pm3_connection.dart';
import 'package:pm3gui/core/pm3/pm3_event.dart';
import 'package:pm3gui/core/pm3/pm3_result.dart';

/// Deterministic backend for feature development and tests without hardware.
final class MockPm3Backend implements Pm3Backend {
  MockPm3Backend({this.responses = const {}});

  final Map<String, String> responses;
  final StreamController<Pm3Event> _events =
      StreamController<Pm3Event>.broadcast(sync: true);
  Pm3ConnectionState _state = Pm3ConnectionState.disconnected;

  @override
  Stream<Pm3Event> get events => _events.stream;
  @override
  Pm3ConnectionState get state => _state;
  @override
  String get version => 'mock';
  @override
  String get lastError => '';

  @override
  Future<void> connect(Pm3ConnectionConfig config) async {
    _setState(Pm3ConnectionState.connecting);
    _setState(Pm3ConnectionState.connected);
  }

  @override
  Future<Pm3Result> execute(Pm3Command command, {Duration? timeout}) async {
    if (_state != Pm3ConnectionState.connected) {
      throw StateError('PM3 is not connected');
    }
    final startedAt = DateTime.now();
    final output = responses[command.id] ?? '';
    for (final line in output.split('\n').where((line) => line.isNotEmpty)) {
      _events.add(Pm3OutputEvent(DateTime.now(), line));
    }
    return Pm3Result(
      command: command,
      output: output,
      startedAt: startedAt,
      finishedAt: DateTime.now(),
    );
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> disconnect() async {
    _setState(Pm3ConnectionState.disconnected);
  }

  void _setState(Pm3ConnectionState state) {
    _state = state;
    _events.add(Pm3StateChangedEvent(DateTime.now(), state));
  }

  @override
  Future<void> shutdown() => _events.close();
}
