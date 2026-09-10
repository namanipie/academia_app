import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import 'package:flutter/foundation.dart';

class SrmNativeClient {
  final http.Client _client = http.Client();
  String? _cookies;

  String _mergeCookies(String? currentCookies, String? setCookieHeader) {
    if (setCookieHeader == null) return currentCookies ?? '';
    final Map<String, String> cookieMap = {};

    void parseString(String str, String separator) {
      for (final part in str.split(separator)) {
        final pair = part.split(';').first.trim();
        final idx = pair.indexOf('=');
        if (idx > 0) cookieMap[pair.substring(0, idx)] = pair;
      }
    }

    if (currentCookies != null && currentCookies.isNotEmpty) {
      parseString(currentCookies, ';');
    }
    // Handle both comma-separated (raw set-cookie) and semicolon-separated (merged) inputs
    if (setCookieHeader.contains('; ') && !setCookieHeader.contains(',')) {
      parseString(setCookieHeader, ';');
    } else {
      parseString(setCookieHeader, ',');
    }

    return cookieMap.values.join('; ');
  }

  Future<Map<String, String>> _getSigninSessionHeaders() async {
    final url = Uri.parse(
      'https://academia.srmist.edu.in/accounts/p/40-10002227248/signin?hide_fp=true&servicename=ZohoCreator&service_language=en&dcc=true&serviceurl=https%3A%2F%2Facademia.srmist.edu.in%2Fportal%2Facademia-academic-services%2FredirectFromLogin',
    );
    final req = http.Request('GET', url)..followRedirects = false;
    req.headers['accept'] =
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';
    req.headers['accept-language'] = 'en-US,en;q=0.9';
    final res = await _client.send(req);
    await res.stream.drain();

    if (kDebugMode)
      debugPrint(
        "[SRM AUTH] Step 1 redirect: ${(res.statusCode >= 300 && res.statusCode < 400)}",
      );

    final setCookie = res.headers['set-cookie'];
    if (kDebugMode)
      debugPrint("[SRM AUTH] RAW Set-Cookie from Step 1: $setCookie");

    final cookie = _mergeCookies(null, setCookie);
    if (kDebugMode) debugPrint("[SRM AUTH] Parsed Cookie for Step 2: $cookie");

    String? csrfToken;
    for (final pair in cookie.split(';')) {
      final p = pair.trim();
      if (p.startsWith('iamcsr=')) csrfToken = p.substring('iamcsr='.length);
      if (csrfToken == null && p.startsWith('_zcsr_tmp='))
        csrfToken = p.substring('_zcsr_tmp='.length);
    }

    if (kDebugMode)
      debugPrint(
        "[SRM AUTH] CSRF/session seed detected: ${csrfToken != null && csrfToken.isNotEmpty}",
      );

    return {'cookie': cookie, 'csrfToken': csrfToken ?? ''};
  }

