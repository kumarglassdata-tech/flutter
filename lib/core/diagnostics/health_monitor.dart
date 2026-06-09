import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:smartglass_flutter/core/engines/context/context_client.dart';
import 'package:smartglass_flutter/core/engines/behavior/behavior_client.dart';
import 'package:smartglass_flutter/core/engines/interaction/interaction_client.dart';
import 'package:smartglass_flutter/core/engines/ecom/ecom_client.dart';
import 'package:smartglass_flutter/core/engines/memory/memory_client.dart';
import 'package:smartglass_flutter/core/engines/shared/circuit_breaker.dart';
import 'package:smartglass_flutter/core/sources/source_manager.dart';

class HealthMonitor extends ChangeNotifier {
  final ContextClient _contextClient;
  final BehaviorClient _behaviorClient;
  final InteractionClient _interactionClient;
  final EcomClient _ecomClient;
  final MemoryClient _memoryClient;
  final SourceManager _sourceManager;

  Timer? _timer;
  bool _isRunning = false;

  HealthMonitor({
    required ContextClient contextClient,
    required BehaviorClient behaviorClient,
    required InteractionClient interactionClient,
    required EcomClient ecomClient,
    required MemoryClient memoryClient,
    required SourceManager sourceManager,
  })  : _contextClient = contextClient,
        _behaviorClient = behaviorClient,
        _interactionClient = interactionClient,
        _ecomClient = ecomClient,
        _memoryClient = memoryClient,
        _sourceManager = sourceManager {
    _sourceManager.addListener(_onSourceHealthUpdated);
  }

  bool get isRunning => _isRunning;

  // Circuit breaker states
  CircuitState get contextState => _contextClient.circuitBreaker.state;
  CircuitState get behaviorState => _behaviorClient.circuitBreaker.state;
  CircuitState get interactionState => _interactionClient.circuitBreaker.state;
  CircuitState get ecomState => _ecomClient.circuitBreaker.state;
  CircuitState get memoryState => _memoryClient.circuitBreaker.state;

  // Keep for backwards compatibility
  CircuitState get privacyState => _interactionClient.circuitBreaker.state;

  void start() {
    if (_isRunning) return;
    _isRunning = true;

    // Periodically notify listeners to update UI with latest circuit breaker states
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      notifyListeners();
    });
    notifyListeners();
  }

  void _onSourceHealthUpdated() {
    notifyListeners();
  }

  void stop() {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  void resetAllCircuits() {
    _contextClient.circuitBreaker.reset();
    _behaviorClient.circuitBreaker.reset();
    _interactionClient.circuitBreaker.reset();
    _ecomClient.circuitBreaker.reset();
    _memoryClient.circuitBreaker.reset();
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    _sourceManager.removeListener(_onSourceHealthUpdated);
    super.dispose();
  }
}
