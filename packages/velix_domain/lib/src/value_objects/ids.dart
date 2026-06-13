/// Strongly-typed ID extensions used across the domain.
///
/// Extension types give us nominal typing with zero runtime overhead.
/// `ConversationId('c1')` is *not* assignable to `MessageId` even though
/// both are backed by `String`.
library;

extension type const ConversationId(String value) {}

extension type const MessageId(String value) {}

extension type const IdentityId(String value) {}

extension type const DeviceId(String value) {}

extension type const SpaceId(String value) {}

extension type const StoryId(String value) {}

extension type const NotificationId(String value) {}
