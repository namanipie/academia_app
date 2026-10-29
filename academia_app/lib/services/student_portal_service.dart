import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'student_portal_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/day_order_backup.dart';
import '../config/backend_config.dart';

class CaptchaSession {
  final Map<String, String> cookies;
  final String captchaToken;
  final Uint8List imageBytes;
  final String? nonce;
  final String? domainFieldName;
  final String? captchaFieldName;
  final String? randomDelimiter;
  final String? honeypotName;
  final DateTime fetchTime;

  CaptchaSession({
    required this.cookies,
    required this.captchaToken,
    required this.imageBytes,
    this.nonce,
    this.domainFieldName,
    this.captchaFieldName,
    this.randomDelimiter,
    this.honeypotName,
    DateTime? fetchTime,
  }) : fetchTime = fetchTime ?? DateTime.now();

  String get cookieHeader => cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
}

class PortalSyncResult {
  final bool success;
  final String? errorMessage;
  final int coursesCount;
  final int marksCount;

  PortalSyncResult({
    required this.success,
    this.errorMessage,
    this.coursesCount = 0,
    this.marksCount = 0,
  });
}

class StudentPortalService {
  static const String _baseUrl = 'https://sp.srmist.edu.in/srmiststudentportal';
  static const String _loginPageUrl = '$_baseUrl/students/loginManager/youLogin.jsp';
  static const String _loginActionUrl = '$_baseUrl/LoginServlet';
  static const String _dashboardUrl = '$_baseUrl/students/template/HRDSystem.jsp';

