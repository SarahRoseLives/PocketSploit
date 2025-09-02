import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui'; // For ImageFilter
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:msgpack_dart/msgpack_dart.dart';
import 'modules.dart'; // Import the module browser

void main() => runApp(const MetasploitRpcApp());

class MetasploitRpcApp extends StatelessWidget {
  const MetasploitRpcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Metasploit RPC UI',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.redAccent,
        cardColor: const Color(0xFF23232D),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
          ),
        ),
      ),
      home: const MetasploitLoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MetasploitLoginPage extends StatefulWidget {
  const MetasploitLoginPage({super.key});

  @override
  _MetasploitLoginPageState createState() => _MetasploitLoginPageState();
}

class _MetasploitLoginPageState extends State<MetasploitLoginPage> {
  final _hostController = TextEditingController(text: "192.168.1.240");
  final _portController = TextEditingController(text: "55553");
  final _userController = TextEditingController(text: "msf");
  final _passController = TextEditingController(text: "msf");

  bool _loading = false;
  String? _error;
  String? _token;
  Map<String, dynamic>? _stats;
  String _version = "";

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  dynamic _decodeMsgPackObject(dynamic data) {
    if (data is Uint8List) {
      return utf8.decode(data);
    }
    if (data is List) {
      return data.map((item) => _decodeMsgPackObject(item)).toList();
    }
    if (data is Map) {
      return data.map((key, value) =>
          MapEntry(_decodeMsgPackObject(key), _decodeMsgPackObject(value)));
    }
    return data;
  }

  Future<Map<String, dynamic>> _msfRpcCall(String method, [List<dynamic> params = const []]) async {
    final host = _hostController.text;
    final port = _portController.text;
    final url = Uri.parse('http://$host:$port/api/1.0/');

    final List<dynamic> payload = [method];
    if (_token != null && method != "auth.login") {
      payload.add(_token);
    }
    payload.addAll(params);

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'binary/message-pack'},
        body: serialize(payload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw 'HTTP Error ${response.statusCode}: ${response.reasonPhrase}';
      }

      final dynamic rawDecoded = deserialize(response.bodyBytes);
      final dynamic decoded = _decodeMsgPackObject(rawDecoded);

      if (decoded is! Map) {
        throw "Invalid response format from server. Expected a Map.";
      }

      final Map<String, dynamic> resultMap = Map<String, dynamic>.from(decoded);

      if (resultMap.containsKey('error') && resultMap['error'] == true) {
        final errorMessage = resultMap['error_message']?.toString() ??
            resultMap['error_string']?.toString() ??
            'An unknown RPC error occurred.';
        throw errorMessage;
      }

      return resultMap;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _login() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final resp = await _msfRpcCall("auth.login", [_userController.text, _passController.text]);

      if (resp['result'] == 'success') {
        _token = resp['token'];
        await _fetchStatsAndVersion();
      } else {
        setState(() => _error = 'Login failed: Unknown reason');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _fetchStatsAndVersion() async {
    try {
      final results = await Future.wait([
        _msfRpcCall("core.version"),
        _msfRpcCall("core.module_stats"),
      ]);

      final versionResp = results[0];
      final statsResp = results[1];

      _version = versionResp["version"]?.toString() ?? "Unknown";
      _stats = Map<String, dynamic>.from(statsResp);

      setState(() {});
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _logout() {
    if (_token != null) {
      _msfRpcCall("auth.logout", [_token]).catchError((e) {});
    }
    setState(() {
      _token = null;
      _stats = null;
      _passController.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_token != null && _stats != null) {
      return WelcomeDashboard(
        version: _version,
        stats: _stats!,
        onLogout: _logout,
        token: _token!,
        msfRpcCall: _msfRpcCall,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Metasploit RPC Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("Metasploit RPC Login",
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.redAccent),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _hostController,
                    decoration: const InputDecoration(labelText: "Host", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _portController,
                    decoration: const InputDecoration(labelText: "Port", border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _userController,
                    decoration: const InputDecoration(labelText: "Username", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passController,
                    decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder()),
                    obscureText: true,
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                  ],
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          onPressed: _login,
                          child: const Text("Login", style: TextStyle(fontSize: 18)),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WelcomeDashboard extends StatelessWidget {
  final String version;
  final Map<String, dynamic> stats;
  final VoidCallback onLogout;
  final String token;
  final Future<Map<String, dynamic>> Function(String, [List<dynamic>]) msfRpcCall;

  const WelcomeDashboard({
    super.key,
    required this.version,
    required this.stats,
    required this.onLogout,
    required this.token,
    required this.msfRpcCall,
  });

  static final moduleBadges = [
    ["exploits", "Exploits", Colors.orange, Colors.black],
    ["auxiliary", "Auxiliary", Colors.lightBlueAccent, Colors.black],
    ["post", "Post", Colors.purpleAccent, Colors.white],
    ["payloads", "Payloads", Colors.tealAccent, Colors.black],
    ["encoders", "Encoders", Colors.pinkAccent, Colors.white],
    ["nops", "Nops", Colors.amber, Colors.black],
    ["evasion", "Evasion", Colors.redAccent, Colors.white],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Metasploit Dashboard'),
        backgroundColor: Colors.redAccent,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: onLogout),
        ],
      ),
      body: Center(
        child: GlassCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                _buildLogo(),
                const SizedBox(height: 24),
                Text(
                  "Metasploit v$version",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Powerful penetration testing framework",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Wrap(
                  runSpacing: 15,
                  spacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final badge in moduleBadges)
                      StatBadge(
                        count: stats[badge[0] as String]?.toString() ?? "?",
                        label: badge[1] as String,
                        color: badge[2] as Color,
                        textColor: badge[3] as Color,
                      ),
                  ],
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text("Browse Modules"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 4,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ModuleBrowserScreen(
                          token: token,
                          msfRpcCall: msfRpcCall,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Colors.redAccent, Colors.black87],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Colors.redAccent.withOpacity(0.35), blurRadius: 18, spreadRadius: 3),
        ],
      ),
      child: const Center(
        child: Icon(Icons.security, color: Colors.white, size: 54),
      ),
    );
  }
}

class StatBadge extends StatelessWidget {
  final String count;
  final String label;
  final Color color;
  final Color textColor;

  const StatBadge({
    super.key,
    required this.count,
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 2.2),
        borderRadius: BorderRadius.circular(14),
        color: color.withOpacity(0.14),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Replace the circle with plain number text
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              count,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: textColor,
                fontSize: 20,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 18,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;

  const GlassCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: Colors.white12, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black87.withOpacity(0.20), blurRadius: 32, spreadRadius: 8),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: child,
        ),
      ),
    );
  }
}