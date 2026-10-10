/// Utility function to format any integer into its English ordinal representation:
/// 1 -> "1st", 2 -> "2nd", 3 -> "3rd", 4 -> "4th", 81 -> "81st", etc.
String formatOrdinal(int number) {
  if (number < 0) return '$number';
  final mod100 = number % 100;
  if (mod100 >= 11 && mod100 <= 13) {
    return '${number}th';
  }
  switch (number % 10) {
    case 1:
      return '${number}st';
    case 2:
      return '${number}nd';
    case 3:
      return '${number}rd';
    default:
      return '${number}th';
  }
}
