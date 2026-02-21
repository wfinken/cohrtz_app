import 'permission_flags.dart';

class PermissionUtils {
  static bool has(int permissions, int flag) {
    if (permissions == PermissionFlags.all) return true;
    if ((permissions & PermissionFlags.administrator) != 0) return true;
    return (permissions & flag) != 0;
  }
}
