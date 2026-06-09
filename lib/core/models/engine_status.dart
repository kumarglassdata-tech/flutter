import 'package:smartglass_flutter/core/engines/shared/circuit_breaker.dart';

class EngineStatus {
  final String engine;
  final String state; // CONNECTED, CONNECTING, ERROR, OFFLINE
  final String? message;
  final DateTime timestamp;
  final Duration? latency;

  EngineStatus({
    required this.engine,
    required this.state,
    this.message,
    required this.timestamp,
    this.latency,
  });

  Map<String, dynamic> toJson() {
    return {
      'engine': engine,
      'state': state,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'latency_ms': latency?.inMilliseconds,
    };
  }
}

class ApiHealth {
  final String name;
  final Uri endpoint;
  final CircuitState circuit;
  final bool reachable;
  final Duration latency;
  final String? lastError;

  ApiHealth({
    required this.name,
    required this.endpoint,
    required this.circuit,
    required this.reachable,
    required this.latency,
    this.lastError,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'endpoint': endpoint.toString(),
      'circuit': circuit.name,
      'reachable': reachable,
      'latency_ms': latency.inMilliseconds,
      'lastError': lastError,
    };
  }
}
