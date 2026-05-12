import 'package:flutter_riverpod/flutter_riverpod.dart';

final calendarProvider = StateNotifierProvider<CalendarNotifier, DateTime>((ref) {
  return CalendarNotifier();
});

class CalendarNotifier extends StateNotifier<DateTime> {
  CalendarNotifier() : super(DateTime.now());

  void setSelectedDay(DateTime day) {
    state = day;
  }

  void setFocusedDay(DateTime day) {
    state = day;
  }

  void goToNextMonth() {
    state = DateTime(state.year, state.month + 1, 1);
  }

  void goToPreviousMonth() {
    state = DateTime(state.year, state.month - 1, 1);
  }

  void goToToday() {
    state = DateTime.now();
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
