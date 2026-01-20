import 'dart:ui';
import '../../models/role.dart';

extension RoleColorExtension on Role {
  Color get color {
    final hexCode = colorHex.replaceAll('#', '');
    try {
      return Color(int.parse('FF$hexCode', radix: 16));
    } catch (e) {
      return const Color(0xFFFFFFFF);
    }
  }
}
