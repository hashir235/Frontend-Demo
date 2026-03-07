class WindowType {
  final String label;
  final String graphicKey;
  final List<WindowType> children;
  final int? displayIndex;
  final String? codeName;
  final String? subtitle;

  const WindowType({
    required this.label,
    required this.graphicKey,
    required this.children,
    required this.displayIndex,
    this.codeName,
    this.subtitle,
  });

  bool get hasChildren => children.isNotEmpty;
}
