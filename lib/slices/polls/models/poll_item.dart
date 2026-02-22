import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:cohortz/slices/permissions_core/acl_group_ids.dart';

part 'poll_item.mapper.dart';

@MappableEnum()
enum PollTiebreakerPolicy {
  statusQuo,
  optimistic,
  creatorPrivilege,
  chaos,
  voteAgain;

  int get code => index;

  String get shortLabel {
    switch (this) {
      case PollTiebreakerPolicy.statusQuo:
        return 'Fail';
      case PollTiebreakerPolicy.optimistic:
        return 'Pass';
      case PollTiebreakerPolicy.creatorPrivilege:
        return 'Creator';
      case PollTiebreakerPolicy.chaos:
        return 'Random';
      case PollTiebreakerPolicy.voteAgain:
        return 'Revote';
    }
  }

  String get description {
    switch (this) {
      case PollTiebreakerPolicy.statusQuo:
        return 'If votes are equal, the motion is rejected.';
      case PollTiebreakerPolicy.optimistic:
        return 'If votes are equal, the motion is approved.';
      case PollTiebreakerPolicy.creatorPrivilege:
        return 'If votes are equal, follow the creator vote.';
      case PollTiebreakerPolicy.chaos:
        return 'If votes are equal, resolve at random.';
      case PollTiebreakerPolicy.voteAgain:
        return 'If votes are equal, restart the vote.';
    }
  }

  static PollTiebreakerPolicy fromCode(Object? value) {
    if (value is int &&
        value >= 0 &&
        value < PollTiebreakerPolicy.values.length) {
      return PollTiebreakerPolicy.values[value];
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return fromCode(parsed);
      }
      return PollTiebreakerPolicy.values.firstWhere(
        (e) => e.name == value,
        orElse: () => PollTiebreakerPolicy.statusQuo,
      );
    }
    return PollTiebreakerPolicy.statusQuo;
  }
}

@MappableEnum()
enum PollMajorityPolicy {
  simple,
  superMajority,
  unanimous;

  int get code => index;

  String get shortLabel {
    switch (this) {
      case PollMajorityPolicy.simple:
        return 'Simple';
      case PollMajorityPolicy.superMajority:
        return 'Super';
      case PollMajorityPolicy.unanimous:
        return 'Unanimous';
    }
  }

  String get description {
    switch (this) {
      case PollMajorityPolicy.simple:
        return 'More yes than no wins.';
      case PollMajorityPolicy.superMajority:
        return 'Requires at least 2/3 yes votes to pass.';
      case PollMajorityPolicy.unanimous:
        return 'Requires 100% yes votes to pass.';
    }
  }

  static PollMajorityPolicy fromCode(Object? value) {
    if (value is int &&
        value >= 0 &&
        value < PollMajorityPolicy.values.length) {
      return PollMajorityPolicy.values[value];
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return fromCode(parsed);
      }
      return PollMajorityPolicy.values.firstWhere(
        (e) => e.name == value,
        orElse: () => PollMajorityPolicy.simple,
      );
    }
    return PollMajorityPolicy.simple;
  }
}

@MappableEnum()
enum PollVoteChoice {
  approve,
  reject;

  int get code => index;

  static PollVoteChoice? fromCode(Object? value) {
    if (value is int && value >= 0 && value < PollVoteChoice.values.length) {
      return PollVoteChoice.values[value];
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return fromCode(parsed);
      }
      for (final choice in PollVoteChoice.values) {
        if (choice.name == value) return choice;
      }
    }
    return null;
  }
}

@MappableEnum()
enum PollOutcomeState { active, approved, rejected }

@MappableClass()
class PendingVoter with PendingVoterMappable {
  final String uid;

  PendingVoter({required this.uid});
}

@MappableClass()
class PollItem with PollItemMappable {
  final String id;
  final String question;
  final int approvedCount;
  final int rejectedCount;
  final int requiredVotes;
  final DateTime endTime;
  final int durationHours;
  final List<PendingVoter> pendingVoters;
  final List<String> votedUserIds;
  final bool isUrgent;
  final PollTiebreakerPolicy tiebreakerPolicy;
  final PollMajorityPolicy majorityPolicy;
  final String creatorId;
  final PollVoteChoice? creatorVote;
  final List<String> visibilityGroupIds;

  PollItem({
    required this.id,
    required this.question,
    required this.approvedCount,
    this.rejectedCount = 0,
    required this.requiredVotes,
    required this.endTime,
    this.durationHours = 2,
    required this.pendingVoters,
    this.votedUserIds = const [],
    this.isUrgent = false,
    this.tiebreakerPolicy = PollTiebreakerPolicy.statusQuo,
    this.majorityPolicy = PollMajorityPolicy.simple,
    this.creatorId = '',
    this.creatorVote,
    this.visibilityGroupIds = const [AclGroupIds.everyone],
  });

  int get totalVotes => approvedCount + rejectedCount;

  bool get isTie => approvedCount == rejectedCount;

  Duration get duration => Duration(hours: durationHours);

  bool isClosedAt(DateTime at) {
    final reachedGoal = requiredVotes > 0 && totalVotes >= requiredVotes;
    final expired = at.isAfter(endTime);
    return reachedGoal || expired;
  }

  bool shouldRestartOnTieAt(DateTime at) {
    return isClosedAt(at) &&
        isTie &&
        tiebreakerPolicy == PollTiebreakerPolicy.voteAgain;
  }

  PollItem restart(DateTime at) {
    return copyWith(
      approvedCount: 0,
      rejectedCount: 0,
      votedUserIds: const [],
      endTime: at.add(duration),
      creatorVote: null,
    );
  }

  PollVoteChoice resolveTie() {
    switch (tiebreakerPolicy) {
      case PollTiebreakerPolicy.statusQuo:
        return PollVoteChoice.reject;
      case PollTiebreakerPolicy.optimistic:
        return PollVoteChoice.approve;
      case PollTiebreakerPolicy.creatorPrivilege:
        if (creatorVote == PollVoteChoice.approve) {
          return PollVoteChoice.approve;
        }
        return PollVoteChoice.reject;
      case PollTiebreakerPolicy.chaos:
        final digest = sha256.convert(utf8.encode(id)).bytes;
        return digest.last.isEven
            ? PollVoteChoice.approve
            : PollVoteChoice.reject;
      case PollTiebreakerPolicy.voteAgain:
        return PollVoteChoice.reject;
    }
  }

  bool hasSuperMajorityApproval() {
    if (totalVotes == 0) return false;
    return approvedCount * 3 >= totalVotes * 2;
  }

  bool hasUnanimousApproval() {
    if (totalVotes == 0) return false;
    return approvedCount == totalVotes && rejectedCount == 0;
  }

  PollOutcomeState outcomeAt(DateTime at) {
    if (!isClosedAt(at)) return PollOutcomeState.active;
    if (shouldRestartOnTieAt(at)) return PollOutcomeState.active;

    if (approvedCount > rejectedCount) {
      if (majorityPolicy == PollMajorityPolicy.unanimous &&
          !hasUnanimousApproval()) {
        return PollOutcomeState.rejected;
      }
      if (majorityPolicy == PollMajorityPolicy.superMajority &&
          !hasSuperMajorityApproval()) {
        return PollOutcomeState.rejected;
      }
      return PollOutcomeState.approved;
    } else if (rejectedCount > approvedCount) {
      return PollOutcomeState.rejected;
    } else {
      // Tie
      final choice = resolveTie();
      return choice == PollVoteChoice.approve
          ? PollOutcomeState.approved
          : PollOutcomeState.rejected;
    }
  }
}
