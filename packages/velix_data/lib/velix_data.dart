/// Velix data layer.
///
/// Phase 5 ships in-memory repository implementations.
/// Alpha build adds the HTTP-backed remote repositories that talk to the
/// `backend/alpha` server.
library velix_data;

export 'src/repositories/in_memory_conversation_repository.dart';
export 'src/repositories/in_memory_message_repository.dart';
export 'src/repositories/in_memory_identity_repository.dart';
export 'src/fixtures.dart';

// Alpha — runnable build pieces.
export 'src/alpha/alpha_api_client.dart';
export 'src/alpha/alpha_session.dart';
export 'src/alpha/remote_conversation_repository.dart';
export 'src/alpha/remote_message_repository.dart';
export 'src/alpha/remote_identity_repository.dart';

// Settings — user-configurable preferences.
export 'src/settings/accessibility_preferences.dart';
