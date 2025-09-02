import 'package:flutter/material.dart';

class ModuleBrowserScreen extends StatefulWidget {
  final String token;
  final Future<Map<String, dynamic>> Function(String method, [List<dynamic> params]) msfRpcCall;

  const ModuleBrowserScreen({
    super.key,
    required this.token,
    required this.msfRpcCall,
  });

  @override
  State<ModuleBrowserScreen> createState() => _ModuleBrowserScreenState();
}

class _ModuleBrowserScreenState extends State<ModuleBrowserScreen> {
  final moduleTypes = [
    {'key': 'exploits', 'name': 'Exploits', 'icon': Icons.bug_report, 'color': Colors.orange},
    {'key': 'auxiliary', 'name': 'Auxiliary', 'icon': Icons.extension, 'color': Colors.blue},
    {'key': 'post', 'name': 'Post', 'icon': Icons.build, 'color': Colors.purple},
    {'key': 'payloads', 'name': 'Payloads', 'icon': Icons.send, 'color': Colors.teal},
    {'key': 'encoders', 'name': 'Encoders', 'icon': Icons.code, 'color': Colors.pink},
    {'key': 'nops', 'name': 'Nops', 'icon': Icons.blur_on, 'color': Colors.amber},
    {'key': 'evasion', 'name': 'Evasion', 'icon': Icons.visibility_off, 'color': Colors.red},
  ];

  String? selectedType;
  List<String>? modules;
  List<String>? filteredModules;
  bool loading = false;
  String? error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedType = moduleTypes.first['key'] as String?;
    _searchController.addListener(_filterModules);
    _fetchModules(selectedType!);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchModules(String type) async {
    setState(() {
      loading = true;
      error = null;
      modules = null;
      filteredModules = null;
    });
    try {
      // FIX: Call without token in params, rely on main.dart to add token automatically
      final result = await widget.msfRpcCall('module.$type');
      final mods = List<String>.from(result['modules'] ?? []);
      setState(() {
        modules = mods;
        filteredModules = mods;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        modules = null;
        filteredModules = null;
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  void _onTypeChanged(String type) {
    setState(() {
      selectedType = type;
      _searchController.clear();
    });
    _fetchModules(type);
  }

  void _filterModules() {
    if (modules == null) return;
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        filteredModules = modules;
      });
    } else {
      setState(() {
        filteredModules = modules!
            .where((m) => m.toLowerCase().contains(query))
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = moduleTypes.firstWhere((t) => t['key'] == selectedType);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Module Browser'),
        backgroundColor: Colors.redAccent,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: moduleTypes.map((type) {
                  final isSelected = selectedType == type['key'];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(type['name'] as String),
                      selected: isSelected,
                      avatar: Icon(type['icon'] as IconData, color: type['color'] as Color),
                      selectedColor: (type['color'] as Color).withOpacity(0.2),
                      onSelected: (_) => _onTypeChanged(type['key'] as String),
                      labelStyle: TextStyle(
                        color: isSelected ? type['color'] as Color : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search modules...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(child: Text(error!, style: const TextStyle(color: Colors.redAccent)))
                    : (filteredModules == null || filteredModules!.isEmpty)
                        ? const Center(child: Text("No modules found."))
                        : ListView.builder(
                            itemCount: filteredModules!.length,
                            itemBuilder: (context, idx) {
                              final mod = filteredModules![idx];
                              return ListTile(
                                leading: Icon(selected['icon'] as IconData, color: selected['color'] as Color),
                                title: Text(mod, style: const TextStyle(fontFamily: 'monospace')),
                                onTap: () {
                                  // TODO: Push to module details/config screen
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}