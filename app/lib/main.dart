import 'package:lingo_core/lingo_core.dart';
import 'package:lingo_protocol/lingo_protocol.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  runApp(const LingowanderApp());
}

/// Placeholder home. Feature screens are not implemented yet.
class LingowanderApp extends StatelessWidget {
  const LingowanderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: '语遇',
      home: Scaffold(
        body: Center(
          child: Text(
            '语遇 Lingowander\n客户端骨架\n$lingoCoreName · $lingoProtocolName',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
