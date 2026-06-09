import 'dart:math';

class RetryPolicy {
  final int attempts;
  final int baseDelayMs;
  final int maxJitterMs;
  final _rng = Random();

  RetryPolicy({
    this.attempts = 2,
    this.baseDelayMs = 200,
    this.maxJitterMs = 100,
  });

  Duration backoffDelay(int attempt) {
    final multiplier = 1 << (attempt - 1);
    final jitter = _rng.nextInt(maxJitterMs + 1);
    return Duration(milliseconds: baseDelayMs * multiplier + jitter);
  }
}
