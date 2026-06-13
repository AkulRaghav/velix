/// Velix AI layer.
///
/// Phase 8 reference skeleton. The implementation follows the architecture
/// in `docs/phase-8/`. Cloud invocation goes through an OHTTP-style relay
/// (Phase 8 doc 05); on-device inference uses TFLite/CoreML/Gemini Nano
/// (Phase 8 doc 04).
///
/// The package's posture: every cloud invocation requires a per-query
/// consent gesture; nothing happens to user content without an explicit
/// user action.
library velix_ai;

export 'src/router.dart';
export 'src/redaction.dart';
export 'src/consent.dart';
export 'src/types.dart';
