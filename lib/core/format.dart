/// Short number text for big idle-game values: 999, 1.50K, 12.3K, 2.50M ...
String formatNumber(num n) {
  const units = ['', 'K', 'M', 'B', 'T'];
  var v = n.toDouble();
  var i = 0;
  while (v >= 1000 && i < units.length - 1) {
    v /= 1000;
    i++;
  }
  if (i == 0) return v.round().toString();
  final text = v >= 100
      ? v.toStringAsFixed(0)
      : v >= 10
          ? v.toStringAsFixed(1)
          : v.toStringAsFixed(2);
  return '$text${units[i]}';
}
