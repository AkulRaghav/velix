/// Velix motion & interaction system.
///
/// Phase 4 reference implementation. Composes `velix_design` tokens
/// (springs, durations, curves) into widgets, page routes, sheets,
/// scroll physics, haptics, and the realtime motion family.
library velix_motion;

export 'src/patterns/velix_arrive.dart';
export 'src/patterns/velix_depart.dart';
export 'src/patterns/velix_lateral.dart';
export 'src/patterns/velix_lift.dart';
export 'src/patterns/velix_reveal.dart';
export 'src/patterns/velix_parallax.dart';

export 'src/realtime/typing_indicator.dart';
export 'src/realtime/ai_streaming_text.dart';
export 'src/realtime/waveform.dart';

export 'src/navigation/velix_page_route.dart';

export 'src/sheets/velix_modal.dart';
export 'src/sheets/velix_sheet.dart';

export 'src/scroll/velix_scroll_physics.dart';

export 'src/haptics/velix_haptics.dart';

export 'src/util/velocity_handoff.dart';