  static const Map<String, String> _defaultHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
    'Origin': 'https://sp.srmist.edu.in',
    'Referer': _loginPageUrl,
  };

  /// Helper to parse and track cookies from response headers
  static void _updateCookies(http.Response response, Map<String, String> cookies) {
    final rawSetCookie = response.headers['set-cookie'];
    if (rawSetCookie == null || rawSetCookie.isEmpty) return;

    // Set-cookie headers may contain multiple cookies separated by commas or newlines
    final parts = rawSetCookie.split(RegExp(r',(?=\s*[A-Za-z0-9_-]+=)'));
    for (final part in parts) {
      final cookiePair = part.split(';').first.trim();
      final eqIdx = cookiePair.indexOf('=');
      if (eqIdx != -1) {
        final key = cookiePair.substring(0, eqIdx).trim();
        final val = cookiePair.substring(eqIdx + 1).trim();
        if (key.isNotEmpty) {
          cookies[key] = val;
        }
      }
    }
  }

  /// Step 1: Fetch a new CAPTCHA image and initialize session
  static Future<CaptchaSession> fetchCaptcha() async {
    final client = http.Client();
    try {
      final Map<String, String> cookies = {};

      final getResp = await client.get(
        Uri.parse(_loginPageUrl),
        headers: _defaultHeaders,
      );
      _updateCookies(getResp, cookies);
      final body = getResp.body;

      // Extract captcha token
      final tokenMatch = RegExp(r'SCaptchaServlet\?ts=.*?token=([a-z0-9\-]+)', caseSensitive: false)
          .firstMatch(body);

      if (tokenMatch == null) {
        throw Exception('Could not extract CAPTCHA token from SRM portal.');
      }

      final captchaToken = tokenMatch.group(1)!;

      // Extract security parameters injected by SRM portal
      final nonceMatch = RegExp(r"nonce:\s*'([^']+)'").firstMatch(body);
      final nonce = nonceMatch?.group(1);

      final domainFieldMatch = RegExp(r"window\.SECURE_CONFIG\.domainFieldName\s*=\s*'([^']+)'").firstMatch(body);
      final domainFieldName = domainFieldMatch?.group(1);

      final captchaFieldMatch = RegExp(r"window\.SECURE_CONFIG\.captchaFieldName\s*=\s*'([^']+)'").firstMatch(body);
      final captchaFieldName = captchaFieldMatch?.group(1);

      final randomDelimMatch = RegExp(r"window\.SECURE_CONFIG\.randomDelimiter\s*=\s*'([^']+)'").firstMatch(body);
      final randomDelimiter = randomDelimMatch?.group(1);

      final honeypotMatch = RegExp(r'name="(ph_[a-z0-9]+)"').firstMatch(body);
      final honeypotName = honeypotMatch?.group(1);

      final ts = DateTime.now().millisecondsSinceEpoch;
      final captchaUrl = '$_baseUrl/SCaptchaServlet?ts=$ts&token=$captchaToken';

      final cookieStr = cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

      final Map<String, String> imgHeaders = {
        ..._defaultHeaders,
        'Accept': 'image/png, image/jpeg, image/svg+xml, image/*',
        if (cookieStr.isNotEmpty) 'Cookie': cookieStr,
      };

      if (nonce != null && nonce.isNotEmpty) {
        final proofStr = '$nonce:sp.srmist.edu.in';
        final proofBase64 = base64.encode(utf8.encode(proofStr));
        imgHeaders['X-Domain-Proof'] = proofBase64;
      }

      final imgResp = await client.get(
        Uri.parse(captchaUrl),
        headers: imgHeaders,
      );
      _updateCookies(imgResp, cookies);

      if (imgResp.statusCode != 200 || imgResp.bodyBytes.isEmpty) {
        throw Exception('Failed to load CAPTCHA image (Status ${imgResp.statusCode}).');
      }

      return CaptchaSession(
        cookies: cookies,
        captchaToken: captchaToken,
        imageBytes: imgResp.bodyBytes,
        nonce: nonce,
        domainFieldName: domainFieldName,
        captchaFieldName: captchaFieldName,
        randomDelimiter: randomDelimiter,
        honeypotName: honeypotName,
        fetchTime: DateTime.now(),
      );
    } finally {
      client.close();
    }
  }

  /// Step 2: Login with credentials & CAPTCHA, then fetch and save academic records
  static Future<PortalSyncResult> loginAndSync({
    required String username,
    required String password,
    required String captcha,
    required CaptchaSession session,
  }) async {
    final client = http.Client();
    try {
      final cookies = Map<String, String>.from(session.cookies);
      String cookieStr() => cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

      // NetID should be clean without @srmist.edu.in
      final cleanUsername = username.trim().replaceAll(RegExp(r'@srmist\.edu\.in$', caseSensitive: false), '').trim();

      // 1. Post Login Form
      final loginPayload = <String, String>{
        'username': cleanUsername,
        'password': password.trim(),
        'captcha': captcha.trim(), // Exact case-sensitive captcha
        'fpPayload': '',
        'fpToken': '',
        'recaptchaToken': '',
      };

      // Add honeypot field (must remain empty for human submission)
      if (session.honeypotName != null && session.honeypotName!.isNotEmpty) {
        loginPayload[session.honeypotName!] = '';
      }

      // Add dynamic domain field (btoa(reversed hostname))
      if (session.domainFieldName != null && session.domainFieldName!.isNotEmpty) {
        const reversedHost = 'ni.ude.tsimrs.ps'; // 'sp.srmist.edu.in' reversed
        loginPayload[session.domainFieldName!] = base64.encode(utf8.encode(reversedHost));
      }

      // Add dynamic captcha trap field (btoa(elapsedSeconds + delimiter + interactCount))
      if (session.captchaFieldName != null && session.captchaFieldName!.isNotEmpty) {
        int elapsed = DateTime.now().difference(session.fetchTime).inSeconds;
        if (elapsed < 3) elapsed = 3;
        final delim = session.randomDelimiter ?? '';
        final trapStr = '$elapsed${delim}12';
        loginPayload[session.captchaFieldName!] = base64.encode(utf8.encode(trapStr));
      }

      final postResp = await client.post(
        Uri.parse(_loginActionUrl),
        headers: {
          ..._defaultHeaders,
          'Content-Type': 'application/x-www-form-urlencoded',
          if (cookieStr().isNotEmpty) 'Cookie': cookieStr(),
        },
        body: loginPayload,
      );
      _updateCookies(postResp, cookies);

      final respBody = postResp.body;
      final lowerResp = respBody.toLowerCase();

      // Extract specific portal alert message if present
      String? portalAlertMessage;
      try {
        final loginDoc = html_parser.parse(respBody);
        final alertElement = loginDoc.querySelector('.alert.alert-danger, .alert-danger');
        if (alertElement != null) {
          portalAlertMessage = alertElement.text.replaceAll('Alert', '').trim();
        }
      } catch (_) {}

      if (kDebugMode) {
        debugPrint('[PORTAL AUTH] Post status: ${postResp.statusCode}, alert: $portalAlertMessage');
      }

      if (respBody.contains('Invalid Captcha') || lowerResp.contains('invalid captcha')) {
        return PortalSyncResult(
          success: false,
          errorMessage: portalAlertMessage ?? 'Invalid CAPTCHA. CAPTCHA is case-sensitive.',
        );
      }

      if (lowerResp.contains('invalid credentials') || lowerResp.contains('check your user id / password')) {
        return PortalSyncResult(
          success: false,
          errorMessage: portalAlertMessage ?? 'Invalid credentials. Please verify your NetID & password.',
        );
      }

      if (portalAlertMessage != null && portalAlertMessage.isNotEmpty) {
        return PortalSyncResult(
          success: false,
          errorMessage: portalAlertMessage,
        );
      }

      // 2. Load Dashboard to verify authenticated session and retrieve CSRF Salt
      final dashResp = await client.get(
        Uri.parse(_dashboardUrl),
        headers: {
          ..._defaultHeaders,
          if (cookieStr().isNotEmpty) 'Cookie': cookieStr(),
        },
      );
      _updateCookies(dashResp, cookies);

      final dashBody = dashResp.body;
      if (!dashBody.toLowerCase().contains('logout') && !dashBody.toLowerCase().contains('welcome')) {
        // Session not authenticated - extract dashboard alert or report failure
        String? dashAlert;
        try {
          final dashDoc = html_parser.parse(dashBody);
          final alertElement = dashDoc.querySelector('.alert.alert-danger, .alert-danger');
          if (alertElement != null) {
            dashAlert = alertElement.text.replaceAll('Alert', '').trim();
          }
        } catch (_) {}

        return PortalSyncResult(
          success: false,
          errorMessage: dashAlert ?? portalAlertMessage ?? 'Authentication failed. Please verify your NetID, password, and CAPTCHA.',
        );
      }

      // 3. Extract CSRF salt and hdnFormDetails from Dashboard using HTML parser
      final dashDoc = html_parser.parse(dashBody);
      final csrfElement = dashDoc.querySelector('#csrfPreventionSalt');
      final csrf = csrfElement?.attributes['value'] ?? '';

      final hdnElement = dashDoc.querySelector('#hdnFormDetails');
      final hdnForm = hdnElement?.attributes['value'] ?? '1';

      // 4. Fetch Attendance and Marks in parallel
      Future<String> fetchEndpoint(String endpointUrl, String iden) async {
        try {
          final res = await client.post(
            Uri.parse(endpointUrl),
            headers: {
              ..._defaultHeaders,
              'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
              'X-Requested-With': 'XMLHttpRequest',
              'Referer': _dashboardUrl,
              if (cookieStr().isNotEmpty) 'Cookie': cookieStr(),
            },
            body: {
              'filter': '',
              'hdnFormDetails': hdnForm,
              'csrfPreventionSalt': csrf,
              'iden': iden,
            },
          );
          _updateCookies(res, cookies);
          return res.body;
        } catch (e) {
          if (kDebugMode) debugPrint('[PORTAL SERVICE] Failed to fetch $endpointUrl: $e');
          return '';
        }
      }

      final endpointsFuture = await Future.wait([
        fetchEndpoint('$_baseUrl/students/report/studentAttendanceDetails.jsp', '9'),
        fetchEndpoint('$_baseUrl/students/report/studentInternalMarkDetails.jsp', '13'),
        fetchEndpoint('$_baseUrl/students/report/studentMarksCredits.jsp', '8'),
        fetchEndpoint('$_baseUrl/students/transaction/onlineResult.jsp', '24'),
        fetchEndpoint('$_baseUrl/students/report/studentProfile.jsp', '1'),
      ]);

      final attendanceHtml = endpointsFuture[0];
      final marksHtml = endpointsFuture[1];
      final gradesHtml = endpointsFuture[2];
      final resultsHtml = endpointsFuture[3];
      final profileHtml = endpointsFuture[4];

      // 5. Parse Data
      final parsedAttendance = StudentPortalParser.parseAttendanceHtml(attendanceHtml);
      final parsedMarks = StudentPortalParser.parseMarksHtml(marksHtml);

      // 6. Save & Merge into SharedPreferences
      await StudentPortalParser.mergeStudentPortalDataIntoUserData(
        attendanceData: parsedAttendance,
        marksData: parsedMarks,
        rawPortalResult: {
          'status': 'success',
          'attendanceHtml': attendanceHtml,
          'marksHtml': marksHtml,
          'gradesHtml': gradesHtml,
          'resultsHtml': resultsHtml,
          'profileHtml': profileHtml,
        },
      );

      final coursesCount = (parsedAttendance['courses'] as Map?)?.length ?? 0;
      final marksCount = parsedMarks.length;

      return PortalSyncResult(
        success: true,
        coursesCount: coursesCount,
        marksCount: marksCount,
      );
    } catch (e, stack) {
      if (kDebugMode) debugPrint('[PORTAL SERVICE] Login error: $e\n$stack');
      return PortalSyncResult(
        success: false,
        errorMessage: 'Connection error: ${e.toString().replaceAll('Exception:', '').trim()}',
      );
    } finally {
      client.close();
    }
  }

  /// Sync attendance and marks directly via our first-party backend (zero-CAPTCHA native scraper)
  static Future<PortalSyncResult> syncViaGateway({
    required String username,
    required String password,
  }) async {
    try {
      final cleanUsername = username.trim().replaceAll(RegExp(r'@srmist\.edu\.in$', caseSensitive: false), '').trim();

      final response = await BackendConfig.postWithFallback(
        '/studentportal_result',
        body: {
          'netid': cleanUsername,
          'password': password.trim(),
        },
        perAttemptTimeout: const Duration(seconds: 20),
      );

      if (response.statusCode != 200) {
        String msg = 'Student Portal sync failed (HTTP ${response.statusCode})';
        try {
          final errBody = jsonDecode(response.body);
          msg = errBody['detail'] ?? errBody['message'] ?? msg;
        } catch (_) {}
        return PortalSyncResult(
          success: false,
          errorMessage: msg,
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'success') {
        return PortalSyncResult(
          success: false,
          errorMessage: data['message'] ?? 'Failed to retrieve portal data',
        );
      }

      final attendanceData = (data['attendance'] as Map<String, dynamic>?) ?? {};
      final marksData = (data['marks'] as Map<String, dynamic>?) ?? {};
      final coursesMap = (attendanceData['courses'] as Map<String, dynamic>?) ?? {};

      // Merge into SharedPreferences
      await StudentPortalParser.mergeStudentPortalDataIntoUserData(
        attendanceData: attendanceData,
        marksData: marksData,
      );

      return PortalSyncResult(
        success: true,
        coursesCount: coursesMap.length,
        marksCount: marksData.length,
      );
    } catch (e, stack) {
      if (kDebugMode) debugPrint('[PORTAL SYNC] Error: $e\n$stack');
      return PortalSyncResult(
        success: false,
        errorMessage: 'Connection error: ${e.toString().replaceAll("Exception:", "").trim()}',
      );
    }
  }

  /// Direct login & full userData compilation using our native backend
  static Future<Map<String, dynamic>?> loginAndBuildFullUserData({
    required String username,
    required String password,
  }) async {
    try {
      final cleanUsername = username.trim().replaceAll(RegExp(r'@srmist\.edu\.in$', caseSensitive: false), '').trim();

      final response = await BackendConfig.postWithFallback(
        '/studentportal_result',
        body: {
          'netid': cleanUsername,
          'password': password.trim(),
        },
        perAttemptTimeout: const Duration(seconds: 20),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'success') {
        return null;
      }

      final rawStudentInfo = (data['student_info'] as Map<String, dynamic>?) ?? {};
            // Preserve existing student info from local storage (if available)
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> existingStudentInfo = {};
      int? existingDayOrder;
      final rawUserData = prefs.getString('userData');
      if (rawUserData != null && rawUserData.isNotEmpty) {
        try {
          final decoded = json.decode(rawUserData) as Map<String, dynamic>;
          if (decoded['student_info'] is Map<String, dynamic>) {
            existingStudentInfo = decoded['student_info'] as Map<String, dynamic>;
          }
          existingDayOrder = decoded['attendance']?['day_order'] as int?;
        } catch (_) {}
      }

      int? resolvedDayOrder = existingDayOrder;
      if (resolvedDayOrder == null) {
        try {
          resolvedDayOrder = await DayOrderManager.getDayOrderForDate(DateTime.now());
        } catch (_) {}
      }

      final studentInfo = {
        'name': rawStudentInfo['name'] ?? existingStudentInfo['name'] ?? cleanUsername,
        'reg_no': rawStudentInfo['reg_no'] ?? existingStudentInfo['reg_no'] ?? cleanUsername,
        'department': existingStudentInfo['department'] ?? '',
        'program': existingStudentInfo['program'] ?? '',
        'semester': existingStudentInfo['semester'] ?? '',
        'classroom': existingStudentInfo['classroom'] ?? '',
        'photo': rawStudentInfo['photo_url'] ?? existingStudentInfo['photo'] ?? '',
      };

      final attendanceData = (data['attendance'] as Map<String, dynamic>?) ?? {};
      final marksData = (data['marks'] as Map<String, dynamic>?) ?? {};
      final coursesMap = (attendanceData['courses'] as Map<String, dynamic>?) ?? {};

      final List<Map<String, dynamic>> ttCoursesList = [];
      coursesMap.forEach((key, val) {
        if (val is Map) {
          final cCode = val['course_code']?.toString() ?? '';
          final cTitle = val['course_title']?.toString() ?? '';
          final cType = val['course_type']?.toString() ?? 'Theory';
          ttCoursesList.add({
            'course_code': cCode,
            'course_title': cTitle,
            'course_type': cType,
            'category': 'General',
            'credit': cCode.contains('J') ? 4 : (cCode.contains('P') ? 2 : 3),
          });
        }
      });

      return {
        'status': 'success',
        'netid': cleanUsername,
        'student_info': studentInfo,
        'attendance': {
          'attendance': attendanceData,
          'student_info': studentInfo,
          if (resolvedDayOrder != null) 'day_order': resolvedDayOrder,
          'attendance_unavailable': false,
          'marks': marksData,
        },
        'marks': marksData,
        'timetable': {
          'courses': ttCoursesList,
          'student_info': studentInfo,
        },
      };
    } catch (e) {
      if (kDebugMode) debugPrint('[PORTAL FULL LOGIN] Error: $e');
      return null;
    }
  }
}
