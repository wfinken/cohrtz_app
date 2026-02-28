// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

typedef WebExitHandler = void Function();

class WebPageLifecycle {
  StreamSubscription<html.Event>? _beforeUnloadSub;
  StreamSubscription<html.Event>? _pageHideSub;
  bool _didTriggerExit = false;

  void register(WebExitHandler onExit) {
    void triggerExit() {
      if (_didTriggerExit) return;
      _didTriggerExit = true;
      onExit();
    }

    _beforeUnloadSub = html.window.onBeforeUnload.listen((_) {
      triggerExit();
    });
    _pageHideSub = html.window.onPageHide.listen((_) {
      triggerExit();
    });
  }

  void dispose() {
    _beforeUnloadSub?.cancel();
    _beforeUnloadSub = null;
    _pageHideSub?.cancel();
    _pageHideSub = null;
  }
}
