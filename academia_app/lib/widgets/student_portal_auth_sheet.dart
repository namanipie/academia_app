import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/student_portal_parser.dart';

class StudentPortalAuthSheet extends StatefulWidget {
  const StudentPortalAuthSheet({super.key});

  /// Static helper to show the modal bottom sheet
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (ctx) => const StudentPortalAuthSheet(),
    );
  }

  @override
  State<StudentPortalAuthSheet> createState() => _StudentPortalAuthSheetState();
}

class _StudentPortalAuthSheetState extends State<StudentPortalAuthSheet> {
  static const Color _bgBlack = Color(0xFF0F0F12);
  static const Color _cardBlack = Color(0xFF18181D);
  static const Color _primaryAccent = Color(0xFFFF6B00);
  static const Color _neonGreen = Color(0xFF76FF03);
  static const Color _mutedText = Color(0xFF9E9E9E);

  late final WebViewController _controller;
  bool _isLoading = true;
  double _progress = 0;
  bool _isSyncingData = false;
  String _syncStatusText = 'Authenticating...';
  String? _prefillUsername;

  @override
  void initState() {
    super.initState();
    _initUsername();
    _initController();
  }

  Future<void> _initUsername() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('userData');
      if (raw != null && raw.isNotEmpty) {
        final data = json.decode(raw) as Map<String, dynamic>;
        final reg = data['attendance']?['student_info']?['registration_number'] ??
            data['timetable']?['student_info']?['registration_number'] ??
            data['netid'];
        if (reg != null && mounted) {
          setState(() {
            _prefillUsername = reg.toString().trim();
          });
        }
      }
    } catch (_) {}
  }

  void _initController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p / 100);
          },
          onPageStarted: (url) {
            if (mounted) {
              setState(() => _isLoading = true);
            }
            _checkIfDashboard(url);
          },
          onPageFinished: (url) async {
            if (mounted) {
              setState(() => _isLoading = false);
            }
            // Auto pre-fill username if on login page
            if (url.contains('youLogin.jsp') && _prefillUsername != null && _prefillUsername!.isNotEmpty) {
              try {
                await _controller.runJavaScript(
                  "if (document.getElementById('username') && !document.getElementById('username').value) { document.getElementById('username').value = '$_prefillUsername'; }",
                );
              } catch (_) {}
            }
            _checkIfDashboard(url);
          },
          onWebResourceError: (error) {
            if (kDebugMode) debugPrint('[PORTAL WEBVIEW] Error: ${error.description}');
          },
        ),
      )
      ..loadRequest(
        Uri.parse('https://sp.srmist.edu.in/srmiststudentportal/students/loginManager/youLogin.jsp'),
      );
  }

  void _checkIfDashboard(String url) {
    if (_isSyncingData) return;
    final lower = url.toLowerCase();
    if (lower.contains('hrdsystem.jsp') || lower.contains('studentprofile.jsp') || lower.contains('students/template')) {
      _handleLoginSuccess();
    }
  }

  Future<void> _handleLoginSuccess() async {
    if (_isSyncingData) return;
    setState(() {
      _isSyncingData = true;
      _syncStatusText = 'Connected! Fetching Attendance & Marks...';
    });

    try {
      // Execute extraction JS inside the authenticated WebView session
      const script = r'''
        (async function() {
          try {
            const csrf = document.getElementById('csrfPreventionSalt')?.value || '';
            const hdnForm = document.getElementById('hdnFormDetails')?.value || '1';

            function parseTables(html) {
              const doc = new DOMParser().parseFromString(html, 'text/html');
              const tables = doc.querySelectorAll('table');
              const res = [];
              tables.forEach(tbl => {
                const rows = [];
                tbl.querySelectorAll('tr').forEach(tr => {
                  const cells = [];
                  tr.querySelectorAll('th, td').forEach(c => {
                    cells.push(c.innerText.trim());
                  });
                  if (cells.length > 0) rows.push(cells);
                });
                if (rows.length > 0) res.push(rows);
              });
              return res;
            }

            async function postEndpoint(url, iden) {
              try {
                const p = new URLSearchParams();
                p.append('filter', '');
                p.append('hdnFormDetails', hdnForm);
                p.append('csrfPreventionSalt', csrf);
                p.append('iden', iden);

                const res = await fetch(url, {
                  method: 'POST',
                  headers: {
                    'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
                    'X-Requested-With': 'XMLHttpRequest'
                  },
                  body: p.toString()
                });
                return await res.text();
              } catch (e) {
                return '';
              }
            }

            const attendanceHtml = await postEndpoint('/srmiststudentportal/students/report/studentAttendanceDetails.jsp', '9');
            const marksHtml = await postEndpoint('/srmiststudentportal/students/report/studentInternalMarkDetails.jsp', '13');
            const resultsHtml = await postEndpoint('/srmiststudentportal/students/transaction/onlineResult.jsp', '24');
            const gradesHtml = await postEndpoint('/srmiststudentportal/students/report/studentMarksCredits.jsp', '8');
            const profileHtml = await postEndpoint('/srmiststudentportal/students/report/studentProfile.jsp', '1');

            return JSON.stringify({
              status: 'success',
              attendanceHtml: attendanceHtml,
              marksHtml: marksHtml,
              attendance_details: parseTables(attendanceHtml),
              internal_marks: parseTables(marksHtml),
              semester_results: parseTables(resultsHtml),
              raw_tables: parseTables(gradesHtml),
              profile: parseTables(profileHtml)
            });
          } catch (err) {
            return JSON.stringify({ status: 'error', error: err.toString() });
          }
        })();
      ''';

      final Object result = await _controller.runJavaScriptReturningResult(script);
      String rawString = result.toString();

      // On Android/iOS, runJavaScriptReturningResult may return a JSON-encoded string
      if (rawString.startsWith('"') && rawString.endsWith('"')) {
        try {
          rawString = json.decode(rawString);
        } catch (_) {}
      }

      final Map<String, dynamic> data = json.decode(rawString) as Map<String, dynamic>;

      if (data['status'] == 'success') {
        setState(() {
          _syncStatusText = 'Parsing Academic Records...';
        });

        final attendanceHtml = data['attendanceHtml']?.toString() ?? '';
        final marksHtml = data['marksHtml']?.toString() ?? '';

        final parsedAttendance = StudentPortalParser.parseAttendanceHtml(attendanceHtml);
        final parsedMarks = StudentPortalParser.parseMarksHtml(marksHtml);

        // Fallback to table arrays if HTML parser returned empty courses
        if ((parsedAttendance['courses'] as Map).isEmpty && data['attendance_details'] is List) {
          final tables = data['attendance_details'] as List;
          if (tables.isNotEmpty && tables[0] is List) {
            final fallbackAtt = StudentPortalParser.parseRawAttendanceTable(tables[0]);
            parsedAttendance['courses'] = fallbackAtt['courses'];
            parsedAttendance['overall_attendance'] = fallbackAtt['overall_attendance'];
            parsedAttendance['total_hours_conducted'] = fallbackAtt['total_hours_conducted'];
            parsedAttendance['total_hours_absent'] = fallbackAtt['total_hours_absent'];
          }
        }

        // Merge into userData
        await StudentPortalParser.mergeStudentPortalDataIntoUserData(
          attendanceData: parsedAttendance,
          marksData: parsedMarks,
          rawPortalResult: data,
        );

        if (mounted) {
          setState(() {
            _syncStatusText = 'Sync Complete!';
          });
          await Future.delayed(const Duration(milliseconds: 600));
          if (mounted) {
            Navigator.pop(context, true);
          }
        }
      } else {
        throw Exception(data['error'] ?? 'Unknown extraction error');
      }
    } catch (e, stack) {
      if (kDebugMode) debugPrint('[PORTAL WEBVIEW] Sync failed: $e\n$stack');
      if (mounted) {
        setState(() {
          _isSyncingData = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to retrieve data: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.90,
      decoration: const BoxDecoration(
        color: _bgBlack,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _cardBlack,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Icon(Icons.school_rounded, color: _neonGreen, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text(
                            "SRM Student Portal",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.verified_rounded, color: _neonGreen, size: 14),
                        ],
                      ),
                      Text(
                        _isSyncingData
                            ? _syncStatusText
                            : "Solve the CAPTCHA & sign in to sync Attendance & Marks",
                        style: TextStyle(
                          color: _isSyncingData ? _primaryAccent : _mutedText,
                          fontSize: 12,
                          fontWeight: _isSyncingData ? FontWeight.bold : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            ),
          ),

          // Loading progress indicator
          if (_isLoading || _isSyncingData)
            LinearProgressIndicator(
              value: _isSyncingData ? null : (_progress > 0 ? _progress : null),
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(_isSyncingData ? _neonGreen : _primaryAccent),
              minHeight: 2.5,
            ),

          // Main WebView or Syncing Overlay
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isSyncingData)
                  Container(
                    color: _bgBlack.withValues(alpha: 0.92),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 50,
                            height: 50,
                            child: CircularProgressIndicator(
                              strokeWidth: 3.5,
                              valueColor: AlwaysStoppedAnimation<Color>(_neonGreen),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _syncStatusText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Importing attendance percentages & internal test marks",
                            style: TextStyle(
                              color: _mutedText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Safety padding for virtual keyboard
          if (bottomInset > 0) SizedBox(height: bottomInset),
        ],
      ),
    );
  }
}
