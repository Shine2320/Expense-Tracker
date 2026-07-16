import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One-shot message shown after the balance migration restates stored history,
/// so a user who sees their past months change knows why. Cleared once shown.
final migrationNoticeProvider = StateProvider<String?>((ref) => null);
