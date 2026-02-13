class WindowType {
  final String label;
  final String graphicKey;
  final List<WindowType> children;
  final int? displayIndex;

  const WindowType({
    required this.label,
    required this.graphicKey,
    required this.children,
    required this.displayIndex,
  });

  bool get hasChildren => children.isNotEmpty;
}