  Future<Map<String, dynamic>> _validateUser(String username) async {
    final seed = await _getSigninSessionHeaders();
    final cookie = seed['cookie'] ?? '';
    final csrfToken = seed['csrfToken'] ?? '';

    if (kDebugMode) debugPrint("[SRM AUTH] Step 2 request started");

    final url = Uri.parse(
      'https://academia.srmist.edu.in/accounts/p/40-10002227248/signin/v2/lookup/${Uri.encodeComponent(username)}',
    );
    final req = http.Request('POST', url)..followRedirects = false;
    req.headers['accept'] = '*/*';
    req.headers['content-type'] =
        'application/x-www-form-urlencoded;charset=UTF-8';
    if (csrfToken.isNotEmpty)
      req.headers['x-zcsrf-token'] = 'iamcsrcoo=$csrfToken';
    if (cookie.isNotEmpty) req.headers['cookie'] = cookie;
    req.headers['Referer'] =
        'https://academia.srmist.edu.in/accounts/p/40-10002227248/signin?hide_fp=true&servicename=ZohoCreator&service_language=en&dcc=true&serviceurl=https%3A%2F%2Facademia.srmist.edu.in%2Fportal%2Facademia-academic-services%2FredirectFromLogin';
    req.body =
        'mode=primary&cli_time=${DateTime.now().millisecondsSinceEpoch}&servicename=ZohoCreator&service_language=en&serviceurl=https%3A%2F%2Facademia.srmist.edu.in%2Fportal%2Facademia-academic-services%2FredirectFromLogin';

    final res = await _client.send(req);
    final resBody = await res.stream.bytesToString();

    if (kDebugMode) {
      debugPrint("[SRM AUTH] Step 2 status: ${res.statusCode}");
      debugPrint(
        "[SRM AUTH] Step 2 Content-Type: ${res.headers['content-type']}",
      );
      debugPrint(
        "[SRM AUTH] Step 2 Content-Length: ${res.headers['content-length']}",
      );
      debugPrint("[SRM AUTH] Step 2 Final URL: ${url.path}");
      debugPrint("[SRM AUTH] Step 2 Response Body: $resBody");
    }

    if (res.statusCode == 200 || res.statusCode == 201) {
      final data = jsonDecode(resBody);
      final hasIdentifier = data['lookup']?['identifier'] != null;
      final hasDigest = data['lookup']?['digest'] != null;

      if (kDebugMode)
        debugPrint("[SRM AUTH] Identifier received: $hasIdentifier");
      if (kDebugMode) debugPrint("[SRM AUTH] Digest received: $hasDigest");

      return {
        'success': true,
        'identifier': data['lookup']?['identifier'],
        'digest': data['lookup']?['digest'],
        'cookie': _mergeCookies(cookie, res.headers['set-cookie']),
      };
    }

    if (kDebugMode)
      debugPrint("[SRM AUTH] Step 2 FAILURE TYPE: HTTP ${res.statusCode}");
    return {'success': false, 'error': 'User lookup failed: ${res.statusCode}'};
  }

  Future<bool> _terminateSessions(
    String sessionCookie,
    String csrfToken,
  ) async {
    if (kDebugMode)
      debugPrint("[SRM AUTH] Attempting to terminate sessions (435 recovery)");
    final url = Uri.parse(
      'https://academia.srmist.edu.in/accounts/p/40-10002227248/webclient/v1/announcement/pre/blocksessions',
    );
    final req = http.Request('DELETE', url)..followRedirects = false;
    req.headers['accept'] = 'application/json, text/javascript, */*; q=0.01';
    req.headers['content-type'] =
        'application/x-www-form-urlencoded;charset=UTF-8';
    if (csrfToken.isNotEmpty)
      req.headers['X-ZCSRF-TOKEN'] =
          'iamcsrcoo=${Uri.encodeComponent(csrfToken)}';
    if (sessionCookie.isNotEmpty) req.headers['cookie'] = sessionCookie;
    req.headers['Referer'] =
        'https://academia.srmist.edu.in/accounts/p/40-10002227248/preannouncement/block-sessions';
    final res = await _client.send(req);
    await res.stream.drain();
    if (kDebugMode)
      debugPrint("[SRM AUTH] Session termination status: ${res.statusCode}");
    return (res.statusCode >= 200 && res.statusCode < 300);
  }

