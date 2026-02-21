class PermissionFlags {
  static const int none = 0;
  static const int administrator = 1 << 0; // Bypasses all checks
  static const int manageGroup = 1 << 1; // Edit Name, Avatar
  static const int manageRoles = 1 << 2; // Create/Edit Roles
  static const int manageMembers = 1 << 3; // Kick/Ban
  static const int createPolls = 1 << 4;
  static const int manageVault = 1 << 5;
  static const int manageCalendar = 1 << 6;
  static const int manageTasks = 1 << 7;
  static const int mentionEveryone = 1 << 8;
  static const int viewVault = 1 << 9;

  // Widget permissions (view / create-edit / manage)
  static const int viewCalendar = 1 << 10;
  static const int editCalendar = 1 << 11;
  static const int viewTasks = 1 << 12;
  static const int editTasks = 1 << 13;
  static const int viewPolls = 1 << 14;
  static const int editPolls = 1 << 15;
  static const int managePolls = 1 << 16;
  static const int editVault = 1 << 17;
  static const int viewNotes = 1 << 18;
  static const int editNotes = 1 << 19;
  static const int manageNotes = 1 << 20;
  static const int viewChat = 1 << 21;
  static const int editChat = 1 << 22;
  static const int manageChat = 1 << 23;
  static const int viewMembers = 1 << 24;
  static const int editMembers = 1 << 25;
  static const int manageInvites = 1 << 26;
  static const int interactCalendar = 1 << 27;
  static const int interactVault = 1 << 28;
  static const int interactTasks = 1 << 29;
  static const int interactPolls = 1 << 30;
  static const int createChatRooms = 1 << 31;
  static const int editChatRooms = 1 << 32;
  static const int deleteChatRooms = 1 << 33;
  static const int startPrivateChats = 1 << 34;
  static const int leavePrivateChats = 1 << 35;
  static const int createCalendar = 1 << 36;
  static const int createTasks = 1 << 37;
  static const int createVault = 1 << 38;
  static const int createNotes = 1 << 39;

  // Sentinel for "all permissions" in calculated results.
  static const int all = -1;

  // Default for new members.
  static const int defaultMember =
      viewVault |
      interactVault |
      createVault |
      viewCalendar |
      editCalendar |
      interactCalendar |
      createCalendar |
      viewTasks |
      editTasks |
      interactTasks |
      createTasks |
      viewPolls |
      editPolls |
      interactPolls |
      createPolls |
      viewNotes |
      editNotes |
      createNotes |
      viewChat |
      editChat |
      createChatRooms |
      startPrivateChats |
      leavePrivateChats |
      viewMembers;

  static int normalize(int permissions) {
    if (permissions == all) return all;
    var normalized = permissions;

    if ((normalized & createPolls) != 0) {
      normalized |= editPolls | viewPolls;
    }

    if ((normalized & manageVault) != 0) {
      normalized |= editVault | interactVault | viewVault | createVault;
    }
    if ((normalized & manageCalendar) != 0) {
      normalized |=
          editCalendar | interactCalendar | viewCalendar | createCalendar;
    }
    if ((normalized & manageTasks) != 0) {
      normalized |= editTasks | interactTasks | viewTasks | createTasks;
    }

    if ((normalized & managePolls) != 0) {
      normalized |= editPolls | interactPolls | viewPolls | createPolls;
    }

    if ((normalized & interactCalendar) != 0) {
      normalized |= viewCalendar;
    }
    if ((normalized & interactVault) != 0) {
      normalized |= viewVault;
    }
    if ((normalized & interactTasks) != 0) {
      normalized |= viewTasks;
    }
    if ((normalized & interactPolls) != 0) {
      normalized |= viewPolls;
    }

    if ((normalized & editPolls) != 0) {
      normalized |= interactPolls | viewPolls | createPolls;
    }
    if ((normalized & editVault) != 0) {
      normalized |= interactVault | viewVault | createVault;
    }
    if ((normalized & editCalendar) != 0) {
      normalized |= interactCalendar | viewCalendar | createCalendar;
    }
    if ((normalized & editTasks) != 0) {
      normalized |= interactTasks | viewTasks | createTasks;
    }
    if ((normalized & editNotes) != 0) {
      normalized |= viewNotes | createNotes;
    }

    if ((normalized & createCalendar) != 0) normalized |= viewCalendar;
    if ((normalized & createTasks) != 0) normalized |= viewTasks;
    if ((normalized & createVault) != 0) normalized |= viewVault;
    if ((normalized & createNotes) != 0) normalized |= viewNotes;

    if ((normalized & manageNotes) != 0) {
      normalized |= editNotes | viewNotes | createNotes;
    }
    if ((normalized & manageChat) != 0) {
      normalized |=
          editChat |
          viewChat |
          createChatRooms |
          editChatRooms |
          deleteChatRooms |
          startPrivateChats |
          leavePrivateChats;
    }
    if ((normalized & editChat) != 0) {
      // Backward compatibility: historic "edit chat" included thread creation.
      normalized |=
          viewChat | createChatRooms | startPrivateChats | leavePrivateChats;
    }
    if ((normalized &
            (createChatRooms |
                editChatRooms |
                deleteChatRooms |
                startPrivateChats |
                leavePrivateChats)) !=
        0) {
      normalized |= viewChat;
    }
    if ((normalized & manageMembers) != 0) {
      normalized |= editMembers | viewMembers;
    }
    if ((normalized & editMembers) != 0) normalized |= viewMembers;

    return normalized;
  }

  static int canonicalize(int permissions) {
    if (permissions == all) return all;
    var canonical = normalize(permissions);

    if ((canonical & (editPolls | managePolls)) != 0) {
      canonical |= createPolls;
    }

    if ((canonical & (editVault | manageVault)) != 0) {
      canonical |= interactVault | viewVault | createVault;
    }
    if ((canonical & (editCalendar | manageCalendar)) != 0) {
      canonical |= interactCalendar | viewCalendar | createCalendar;
    }
    if ((canonical & (editTasks | manageTasks)) != 0) {
      canonical |= interactTasks | viewTasks | createTasks;
    }
    if ((canonical & (editNotes | manageNotes)) != 0) {
      canonical |= viewNotes | createNotes;
    }
    if ((canonical & (editMembers | manageMembers)) != 0) {
      canonical |= viewMembers;
    }
    if ((canonical & (editChat | manageChat)) != 0) {
      canonical |= viewChat | createChatRooms | startPrivateChats;
    }
    if ((canonical & manageChat) != 0) {
      canonical |=
          editChatRooms | deleteChatRooms | leavePrivateChats | editChat;
    }
    if ((canonical &
            (createChatRooms |
                editChatRooms |
                deleteChatRooms |
                startPrivateChats |
                leavePrivateChats)) !=
        0) {
      canonical |= viewChat;
    }
    if ((canonical & interactCalendar) != 0) {
      canonical |= viewCalendar;
    }
    if ((canonical & interactVault) != 0) {
      canonical |= viewVault;
    }
    if ((canonical & interactTasks) != 0) {
      canonical |= viewTasks;
    }
    if ((canonical & (editPolls | managePolls)) != 0) {
      canonical |= interactPolls | viewPolls;
    }
    if ((canonical & interactPolls) != 0) {
      canonical |= viewPolls;
    }

    return canonical;
  }
}
