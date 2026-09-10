import 'package:flutter/material.dart';
import '../services/student_portal_data.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';


// --- Aesthetic Constants ---
const Color kPitchBlack = Color(0xFF000000);
const Color kCardBlack = Color(0xFF0D0D0D);
const Color kSurfaceGrey = Color(0xFF1A1A1A);
const Color kMutedText = Colors.white38;
const Color kAccentNeon = Color(0xFFD2FEA0); 

class MainPortalPage extends StatefulWidget {
  const MainPortalPage({super.key});

  @override
  State<MainPortalPage> createState() => _MainPortalPageState();
}

class _MainPortalPageState extends State<MainPortalPage> {
  Map<String, dynamic>? _studentData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkLocalStorage();
  }

  // --- Logic Blocks ---

  Future<void> _checkLocalStorage() async {
    final cached = await student_portal_Service.getCachedResult();
    if (mounted) {
      setState(() {
        _studentData = cached;
        _isLoading = false;
      });
    }
  }

  void _handleLogout() async {
    await student_portal_Service.clearResult();
    setState(() {
      _studentData = null;
    });
  }

  // GPA Calculator for Semester recently fetched (eg Sem 5)
  String _calculateSem5GPA(List subjects) {
    final gradeMap = {'O': 10, 'A+': 9, 'A': 8, 'B+': 7, 'B': 6, 'C': 5, 'P': 4, 'F': 0};
    double points = 0;
    int credits = 0;
    for (var s in subjects) {
      int c = int.tryParse(s[4].toString()) ?? 0;
      int g = gradeMap[s[7].toString()] ?? 0;
      points += (c * g);
      credits += (s[7].toString() == "O" || g > 0) ? c : 0; // Only count earned credits
    }
    return credits == 0 ? "0.00" : (points / credits).toStringAsFixed(3);
  }

  // Calculate Final CGPA including all semesters (1-5)
  String _calculateFinalCGPA(Map<String, String> semesterSGPAs) {
    if (semesterSGPAs.isEmpty) return "0.00";
    
    double totalGPA = 0.0;
    int semesterCount = 0;
    
    // Sum all semester SGPAs
    semesterSGPAs.forEach((semester, sgpa) {
      final gpaValue = double.tryParse(sgpa) ?? 0.0;
      totalGPA += gpaValue;
      semesterCount++;
    });
    
    // Calculate average CGPA across all semesters
    final finalCGPA = semesterCount > 0 ? totalGPA / semesterCount : 0.0;
    return finalCGPA.toStringAsFixed(2);
  }

  // Unified Parser to get ALL Semesters
  Map<String, dynamic> _getAllSemesterData() {
    final rawHistory = _studentData!['raw_tables'][0] as List;
    final recentSem = _studentData!['semester_results'][1] as List;
    
    Map<String, List<dynamic>> semesterSubjects = {};
    Map<String, String> semesterSGPAs = {};

    // 1. Process History (Sem 1-4 etc excluding recent sem eg 5 sem)
    for (var row in rawHistory) {
      if (row.length == 6 && row[0] != "Semester") {
        String sem = row[0].toString();
        semesterSubjects.putIfAbsent(sem, () => []);
        semesterSubjects[sem]!.add(row);
      } else if (row.length == 2 && row[0] == "SGPA") {
        semesterSGPAs[semesterSubjects.keys.last] = row[1].toString();
      }
    }

    // 2. Process Recent (Sem)
    final sem5Subs = recentSem.where((r) => r.length > 5).toList();
    if (sem5Subs.isNotEmpty) {
      semesterSubjects["5"] = sem5Subs;
      semesterSGPAs["5"] = _calculateSem5GPA(sem5Subs);
    }

    // 3. Calculate Final CGPA including Semester 5
    String finalCGPA = _calculateFinalCGPA(semesterSGPAs);

    return {
      "subjects": semesterSubjects, 
      "sgpas": semesterSGPAs, 
      "totalCgpa": finalCGPA
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: kPitchBlack, body: Center(child: CircularProgressIndicator(color: kAccentNeon)));
    return _studentData == null ? _buildLoginWidget() : _buildDashboardWidget();
  }

  // --- UI Components ---

  Widget _buildLoginWidget() {
    return Scaffold(
      backgroundColor: kPitchBlack,
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "STUDENT\nPORTAL", 
              style: TextStyle(color: kAccentNeon, fontWeight: FontWeight.w900, fontSize: 32)
            ),
            const SizedBox(height: 24),
            Text(
              "In-app syncing is temporarily unavailable due to SRM's new CAPTCHA security.",
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 16),
            Text(
              "You can still view your results by opening the official SRM portal directly.",
              style: TextStyle(color: kMutedText, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final url = Uri.parse('https://sp.srmist.edu.in/srmiststudentportal/');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.open_in_browser_rounded),
                label: const Text("OPEN OFFICIAL PORTAL", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentNeon, 
                  foregroundColor: Colors.black, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kMutedText),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                ),
                child: const Text("GO BACK", style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardWidget() {
    final data = _getAllSemesterData();
    final attendance = _studentData!['attendance_details'][0] as List;
    final internals = _studentData!['internal_marks'][0] as List;

    return Scaffold(
      backgroundColor: kPitchBlack,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
        title: const Text("Semester Results", 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          _buildHeroCGPA(data['totalCgpa'],data['sgpas']),
          const SizedBox(height: 32),
          
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20, horizontal: 8),
            child: Text("SEMESTER RECORDS (1-5)", style: TextStyle(color: kMutedText, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
          ),

          // Dynamically builds all 5 semesters
          ...(data['subjects'] as Map<String, List>).keys.toList().reversed.map((semNum) {
            String sgpa = data['sgpas'][semNum] ?? "N/A";
            return _buildExpandableTile(
              title: "SEMESTER $semNum",
              subtitle: "SGPA: $sgpa",
              icon: Icons.notes_rounded,
              isHighlight: semNum == "5",
              content: Column(
                children: (data['subjects'][semNum] as List).map((sub) {
                  // Handle different list structures for Sem 5 vs History
                  String name = sub.length > 5 ? sub[3] : sub[3]; 
                  String grade = sub.length > 7 ? sub[7] : sub[5];
                  return _buildCleanRow(name, grade);
                }).toList(),
              ),
            );
          }),
          const SizedBox(height: 40),

           const Padding(
            padding: EdgeInsets.symmetric(vertical: 20, horizontal: 8),
            child: Text("Last Sem Data ", style: TextStyle(color: kMutedText, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
          ),

          _buildExpandableTile(
            title: "ATTENDANCE",
            icon: Icons.check_circle_outline,
            content: Wrap(spacing: 8, runSpacing: 8, children: attendance.skip(1).map((a) => _buildStatPill(a[0], "${a[2]}%")).toList()),
          ),
          
          _buildExpandableTile(
            title: "INTERNAL MARKS",
            icon: Icons.analytics_outlined,
            content: Column(children: internals.skip(1).map((m) => _buildCleanRow(m[1], m[2])).toList()),
          ),
        ],
      ),
    );
  }

  // --- Sub-Widgets ---


Widget _buildHeroCGPA(String cgpaVal, Map<String, String> sgpas) {
  // Convert SGPAs to double for the graph
  List<double> gpaValues = sgpas.values
      .map((v) => double.tryParse(v) ?? 0.0)
      .toList();
  
  // Get the last sem gpa for comparison
  String lastSemGpa = sgpas.isNotEmpty
    ? (double.tryParse(sgpas.values.last) ?? 0.0).toStringAsFixed(2)
    : "0.00";

  double highestGpa = sgpas.values
      .map((v) => double.tryParse(v) ?? 0.0)
      .fold<double>(0.0, (max, val) => val > max ? val : max);

  String highestSemGpa = highestGpa.toStringAsFixed(2);



  return Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: const Color.fromARGB(255, 186, 226, 122),
      borderRadius: BorderRadius.circular(32),
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("OVERALL CGPA", 
                  style: TextStyle(color: Color.fromARGB(235, 0, 0, 0), fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2)),
                const SizedBox(height: 4),
                Text(cgpaVal, 
                  style: const TextStyle(color: Color.fromARGB(255, 255, 255, 255), fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -2)),
              ],
            ),
            _buildMiniTrend(highestSemGpa),
          ],
        ),
        const SizedBox(height: 20),
        
        // --- GPA Trend Graph ---
        SizedBox(
          height: 60,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: gpaValues.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                  isCurved: true,
                  color: const Color.fromARGB(255, 255, 255, 255),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [const Color.fromARGB(255, 219, 215, 215).withValues(alpha:0.2), const Color.fromARGB(255, 125, 121, 121).withValues(alpha:0)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        const Divider(color: kSurfaceGrey, thickness: 1),
        const SizedBox(height: 12),
        
        // --- Comparison Footer ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem("LAST SEM", lastSemGpa),
            _buildStatItem("SEMESTERS", gpaValues.length.toString()),
            _buildStatItem("STATUS", "PASS"),
          ],
        )
      ],
    ),
  );
}