  Future<Map<String, dynamic>> _validatePassword(
    String identifier,
    String digest,
    String password,
    String cookie,
  ) async {
    String csrfToken = '';
    for (final pair in cookie.split(';')) {
      final p = pair.trim();
      if (p.startsWith('iamcsr=')) csrfToken = p.substring('iamcsr='.length);
      if (csrfToken.isEmpty && p.startsWith('_zcsr_tmp='))
        csrfToken = p.substring('_zcsr_tmp='.length);
    }

    if (kDebugMode) debugPrint("[SRM AUTH] Step 3 request started");

    final url = Uri.parse(
      'https://academia.srmist.edu.in/accounts/p/40-10002227248/signin/v2/primary/$identifier/password?digest=$digest&cli_time=${DateTime.now().millisecondsSinceEpoch}&servicename=ZohoCreator&service_language=en&serviceurl=https%3A%2F%2Facademia.srmist.edu.in%2Fportal%2Facademia-academic-services%2FredirectFromLogin',
    );
    final req = http.Request('POST', url)..followRedirects = false;
    req.headers['accept'] = '*/*';
    req.headers['content-type'] =
        'application/x-www-form-urlencoded;charset=UTF-8';
    if (csrfToken.isNotEmpty)
      req.headers['x-zcsrf-token'] = 'iamcsrcoo=$csrfToken';
    if (cookie.isNotEmpty) req.headers['cookie'] = cookie;
    req.headers['Referer'] =
        'https://academia.srmist.edu.in/accounts/p/40-10002227248/signin?hide_fp=true&servicename=ZohoCreator&service_language=en&dcc=true&serviceurl=https%3A%2F%2Facademia.srmist.edu.in%2Fportal%2Facademia-academic-services%2FredirectFromLogin';
    req.body = jsonEncode({
      "passwordauth": {"password": password},
    });

    if (kDebugMode) debugPrint("[SRM AUTH] Step 3 request body: ${req.body}");

    final res = await _client.send(req);
    final resBody = await res.stream.bytesToString();

    if (kDebugMode) {
      debugPrint("[SRM AUTH] Step 3 status: ${res.statusCode}");
      debugPrint(
        "[SRM AUTH] Step 3 Content-Type: ${res.headers['content-type']}",
      );
      debugPrint(
        "[SRM AUTH] Step 3 Content-Length: ${res.headers['content-length']}",
      );
      debugPrint("[SRM AUTH] Step 3 Final URL: ${url.path}");
      debugPrint("[SRM AUTH] Step 3 Response Body: $resBody");
    }

    final newCookie = _mergeCookies(cookie, res.headers['set-cookie']);
    final location = res.headers['location'] ?? '';

    if ((res.statusCode == 301 ||
            res.statusCode == 302 ||
            res.statusCode == 303 ||
            res.statusCode == 307 ||
            res.statusCode == 308) &&
        location.contains('sessions-reminder')) {
      if (kDebugMode)
        debugPrint(
          "[SRM AUTH] Step 3 redirect detected (435 session reminder)",
        );
      return {
        'success': false,
        'status': 435,
        'cookie': newCookie,
        'csrfToken': csrfToken,
      };
    }

    if (res.statusCode == 200 || res.statusCode == 201) {
      try {
        final data = jsonDecode(resBody);
        if (data['status_code'] == 435 || data['status_code'] == '435') {
          if (kDebugMode)
            debugPrint(
              "[SRM AUTH] Step 3 FAILURE TYPE: HTTP 435 (sessions full)",
            );
          return {
            'success': false,
            'status': 435,
            'cookie': newCookie,
            'csrfToken': csrfToken,
          };
        }
        if (kDebugMode)
          debugPrint("[SRM AUTH] Authentication success detected: true");
        return {'success': true, 'cookie': newCookie};
      } catch (e) {
        if (kDebugMode)
          debugPrint("[SRM AUTH] Step 3 FAILURE TYPE: parser/JSON error");
      }
    }

    if (kDebugMode)
      debugPrint(
        "[SRM AUTH] Step 3 FAILURE TYPE: HTTP ${res.statusCode} ${res.headers['location'] ?? ''}",
      );
    if (kDebugMode)
      debugPrint("[SRM AUTH] Authentication success detected: false");
    return {
      'success': false,
      'error': 'Password validation failed: ${res.statusCode}',
    };
  }

  Future<bool> login(String email, String password) async {
    try {
      if (kDebugMode) debugPrint("[SRM AUTH] Starting login");
      final userRes = await _validateUser(email);
      if (userRes['success'] != true) return false;

      final identifier = userRes['identifier'];
      final digest = userRes['digest'];
      final cookie = userRes['cookie'];

      var passRes = await _validatePassword(
        identifier,
        digest,
        password,
        cookie,
      );
      if (passRes['success'] == false && passRes['status'] == 435) {
        final termRes = await _terminateSessions(
          passRes['cookie'],
          passRes['csrfToken'],
        );
        if (termRes) {
          if (kDebugMode)
            debugPrint(
              "[SRM AUTH] Retrying after session termination (restarting flow)",
            );
          final retryUserRes = await _validateUser(email);
          if (retryUserRes['success'] != true) return false;
          passRes = await _validatePassword(
            retryUserRes['identifier'],
            retryUserRes['digest'],
            password,
            retryUserRes['cookie'],
          );
        } else {
          if (kDebugMode) debugPrint("[SRM AUTH] Session termination failed");
          return false;
        }
      }
      if (passRes['success'] == true) {
        _cookies = passRes['cookie'];
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode)
        debugPrint("[SRM AUTH] Native login failed (Exception): $e");
      return false;
    }
  }

