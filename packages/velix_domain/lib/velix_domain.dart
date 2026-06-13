/// Velix domain layer.
///
/// Pure Dart. No Flutter, no platform dependencies. Holds the contract
/// surface every other layer composes against.
library velix_domain;

export 'src/value_objects/ids.dart';
export 'src/value_objects/instant.dart';
export 'src/value_objects/result.dart';

export 'src/entities/identity.dart';
export 'src/entities/device.dart';
export 'src/entities/conversation.dart';
export 'src/entities/message.dart';
export 'src/entities/trust_state.dart';
export 'src/entities/connectivity_state.dart';

export 'src/errors/app_error.dart';

export 'src/repositories/conversation_repository.dart';
export 'src/repositories/message_repository.dart';
export 'src/repositories/identity_repository.dart';
export 'src/repositories/device_repository.dart';

export 'src/use_cases/watch_conversations.dart';
export 'src/use_cases/watch_messages.dart';
export 'src/use_cases/send_message.dart';
export 'src/use_cases/mark_conversation_as_read.dart';
export 'src/use_cases/archive_conversation.dart';
export 'src/use_cases/create_identity.dart';
