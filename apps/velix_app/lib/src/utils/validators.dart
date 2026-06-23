/// Input validation utilities.
class Validators {
  static bool isValidHandle(String h) => RegExp(r'^[a-zA-Z0-9._-]{3,32}$').hasMatch(h);
  static bool isValidEmail(String e) => RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(e);
  static int passwordStrength(String p) {
    int score = 0;
    if (p.length >= 8) score++;
    if (p.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(p)) score++;
    if (RegExp(r'[0-9]').hasMatch(p)) score++;
    if (RegExp(r'[!@#$%^&*]').hasMatch(p)) score++;
    return score;
  }
}
