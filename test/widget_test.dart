import 'package:club_blackout/utils/role_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recommendedDealerCount matches 6/10/+4 rule', () {
    expect(RoleValidator.recommendedDealerCount(1), 1);
    expect(RoleValidator.recommendedDealerCount(6), 1);
    expect(RoleValidator.recommendedDealerCount(7), 2);
    expect(RoleValidator.recommendedDealerCount(10), 2);
    expect(RoleValidator.recommendedDealerCount(11), 3);
    expect(RoleValidator.recommendedDealerCount(14), 3);
    expect(RoleValidator.recommendedDealerCount(15), 4);
  });
}
