import 'package:flutter_test/flutter_test.dart';
import 'package:club_blackout/utils/role_validator.dart';

void main() {
  test('recommendedDealerCount matches 1-per-7 rule', () {
    expect(RoleValidator.recommendedDealerCount(4), 1);
    expect(RoleValidator.recommendedDealerCount(7), 1);
    expect(RoleValidator.recommendedDealerCount(8), 2);
    expect(RoleValidator.recommendedDealerCount(14), 2);
    expect(RoleValidator.recommendedDealerCount(15), 3);
  });
}
