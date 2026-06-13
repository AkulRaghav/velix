/// Network connectivity as observed by the client.
///
/// The `metered` state indicates a connection that is paid-for-by-data
/// (cellular, hotspot). The user can configure whether large media
/// uploads use metered connections.
enum ConnectivityState {
  offline,
  connecting,
  online,
  metered,
}
