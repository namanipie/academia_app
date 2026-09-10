import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Service & Widget Imports
import '../services/study_material.dart';
import '../widgets/subject_material_info_widget.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  bool _loading = true;
  String _query = '';
  Map<String, Map<String, dynamic>> _materials = {};
  List<SubjectEntry> _subjects = [];
  List<SubjectEntry> _filtered = [];
  Set<String> _mySubjectIds = {};
  String? _selectedSem;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _load();
  }

  // --- LOGIC ---
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final List<String>? saved = prefs.getStringList('my_subjects');
      if (saved != null) _mySubjectIds = saved.toSet();
    });
  }

  Future<void> _toggleMySubject(String id) async {
    setState(() {
      if (_mySubjectIds.contains(id)) {
        _mySubjectIds.remove(id);
      } else {
        _mySubjectIds.add(id);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('my_subjects', _mySubjectIds.toList());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await getMaterialsData();
      _materials = data;
      _subjects = _flatten(data);
      _applyFilter();
    } catch (e) {
      if (kDebugMode) debugPrint('Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  List<SubjectEntry> _flatten(Map<String, Map<String, dynamic>> map) {
    final list = <SubjectEntry>[];
    map.forEach((sem, subjects) {
      subjects.forEach((id, doc) {
        String display = id;
        final keys = ['Subject', 'subject', 'Title', 'title', 'Name', 'name'];
        for (final k in keys) {
          if (doc[k] != null && doc[k].toString().trim().isNotEmpty) {
            display = doc[k].toString();
            break;
          }
        }
        list.add(SubjectEntry(
          sem: sem,
          id: id,
          displayName: display,
          data: Map<String, dynamic>.from(doc),
        ));
      });
    });
    list.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return list;
  }

  void _applyFilter() {
    final q = _query.toLowerCase().trim();
    setState(() {
      _filtered = _subjects.where((s) {
        final matchesSem = _selectedSem == null ? true : s.sem == _selectedSem;
        final matchesQuery = q.isEmpty
            ? true
            : (s.displayName.toLowerCase().contains(q) || s.id.toLowerCase().contains(q));
        return matchesSem && matchesQuery;
      }).toList();
    });
  }

  List<String> get _semesterKeys {
    final keys = _materials.keys.toList();
    keys.sort((a, b) {
      final aNum = int.tryParse(RegExp(r'\d+').stringMatch(a) ?? '') ?? 999;
      final bNum = int.tryParse(RegExp(r'\d+').stringMatch(b) ?? '') ?? 999;
      return aNum.compareTo(bNum);
    });
    return keys;
  }

  Color _getSemColor(String semKey) {
    final key = semKey.toLowerCase();
    if (key.contains('1')) return Colors.orange;
    if (key.contains('2')) return const Color(0xFF61A5DD);
    if (key.contains('3')) return const Color(0xFFE040FB);
    if (key.contains('4')) return const Color(0xFF9DF8A0);
    if (key.contains('5')) return const Color(0xFFFD3974);
    return Colors.cyanAccent;
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    final mySubjectsList = _subjects.where((s) => _mySubjectIds.contains(s.id)).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
        title: const Text("Study Material", 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildSemesterFilters(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                if (mySubjectsList.isNotEmpty && _selectedSem == null && _query.isEmpty) 
                  _buildPinnedSection(mySubjectsList),
                
                _buildMainListHeader(),
                _buildMainList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 15),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(15),
        ),
        child: TextField(
          style: const TextStyle(color: Colors.white),
          onChanged: (v) {
            _query = v;
            _applyFilter();
          },
          decoration: InputDecoration(
            hintText: 'Search subjects or codes...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha:0.3)),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withValues(alpha:0.3)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildSemesterFilters() {
    return Container(
      height: 45,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _semesterKeys.length + 1,
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final sem = isAll ? null : _semesterKeys[index - 1];
          final isSelected = _selectedSem == sem;
          final color = isAll ? Colors.greenAccent : _getSemColor(sem!);

          return GestureDetector(
            onTap: () {
              setState(() => _selectedSem = sem);
              _applyFilter();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha:0.2) : const Color(0xFF121212),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isSelected ? color : Colors.transparent,
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                isAll ? "All" : sem!.toUpperCase(),
                style: TextStyle(
                  color: isSelected ? color : Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPinnedSection(List<SubjectEntry> pinned) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Text("Pinned Subjects", 
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: pinned.length,
            itemBuilder: (context, i) {
              final s = pinned[i];
              final color = _getSemColor(s.sem);
              return Container(
                width: 160,
                margin: const EdgeInsets.only(right: 12, bottom: 10, top: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.3), blurRadius: 8)],
                ),
                child: InkWell(
                  onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => SubjectMaterialsScreen(entry: s))),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: color.withValues(alpha:0.1), borderRadius: BorderRadius.circular(5)),
                              child: Text(s.sem.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                            GestureDetector(
                              onTap: () => _toggleMySubject(s.id),
                              child: const Icon(Icons.close_rounded, color: Colors.white24, size: 16),
                            )
                          ],
                        ),
                        const Spacer(),
                        Text(s.displayName, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMainListHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(_selectedSem == null ? "All Subjects" : "Semester ${_selectedSem!.replaceAll(RegExp(r'\D'), '')}",
              style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
          Text("${_filtered.length} items", style: const TextStyle(color: Colors.white24, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMainList() {
    if (_loading) return const Center(child: Padding(padding: EdgeInsets.only(top: 50), child: CircularProgressIndicator(color: Colors.orange)));
    if (_filtered.isEmpty) return const Center(child: Padding(padding: EdgeInsets.only(top: 50), child: Text("No subjects found", style: TextStyle(color: Colors.white24))));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filtered.length,
      itemBuilder: (context, i) {
        final s = _filtered[i];
        final color = _getSemColor(s.sem);
        final isAdded = _mySubjectIds.contains(s.id);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(20),
          ),
          child: InkWell(
            onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => SubjectMaterialsScreen(entry: s))),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    height: 45, width: 45,
                    decoration: BoxDecoration(color: color.withValues(alpha:0.1), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.book_rounded, color: color, size: 22),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(s.id, style: const TextStyle(color: Colors.white24, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _toggleMySubject(s.id),
                    icon: Icon(isAdded ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      color: isAdded ? color : Colors.white24),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}