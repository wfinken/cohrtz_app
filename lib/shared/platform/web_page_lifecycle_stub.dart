typedef WebExitHandler = void Function();

class WebPageLifecycle {
  void register(WebExitHandler onExit) {}

  void dispose() {}
}
