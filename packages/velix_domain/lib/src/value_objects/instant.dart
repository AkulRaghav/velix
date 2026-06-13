/// A monotonic timestamp value object with explicit UTC semantics.
///
/// We avoid raw `DateTime` across the domain because Dart's `DateTime`
/// is mutable in posture (allows arithmetic that mixes locales), and
/// because we want `==` to mean "the same instant" regardless of source
/// timezone.
import 'package:meta/meta.dart';

@immutable
class Instant implements Comparable<Instant> {
  const Instant(this._microsecondsSinceEpoch);

  Instant.fromDateTime(DateTime t)
      : _microsecondsSinceEpoch = t.toUtc().microsecondsSinceEpoch;

  factory Instant.now() => Instant.fromDateTime(DateTime.timestamp());

  static const Instant epoch = Instant(0);

  final int _microsecondsSinceEpoch;

  int get microsecondsSinceEpoch => _microsecondsSinceEpoch;
  int get millisecondsSinceEpoch => _microsecondsSinceEpoch ~/ 1000;
  int get secondsSinceEpoch => _microsecondsSinceEpoch ~/ 1000000;

  DateTime toDateTime() =>
      DateTime.fromMicrosecondsSinceEpoch(_microsecondsSinceEpoch, isUtc: true);

  Duration since(Instant earlier) => Duration(
        microseconds: _microsecondsSinceEpoch - earlier._microsecondsSinceEpoch,
      );

  Instant plus(Duration d) =>
      Instant(_microsecondsSinceEpoch + d.inMicroseconds);

  Instant minus(Duration d) =>
      Instant(_microsecondsSinceEpoch - d.inMicroseconds);

  bool isBefore(Instant other) =>
      _microsecondsSinceEpoch < other._microsecondsSinceEpoch;

  bool isAfter(Instant other) =>
      _microsecondsSinceEpoch > other._microsecondsSinceEpoch;

  @override
  int compareTo(Instant other) =>
      _microsecondsSinceEpoch.compareTo(other._microsecondsSinceEpoch);

  @override
  bool operator ==(Object other) =>
      other is Instant &&
      _microsecondsSinceEpoch == other._microsecondsSinceEpoch;

  @override
  int get hashCode => _microsecondsSinceEpoch.hashCode;

  @override
  String toString() => 'Instant(${toDateTime().toIso8601String()})';
}
