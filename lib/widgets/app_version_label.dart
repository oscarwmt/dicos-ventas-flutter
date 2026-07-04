import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersionLabel extends StatefulWidget {
  const AppVersionLabel({super.key});

  @override
  State<AppVersionLabel> createState() => _AppVersionLabelState();
}

class _AppVersionLabelState extends State<AppVersionLabel> {
  String _versionText = 'Versión cargando...';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();

      if (!mounted) return;

      setState(() {
        _versionText = 'Versión ${info.version}+${info.buildNumber}';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _versionText = 'Versión no disponible';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _versionText,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey.shade600,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
