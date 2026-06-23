enum OnlineState { online, away, offline, doNotDisturb }

class OnlineStatus {
  final OnlineState state;
  final DateTime? lastSeen;
  const OnlineStatus({required this.state, this.lastSeen});
  String get displayText => switch (state) { OnlineState.online => 'Online', OnlineState.away => 'Away', OnlineState.doNotDisturb => 'Do not disturb', OnlineState.offline => lastSeen != null ? 'Last seen recently' : 'Offline' };
}
