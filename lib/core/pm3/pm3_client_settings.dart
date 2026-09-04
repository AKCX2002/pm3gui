/// Persisted desktop-client settings independent of UI state.
final class Pm3ClientSettings {
  const Pm3ClientSettings({
    required this.executable,
    this.port = '',
    this.arguments = const [],
    this.workingDirectory,
  });

  final String executable;
  final String port;
  final List<String> arguments;
  final String? workingDirectory;

  Map<String, Object?> toJson() => <String, Object?>{
        'executable': executable,
        'port': port,
        'arguments': arguments,
        'workingDirectory': workingDirectory,
      };

  static Pm3ClientSettings? fromJson(Object? value) {
    if (value is! Map) return null;

    final executable = value['executable'];
    final port = value['port'];
    final arguments = value['arguments'];
    final workingDirectory = value['workingDirectory'];
    if (executable is! String ||
        port is! String ||
        arguments is! List ||
        !arguments.every((argument) => argument is String) ||
        (workingDirectory != null && workingDirectory is! String)) {
      return null;
    }

    return Pm3ClientSettings(
      executable: executable,
      port: port,
      arguments: List<String>.from(arguments),
      workingDirectory: workingDirectory as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Pm3ClientSettings &&
      executable == other.executable &&
      port == other.port &&
      _sameArguments(arguments, other.arguments) &&
      workingDirectory == other.workingDirectory;

  @override
  int get hashCode => Object.hash(
        executable,
        port,
        Object.hashAll(arguments),
        workingDirectory,
      );

  static bool _sameArguments(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
