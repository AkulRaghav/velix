extension StringX on String {
  String get initials => split(' ').where((w) => w.isNotEmpty).map((w) => w[0].toUpperCase()).take(2).join();
  String get truncated => length > 50 ? '${substring(0, 47)}...' : this;
}

extension ListX<T> on List<T> {
  List<T> get unique => toSet().toList();
}
