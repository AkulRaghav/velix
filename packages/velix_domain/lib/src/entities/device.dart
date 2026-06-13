import 'package:meta/meta.dart';

import '../value_objects/ids.dart';
import '../value_objects/instant.dart';

enum DeviceStatus { active, paused, revoked }

@immutable
class Device {
  const Device({
    required this.id,
    required this.identityId,
    required this.name,
    required this.publicKey,
    required this.pairedAt,
    required this.lastSeenAt,
    required this.status,
  });

  final DeviceId id;
  final IdentityId identityId;
  final String name; // "Quinn's iPhone"
  final List<int> publicKey;
  final Instant pairedAt;
  final Instant lastSeenAt;
  final DeviceStatus status;
}
