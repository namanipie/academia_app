import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:academia_app/services/student_portal_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StudentPortalParser Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('parseAttendanceHtml parses standard SRM Student Portal attendance table', () {
      const html = '''
      <html>
        <body>
          <table border="1">
            <tr>
              <th>Course Code</th>
              <th>Course Title</th>
              <th>Category</th>
              <th>Faculty Name</th>
              <th>Slot</th>
              <th>Room No</th>
              <th>Hours Conducted</th>
              <th>Hours Absent</th>
              <th>Attendance %</th>
            </tr>
            <tr>
              <td>21CSC302J Regular</td>
              <td>Database Management Systems</td>
              <td>Theory</td>
              <td>Dr. Alan Smith</td>
              <td>A1</td>
              <td>UB601</td>
              <td>40</td>
              <td>4</td>
              <td>90.00</td>
            </tr>
            <tr>
              <td>21CSC303J Regular</td>
              <td>Web Technology</td>
              <td>Practical</td>
              <td>Dr. Jane Doe</td>
              <td>L1</td>
              <td>TP201</td>
              <td>30</td>
              <td>0</td>
              <td>100.00</td>
            </tr>
          </table>
        </body>
      </html>
      ''';

      final result = StudentPortalParser.parseAttendanceHtml(html);
      expect(result['overall_attendance'], 94.29);
      expect(result['total_hours_conducted'], 70);
      expect(result['total_hours_absent'], 4);

      final courses = result['courses'] as Map<String, dynamic>;
      expect(courses.containsKey('21CSC302JTheory'), isTrue);
      expect(courses['21CSC302JTheory']['course_title'], 'Database Management Systems');
      expect(courses['21CSC302JTheory']['hours_conducted'], 40);
      expect(courses['21CSC302JTheory']['hours_absent'], 4);
      expect(courses['21CSC302JTheory']['attendance_percentage'], 90.0);

      expect(courses.containsKey('21CSC303JPractical'), isTrue);
      expect(courses['21CSC303JPractical']['hours_conducted'], 30);
      expect(courses['21CSC303JPractical']['hours_absent'], 0);
      expect(courses['21CSC303JPractical']['attendance_percentage'], 100.0);
    });

    test('parseAttendanceHtml handles percentage calculation when missing', () {
      const html = '''
      <table>
        <tr>
          <td>Code</td>
          <td>Subject</td>
          <td>Type</td>
          <td>Conducted</td>
          <td>Absent</td>
          <td>%</td>
        </tr>
        <tr>
          <td>21MAT201T</td>
          <td>Calculus</td>
          <td>Theory</td>
          <td>50</td>
          <td>10</td>
          <td>0.00</td>
        </tr>
      </table>
      ''';

      final result = StudentPortalParser.parseAttendanceHtml(html);
      final courses = result['courses'] as Map<String, dynamic>;
      expect(courses['21MAT201TTheory']['attendance_percentage'], 80.0);
      expect(result['overall_attendance'], 80.0);
    });

    test('parseMarksHtml parses test names and marks', () {
      const html = '''
      <table>
        <tr>
          <td>Course Code</td>
          <td>Course Type</td>
          <td>Marks</td>
        </tr>
        <tr>
          <td>21CSC302J</td>
          <td>Theory</td>
          <td>
            <table>
              <tr>
                <td><strong>CLA-1/15.00</strong> 14.00</td>
                <td><strong>CLA-2/15.00</strong> 13.50</td>
                <td><strong>FT-I/5.00</strong> 4.50</td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
      ''';

      final marks = StudentPortalParser.parseMarksHtml(html);
      expect(marks.containsKey('21CSC302JTheory'), isTrue);

      final tests = marks['21CSC302JTheory']['tests'] as List;
      expect(tests.length, 3);
      expect(tests[0]['test_name'], 'CLA-1');
      expect(tests[0]['max_marks'], 15.0);
      expect(tests[0]['obtained_marks'], 14.0);
      expect(tests[0]['percentage'], 93.33);

      expect(tests[1]['test_name'], 'CLA-2');
      expect(tests[1]['obtained_marks'], 13.5);

      expect(tests[2]['test_name'], 'FT-I');
      expect(tests[2]['obtained_marks'], 4.5);
    });

    test('mergeStudentPortalDataIntoUserData updates SharedPreferences correctly', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userData', json.encode({
        'attendance': {
          'attendance_unavailable': true,
          'student_info': {'name': 'Test Student'},
        },
        'timetable': {
          'courses': [
            {'course_code': '21CSC302J', 'course_title': 'Full DBMS Title'}
          ]
        }
      }));

      final attendanceData = {
        'courses': {
          '21CSC302JTheory': {
            'course_code': '21CSC302J',
            'course_title': '21CSC302J',
            'category': 'Theory',
            'hours_conducted': 30,
            'hours_absent': 3,
            'attendance_percentage': 90.0,
          }
        },
        'overall_attendance': 90.0,
        'total_hours_conducted': 30,
        'total_hours_absent': 3,
      };

      final marksData = {
        '21CSC302JTheory': {
          'course_code': '21CSC302J',
          'course_type': 'Theory',
          'tests': [
            {'test_name': 'CLA-1', 'obtained_marks': 14.0, 'max_marks': 15.0, 'percentage': 93.33}
          ]
        }
      };

      final success = await StudentPortalParser.mergeStudentPortalDataIntoUserData(
        attendanceData: attendanceData,
        marksData: marksData,
      );

      expect(success, isTrue);

      final updatedRaw = prefs.getString('userData');
      expect(updatedRaw, isNotNull);

      final updated = json.decode(updatedRaw!) as Map<String, dynamic>;
      expect(updated['attendance']['attendance_unavailable'], isFalse);
      expect(updated['attendance']['attendance']['overall_attendance'], 90.0);

      // Verify course title was enhanced from timetable mapping
      final savedCourse = updated['attendance']['attendance']['courses']['21CSC302JTheory'];
      expect(savedCourse['course_title'], 'Full DBMS Title');

      // Verify marks were merged
      expect(updated['marks']['21CSC302JTheory']['tests'].length, 1);

      // Verify connection flag
      final connected = await StudentPortalParser.isStudentPortalConnected();
      expect(connected, isTrue);
    });
  });
}
