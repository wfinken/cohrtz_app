import 'dart:convert';

import 'package:cohortz/features/dashboard/domain/dashboard_models.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

PollItem _buildTiePoll({
  required PollTiebreakerPolicy policy,
  PollVoteChoice? creatorVote,
  String id = 'poll-1',
}) {
  return PollItem(
    id: id,
    question: 'Test poll',
    approvedCount: 2,
    rejectedCount: 2,
    requiredVotes: 4,
    endTime: DateTime(2026, 1, 1),
    pendingVoters: [],
    votedUserIds: const ['u1', 'u2', 'u3', 'u4'],
    creatorId: 'creator',
    creatorVote: creatorVote,
    tiebreakerPolicy: policy,
  );
}

void main() {
  group('Poll tiebreaker outcome', () {
    final closeTime = DateTime(2026, 1, 2);

    test('status quo rejects tied poll', () {
      final poll = _buildTiePoll(policy: PollTiebreakerPolicy.statusQuo);
      expect(poll.outcomeAt(closeTime), PollOutcomeState.rejected);
    });

    test('optimistic passes tied poll', () {
      final poll = _buildTiePoll(policy: PollTiebreakerPolicy.optimistic);
      expect(poll.outcomeAt(closeTime), PollOutcomeState.approved);
    });

    test('creator privilege follows creator vote', () {
      final yesPoll = _buildTiePoll(
        policy: PollTiebreakerPolicy.creatorPrivilege,
        creatorVote: PollVoteChoice.approve,
      );
      final noPoll = _buildTiePoll(
        policy: PollTiebreakerPolicy.creatorPrivilege,
        creatorVote: PollVoteChoice.reject,
      );
      final abstainPoll = _buildTiePoll(
        policy: PollTiebreakerPolicy.creatorPrivilege,
      );

      expect(yesPoll.outcomeAt(closeTime), PollOutcomeState.approved);
      expect(noPoll.outcomeAt(closeTime), PollOutcomeState.rejected);
      expect(abstainPoll.outcomeAt(closeTime), PollOutcomeState.rejected);
    });

    test('chaos policy uses deterministic hash parity of poll id', () {
      const id = 'chaos-poll-42';
      final poll = _buildTiePoll(policy: PollTiebreakerPolicy.chaos, id: id);
      final digest = sha256.convert(utf8.encode(id)).bytes;
      final expected = digest.last.isEven
          ? PollOutcomeState.approved
          : PollOutcomeState.rejected;

      expect(poll.outcomeAt(closeTime), expected);
      expect(poll.outcomeAt(closeTime), expected);
    });
  });

  group('Poll serialization', () {
    test('stores and restores integer tiebreaker enum', () {
      final original = PollItem(
        id: 'poll-serde',
        question: 'Serialize?',
        approvedCount: 1,
        rejectedCount: 1,
        requiredVotes: 2,
        endTime: DateTime(2026, 1, 1),
        pendingVoters: [],
        votedUserIds: const ['a', 'b'],
        creatorId: 'a',
        creatorVote: PollVoteChoice.approve,
        tiebreakerPolicy: PollTiebreakerPolicy.chaos,
      );

      final decoded = PollItemMapper.fromMap(original.toMap());
      expect(decoded.tiebreakerPolicy, PollTiebreakerPolicy.chaos);
      expect(decoded.creatorId, 'a');
      expect(decoded.creatorVote, PollVoteChoice.approve);
    });

    test('missing tiebreaker fields fallback safely', () {
      final decoded = PollItemMapper.fromMap({
        'id': 'legacy',
        'question': 'legacy',
        'approvedCount': 1,
        'rejectedCount': 1,
        'requiredVotes': 2,
        'endTime': DateTime(2026, 1, 1).toIso8601String(),
        'pendingVoters': [],
        'votedUserIds': ['a', 'b'],
        'isUrgent': false,
      });

      expect(decoded.tiebreakerPolicy, PollTiebreakerPolicy.statusQuo);
      expect(decoded.creatorId, '');
      expect(decoded.creatorVote, isNull);
    });
  });
}
