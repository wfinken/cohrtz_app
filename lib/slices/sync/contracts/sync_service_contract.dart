import 'package:cohortz/slices/sync/contracts/group_descriptor.dart';
import 'package:cryptography/cryptography.dart';
import 'package:livekit_client/livekit_client.dart';

abstract class ISyncService {
  String? get activeRoomName;
  String? get currentRoomName;
  String? get identity;
  bool get isConnected;
  bool get isActiveRoomConnected;
  bool get isActiveRoomConnecting;
  Map<String, RemoteParticipant> get remoteParticipants;

  List<Map<String, String?>> get knownGroups;
  List<Map<String, String?>> get knownInviteGroups;
  List<Map<String, String?>> get allKnownGroups;
  List<GroupDescriptor> get knownGroupDescriptors;
  List<GroupDescriptor> get knownInviteGroupDescriptors;
  List<GroupDescriptor> get allKnownGroupDescriptors;

  Future<void> connect(
    String token,
    String roomName, {
    String? identity,
    String? inviteCode,
    String? friendlyName,
    String? dataRoomName,
    bool isHost = false,
    bool setActive = true,
  });
  Future<void> connectAllKnownGroups();
  Future<void> disconnect();
  Future<void> joinInviteRoom(
    String token,
    String groupName, {
    String? identity,
    bool setActive = false,
  });
  Future<List<Map<String, String?>>> getKnownGroups();
  Future<KnownGroupsSnapshot> getKnownGroupsSnapshot();
  Future<void> forgetGroup(String roomName);
  bool isGroupConnected(String roomName);
  void setActiveRoom(String roomName);
  String getFriendlyName(String? roomName);
  Future<SecretKey> getVaultKey(
    String roomName, {
    bool allowGenerateIfMissing = false,
  });
}
