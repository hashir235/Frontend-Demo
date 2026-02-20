class WindowType {
  final String label;
  final String graphicKey;
  final List<WindowType> children;
  final int? displayIndex;
  final String? codeName;

  const WindowType({
    required this.label,
    required this.graphicKey,
    required this.children,
    required this.displayIndex,
    this.codeName,
  });

  bool get hasChildren => children.isNotEmpty;
}