  String? _decodePageSanitizer(String response) {
    final match = RegExp(
      r"pageSanitizer\.sanitize\s*\(\s*'(.*?)'\s*\)",
      dotAll: true,
    ).firstMatch(response);
    if (match == null || match.groupCount < 1) return null;
    String decoded = match.group(1)!;
    decoded = decoded.replaceAllMapped(
      RegExp(r'\\x([0-9A-Fa-f]{2})'),
      (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
    );
    decoded = decoded.replaceAll(r'\\', '');
    decoded = decoded.replaceAll(r"\'", "'");
    return decoded;
  }

  Future<String?> _fetchPage(String url) async {
    if (_cookies == null) return null;
    final req = http.Request('GET', Uri.parse(url))..followRedirects = false;
    req.headers['accept'] = '*/*';
    req.headers['cookie'] = _cookies!;
    req.headers['x-requested-with'] = 'XMLHttpRequest';
    req.headers['Referer'] = 'https://academia.srmist.edu.in/';
    final res = await _client.send(req);
    final resBody = await res.stream.bytesToString();
    if (res.statusCode == 200) return resBody;
    return null;
  }

  Future<Map<String, dynamic>> fetchAllData() async {
    final rawHtml = await _fetchPage(
      'https://academia.srmist.edu.in/srm_university/academia-academic-services/page/My_Attendance',
    );
    if (rawHtml == null) return {};

    final decodedHtml = _decodePageSanitizer(rawHtml);
    if (decodedHtml == null) return {};
    final document = html_parser.parse(decodedHtml);

    // Parse Student Info
    final text = document.body?.text.replaceAll(RegExp(r'\s+'), ' ') ?? '';
    final regMatch = RegExp(
      r'Registration Number\s*:\s*([A-Za-z0-9]+)',
      caseSensitive: false,
    ).firstMatch(text);
    final nameMatch = RegExp(
      r'Name\s*:\s*([a-zA-Z\s]+?)(?:Program|Department|$)',
      caseSensitive: false,
    ).firstMatch(text);
    final progMatch = RegExp(
      r'Program\s*:\s*([a-zA-Z\.\s]+?)(?:Department|$)',
      caseSensitive: false,
    ).firstMatch(text);
    final semMatch = RegExp(
      r'Semester\s*:\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(text);

    final studentInfo = {
      'name': nameMatch?.group(1)?.trim() ?? '',
      'registration_number': regMatch?.group(1)?.trim() ?? '',
      'program': progMatch?.group(1)?.trim() ?? '',
      'semester': semMatch?.group(1)?.trim() ?? '',
    };

    // Parse Day Order
    int dayOrder = 0;
    final fonts = document.querySelectorAll("font, span, strong, td");
    for (final font in fonts) {
      final t = font.text.trim();
      if (t.startsWith("Day Order:")) {
        final dStr = t.replaceAll("Day Order:", "").trim();
        dayOrder = int.tryParse(dStr) ?? 0;
        break;
      }
    }

    // Parse Attendance
    Map<String, dynamic> coursesMap = {};
    double overallAttendance = 0.0;

    html_dom.Element? attTable;
    final tables = document.querySelectorAll('table');
    for (final table in tables) {
      final headerText = table.querySelector('tr')?.text.toLowerCase() ?? '';
      if (headerText.contains('course code') &&
          headerText.contains('conducted') &&
          headerText.contains('absent')) {
        attTable = table;
        break;
      }
    }

    if (attTable != null) {
      final rows = attTable.querySelectorAll('tr').skip(1);
      int totalConducted = 0;
      int totalAbsent = 0;
      for (final row in rows) {
        final cols = row.querySelectorAll('td');
        if (cols.length >= 8) {
          final code = cols[0].text.trim();
          if (code.isEmpty) continue;
          final title = cols[1].text.trim();
          final category = cols[2].text.trim();
          final faculty = cols[3].text.split('(').first.trim();
          final conducted = int.tryParse(cols[6].text.trim()) ?? 0;
          final absent = int.tryParse(cols[7].text.trim()) ?? 0;

          double percentage = 0.0;
          if (conducted > 0) {
            percentage = ((conducted - absent) / conducted) * 100;
          }

          coursesMap[code] = {
            'course_title': title,
            'category': category,
            'faculty_name': faculty,
            'hours_conducted': conducted,
            'hours_absent': absent,
            'attendance_percentage': double.parse(
              percentage.toStringAsFixed(2),
            ),
          };

          totalConducted += conducted;
          totalAbsent += absent;
        }
      }
      if (totalConducted > 0) {
        overallAttendance = double.parse(
          (((totalConducted - totalAbsent) / totalConducted) * 100)
              .toStringAsFixed(2),
        );
      }
    }

    // Parse Marks
    List<dynamic> internalMarks = [
      ["Course Code", "Course Title", "Total"],
    ];

    html_dom.Element? marksTable;
    for (final table in tables) {
      if (table.querySelectorAll('td table').isNotEmpty) {
        final strongText = table.querySelector('td strong')?.text ?? '';
        if (strongText.contains('/')) {
          marksTable = table;
          break;
        }
      }
    }

    if (marksTable != null) {
      final rows = marksTable.querySelectorAll('tr').skip(1);
      for (final row in rows) {
        final cols = row.querySelectorAll('td');
        if (cols.length >= 3) {
          final course = cols[0].text.trim();
          final category = cols[1].text.trim();
          final innerTable = cols[2].querySelector('table');
          if (course.isEmpty || category.isEmpty || innerTable == null)
            continue;

          double totalObtained = 0.0;
          final innerTds = innerTable.querySelectorAll('td');
          for (final markTd in innerTds) {
            final strongText =
                markTd.querySelector('strong')?.text.trim() ?? '';
            if (strongText.contains('/')) {
              final valStr = markTd.text.replaceAll(strongText, '').trim();
              final val = double.tryParse(valStr) ?? 0.0;
              totalObtained += val;
            }
          }

          internalMarks.add([course, course, totalObtained.toStringAsFixed(2)]);
        }
      }
    }

    // Parse Timetable (try a few common URLs)
    List<dynamic> timetableCourses = [];
    final ysList = ['2026_27', '2025_26', '2024_25', '2023_24', '2022_23'];
    for (final ys in ysList) {
      final ttHtml = await _fetchPage(
        'https://academia.srmist.edu.in/srm_university/academia-academic-services/page/My_Time_Table_$ys',
      );
      if (ttHtml != null) {
        final decTt = _decodePageSanitizer(ttHtml);
        if (decTt != null) {
          final docTt = html_parser.parse(decTt);
          final tbls = docTt.querySelectorAll('table.course_tbl');
          if (tbls.isNotEmpty) {
            final ttRows = tbls.first.querySelectorAll('tr').skip(1);
            for (final row in ttRows) {
              final cols = row.querySelectorAll('td');
              if (cols.length >= 11) {
                timetableCourses.add({
                  'course_code': cols[1].text.trim(),
                  'course_title': cols[2].text.trim(),
                  'credit': int.tryParse(cols[3].text.trim()) ?? 0,
                  'category': cols[5].text.trim(),
                  'faculty_name': cols[7].text.trim(),
                  'slot': cols[8].text.trim(),
                  'room_no': cols[10].text.trim(),
                });
              }
            }
            break; // found it, stop probing
          }
        }
      }
    }

    return {
      'attendance': {
        'student_info': studentInfo,
        'day_order': dayOrder,
        'attendance': {
          'overall_attendance': overallAttendance,
          'courses': coursesMap,
        },
      },
      'timetable': {'courses': timetableCourses},
      'marks': {
        'internal_marks': [internalMarks],
        'raw_tables':
            [], // We don't have end-sem marks natively via My_Attendance
        'semester_results': [],
        'attendance_details': [],
      },
    };
  }
}
