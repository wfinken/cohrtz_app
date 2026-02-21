/// Shared layout constants for the Cohrtz application.
class LayoutConstants {
  LayoutConstants._();

  /// Standard corner radius for cards/dialogs in the bento visual system.
  static const double kDefaultRadius = 32.0;

  /// The height of the chat accordion header when collapsed.
  static const double chatAccordionHeaderHeight = 56.0;

  /// The width of the top border of the chat accordion.
  static const double chatAccordionBorderWidth = 1.0;

  /// The total height of the chat accordion when collapsed,
  /// including the top border.
  static const double chatAccordionTotalHeight =
      chatAccordionHeaderHeight + chatAccordionBorderWidth;
}
