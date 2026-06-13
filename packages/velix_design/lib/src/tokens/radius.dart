import 'package:flutter/painting.dart';

class VelixRadius {
  const VelixRadius();

  Radius get xs => const Radius.circular(4);
  Radius get sm => const Radius.circular(8);
  Radius get md => const Radius.circular(12);
  Radius get lg => const Radius.circular(16);
  Radius get xl => const Radius.circular(20);
  Radius get xxl => const Radius.circular(28);
  Radius get pill => const Radius.circular(9999);

  BorderRadius get xsAll => BorderRadius.all(xs);
  BorderRadius get smAll => BorderRadius.all(sm);
  BorderRadius get mdAll => BorderRadius.all(md);
  BorderRadius get lgAll => BorderRadius.all(lg);
  BorderRadius get xlAll => BorderRadius.all(xl);
  BorderRadius get xxlAll => BorderRadius.all(xxl);
  BorderRadius get pillAll => BorderRadius.all(pill);

  /// The bottom-sheet asymmetric pattern: rounded top, square bottom.
  /// This is the only documented asymmetric usage in the system.
  BorderRadius get sheetTop => BorderRadius.only(topLeft: xxl, topRight: xxl);
}
