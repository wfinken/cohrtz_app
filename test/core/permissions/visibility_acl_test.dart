import 'package:flutter_test/flutter_test.dart';

import 'package:cohortz/slices/permissions_core/acl_group_ids.dart';
import 'package:cohortz/slices/permissions_core/visibility_acl.dart';

void main() {
  group('normalizeVisibilityGroupIds', () {
    test('defaults to everyone when empty', () {
      expect(normalizeVisibilityGroupIds(const []), const [
        AclGroupIds.everyone,
      ]);
    });

    test('collapses to everyone when everyone is present', () {
      expect(
        normalizeVisibilityGroupIds(const [
          AclGroupIds.everyone,
          'ops',
          'design',
        ]),
        const [AclGroupIds.everyone],
      );
    });
  });

  group('canViewByLogicalGroups', () {
    test('allows when visibility includes everyone', () {
      expect(
        canViewByLogicalGroups(
          itemGroupIds: const [AclGroupIds.everyone],
          viewerGroupIds: const {'ops'},
        ),
        isTrue,
      );
    });

    test('allows when viewer has intersecting group', () {
      expect(
        canViewByLogicalGroups(
          itemGroupIds: const ['ops'],
          viewerGroupIds: const {'ops', 'design'},
        ),
        isTrue,
      );
    });

    test('denies when no overlap and no everyone', () {
      expect(
        canViewByLogicalGroups(
          itemGroupIds: const ['ops'],
          viewerGroupIds: const {'design'},
        ),
        isFalse,
      );
    });

    test('bypass always allows', () {
      expect(
        canViewByLogicalGroups(
          itemGroupIds: const ['ops'],
          viewerGroupIds: const {},
          bypass: true,
        ),
        isTrue,
      );
    });
  });
}
