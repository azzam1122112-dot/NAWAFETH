import 'dart:async';

/// ينفذ آخر عملية حفظ بعد مهلة قصيرة، ويدعم flush عند الخروج من الشاشة.
class DebouncedSaveRunner {
  DebouncedSaveRunner({
    this.delay = const Duration(milliseconds: 700),
  });

  final Duration delay;
  Timer? _timer;
  Future<void> Function()? _pendingTask;
  Future<void>? _inFlight;

  void schedule(Future<void> Function() task) {
    _pendingTask = task;
    _timer?.cancel();
    _timer = Timer(delay, () {
      _runPending();
    });
  }

  Future<void> flush() async {
    _timer?.cancel();
    await _runPending();
  }

  Future<void> _runPending() async {
    final task = _pendingTask;
    if (task == null) return;
    _pendingTask = null;

    if (_inFlight != null) {
      await _inFlight;
    }

    final current = task();
    _inFlight = current;
    try {
      await current;
    } finally {
      if (identical(_inFlight, current)) {
        _inFlight = null;
      }
    }

    if (_pendingTask != null) {
      await _runPending();
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}
