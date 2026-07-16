import 'package:flutter/material.dart';

/// Semantic colours for money states, resolved per brightness.
///
/// The app previously used fixed hex values (`AppColors.success` / `error`)
/// straight from widgets. Those are tuned for a light surface and stay exactly
/// as dark in dark mode, which is why amounts read poorly there. These tokens
/// carry a light and a dark variant instead, so a widget asks for "positive"
/// and gets something legible in either theme.
@immutable
class MoneyColors extends ThemeExtension<MoneyColors> {
  /// Money you keep — a positive remaining balance.
  final Color positive;
  final Color positiveContainer;
  final Color onPositiveContainer;

  /// Money going out — expenses, an overdrawn balance.
  final Color negative;
  final Color negativeContainer;
  final Color onNegativeContainer;

  /// Owed but not yet settled — an unpaid credit card expense.
  final Color pending;
  final Color pendingContainer;
  final Color onPendingContainer;

  /// Squared up — a split whose participants have repaid.
  final Color settled;
  final Color settledContainer;
  final Color onSettledContainer;

  const MoneyColors({
    required this.positive,
    required this.positiveContainer,
    required this.onPositiveContainer,
    required this.negative,
    required this.negativeContainer,
    required this.onNegativeContainer,
    required this.pending,
    required this.pendingContainer,
    required this.onPendingContainer,
    required this.settled,
    required this.settledContainer,
    required this.onSettledContainer,
  });

  static const light = MoneyColors(
    positive: Color(0xFF146B3A),
    positiveContainer: Color(0xFFC8F0D6),
    onPositiveContainer: Color(0xFF05371B),
    negative: Color(0xFFB3261E),
    negativeContainer: Color(0xFFF9DEDC),
    onNegativeContainer: Color(0xFF410E0B),
    pending: Color(0xFF8A5000),
    pendingContainer: Color(0xFFFFDDAF),
    onPendingContainer: Color(0xFF2B1700),
    settled: Color(0xFF0B5FA5),
    settledContainer: Color(0xFFCFE5FF),
    onSettledContainer: Color(0xFF001D36),
  );

  static const dark = MoneyColors(
    positive: Color(0xFF7ADF9E),
    positiveContainer: Color(0xFF14532B),
    onPositiveContainer: Color(0xFFA9F5C4),
    negative: Color(0xFFF2B8B5),
    negativeContainer: Color(0xFF8C1D18),
    onNegativeContainer: Color(0xFFF9DEDC),
    pending: Color(0xFFFFD08A),
    pendingContainer: Color(0xFF5C3A00),
    onPendingContainer: Color(0xFFFFDDAF),
    settled: Color(0xFF9BCBFF),
    settledContainer: Color(0xFF00416B),
    onSettledContainer: Color(0xFFD3E8FF),
  );

  /// The colour a balance should be shown in, given whether it's in the black.
  Color forBalance(double amount) => amount >= 0 ? positive : negative;

  @override
  MoneyColors copyWith({
    Color? positive,
    Color? positiveContainer,
    Color? onPositiveContainer,
    Color? negative,
    Color? negativeContainer,
    Color? onNegativeContainer,
    Color? pending,
    Color? pendingContainer,
    Color? onPendingContainer,
    Color? settled,
    Color? settledContainer,
    Color? onSettledContainer,
  }) {
    return MoneyColors(
      positive: positive ?? this.positive,
      positiveContainer: positiveContainer ?? this.positiveContainer,
      onPositiveContainer: onPositiveContainer ?? this.onPositiveContainer,
      negative: negative ?? this.negative,
      negativeContainer: negativeContainer ?? this.negativeContainer,
      onNegativeContainer: onNegativeContainer ?? this.onNegativeContainer,
      pending: pending ?? this.pending,
      pendingContainer: pendingContainer ?? this.pendingContainer,
      onPendingContainer: onPendingContainer ?? this.onPendingContainer,
      settled: settled ?? this.settled,
      settledContainer: settledContainer ?? this.settledContainer,
      onSettledContainer: onSettledContainer ?? this.onSettledContainer,
    );
  }

  @override
  MoneyColors lerp(ThemeExtension<MoneyColors>? other, double t) {
    if (other is! MoneyColors) return this;
    return MoneyColors(
      positive: Color.lerp(positive, other.positive, t)!,
      positiveContainer:
          Color.lerp(positiveContainer, other.positiveContainer, t)!,
      onPositiveContainer:
          Color.lerp(onPositiveContainer, other.onPositiveContainer, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
      negativeContainer:
          Color.lerp(negativeContainer, other.negativeContainer, t)!,
      onNegativeContainer:
          Color.lerp(onNegativeContainer, other.onNegativeContainer, t)!,
      pending: Color.lerp(pending, other.pending, t)!,
      pendingContainer: Color.lerp(pendingContainer, other.pendingContainer, t)!,
      onPendingContainer:
          Color.lerp(onPendingContainer, other.onPendingContainer, t)!,
      settled: Color.lerp(settled, other.settled, t)!,
      settledContainer: Color.lerp(settledContainer, other.settledContainer, t)!,
      onSettledContainer:
          Color.lerp(onSettledContainer, other.onSettledContainer, t)!,
    );
  }
}

extension MoneyColorsX on BuildContext {
  /// Semantic money colours for the current theme.
  ///
  /// Falls back to the brightness-appropriate defaults rather than asserting:
  /// a [Theme] built without this extension (a bare `MaterialApp`, a local
  /// `Theme` override, a widget preview) should render slightly off-palette
  /// amounts, not crash the screen.
  MoneyColors get money {
    final theme = Theme.of(this);
    return theme.extension<MoneyColors>() ??
        (theme.brightness == Brightness.dark
            ? MoneyColors.dark
            : MoneyColors.light);
  }
}
