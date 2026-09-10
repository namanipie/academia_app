import 'package:flutter/material.dart';

class StudentInfoCard extends StatelessWidget {
  final Map<String, dynamic> studentInfo;

  const StudentInfoCard({super.key, required this.studentInfo});

@override
Widget build(BuildContext context) {
  return Align( // Keeps card only as wide as content if needed
    alignment: Alignment.topLeft,
    child: IntrinsicHeight( // ✅ Ensures height wraps content
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color.fromARGB(255, 211, 213, 215).withValues(alpha:0.4),
              const Color.fromARGB(255, 170, 168, 169).withValues(alpha:0.2),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha:0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.15),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min, // ✅ Prevents Column from stretching
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    studentInfo["name"] ?? "N/A",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoRow(Icons.confirmation_number, "Reg No.", studentInfo["registration_number"]),
            _buildInfoRow(Icons.school, "Program", studentInfo["program"]),
            _buildInfoRow(Icons.code, "Specialization", studentInfo["specialization"]),
            _buildInfoRow(Icons.account_tree, "Department", studentInfo["department"]),
            _buildInfoRow(Icons.assessment, "Semester", studentInfo["semester"]),
            _buildInfoRow(Icons.verified, "Status",
              studentInfo["enrollment_status"] == "true" ? " Active" : "Inactive",
            ),
            _buildInfoRow(Icons.calendar_today, "Enrolled On", studentInfo["enrollment_date"]),
          ],
        ),
      ),
    ),
  );
}


  Widget _buildInfoRow(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Text(
            "$label:",
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value?.toString() ?? "N/A",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
