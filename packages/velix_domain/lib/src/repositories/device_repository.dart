import '../entities/device.dart';
import '../value_objects/ids.dart';

abstract interface class DeviceRepository {
  Stream<List<Device>> watch();

  Future<void> revoke(DeviceId id);

  /// Returns the [Device] for the local hardware. Always non-null after
  /// pairing completes.
  Future<Device?> currentDevice();
}