Widget _buildMiniTrend(String highestGpa) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color.fromARGB(255, 25, 26, 25).withValues(alpha:0.1),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const Icon(Icons.trending_up, color: Color.fromARGB(255, 21, 22, 21), size: 16),
        const SizedBox(width: 6),
        Text(highestGpa, style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0), fontWeight: FontWeight.w900, fontSize: 12)),
      ],
    ),
  );
}

Widget _buildStatItem(String label, String value) {
  return Column(
    children: [
      Text(label, style: const TextStyle(color: Color.fromARGB(219, 246, 242, 242), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0), fontSize: 13, fontWeight: FontWeight.bold)),
    ],
  );
}

Widget _buildExpandableTile({
  required String title,
  String? subtitle,
  required IconData icon,
  required Widget content,
  bool isHighlight = false,
}) {
  return TweenAnimationBuilder<double>(
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOut,
    tween: Tween<double>(begin: 0.98, end: 1.0),
    builder: (context, scale, child) {
      return Transform.scale(
        scale: scale,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: kCardBlack,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isHighlight ? kAccentNeon.withValues(alpha:0.25) : Colors.transparent,
              width: 1.1,
            ),
            boxShadow: isHighlight
                ? [
                    BoxShadow(
                      color: kAccentNeon.withValues(alpha:0.10),
                      blurRadius: 14,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha:0.35),
                      blurRadius: 12,
                      spreadRadius: -2,
                      offset: const Offset(0, 3),
                    )
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: ExpansionTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kAccentNeon.withValues(alpha:0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: kAccentNeon, size: 18),
                ),

                tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),

                title: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),

                subtitle: subtitle != null
                    ? Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle,
                          style: const TextStyle(
                            color: kAccentNeon,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                          ),
                        ),
                      )
                    : null,

                iconColor: kAccentNeon,
                collapsedIconColor: kMutedText,

                shape: const RoundedRectangleBorder(side: BorderSide.none),

                children: [
                  const Divider(
                    color: Colors.white24,
                    thickness: 0.4,
                    height: 18,
                  ),
                  content,
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}


Widget _buildCleanRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          flex: 6,
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: kAccentNeon,             // background color
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.black,          // text inside pill
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}


  Widget _buildStatPill(String label, String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: kSurfaceGrey, borderRadius: BorderRadius.circular(16)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: const TextStyle(color: kMutedText, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
      ]),
    );
  }

}