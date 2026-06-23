class Throttle {
  Throttle({this.duration = const Duration(milliseconds: 500)});
  final Duration duration;
  DateTime? _last;
  void call(void Function() action) {
    final now = DateTime.now();
    if (_last == null || now.difference(_last!) >= duration) {
      _last = now;
      action();
    }
  }
}
