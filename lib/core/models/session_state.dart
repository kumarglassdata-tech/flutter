class SessionState {
  /// Nine numeric outputs expected from the on-device model.
  final List<double> outputs;

  /// Optional structured context returned by model or orchestration
  final Map<String, dynamic>? context;

  SessionState({required this.outputs, this.context});

  factory SessionState.fromMap(Map<String, dynamic> map) {
    final outputsRaw = map['outputs'];
    List<double> outputs = List.filled(9, 0.0);
    if (outputsRaw is List) {
      for (var i = 0; i < outputs.length && i < outputsRaw.length; i++) {
        final v = outputsRaw[i];
        if (v is num) outputs[i] = v.toDouble();
      }
    }

    final ctx = <String, dynamic>{};
    map.forEach((k, v) {
      if (k != 'outputs') ctx[k] = v;
    });

    return SessionState(outputs: outputs, context: ctx.isEmpty ? null : ctx);
  }
}
