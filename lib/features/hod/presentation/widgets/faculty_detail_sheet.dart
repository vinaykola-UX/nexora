import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../models/hod_models.dart';

/// Modal bottom sheet displaying complete details for a faculty member
class FacultyDetailSheet extends StatelessWidget {
  final FacultyProfile faculty;

  const FacultyDetailSheet({
    Key? key,
    required this.faculty,
  }) : super(key: key);

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(NexoraColors.primaryDark),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Color(NexoraColors.surface),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(NexoraColors.border),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: NexoraSpacing.xl,
                vertical: NexoraSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Faculty Header Card
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: faculty.isHod
                              ? const Color(NexoraColors.primary)
                              : const Color(0xFF6366F1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            faculty.initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: NexoraSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              faculty.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(NexoraColors.text),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              faculty.designation,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(NexoraColors.textSecondary),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: faculty.status.backgroundColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    faculty.status.displayName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: faculty.status.color,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.star_rounded,
                                  color: Color(NexoraColors.warning),
                                  size: 16,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${faculty.rating} Student Rating',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(NexoraColors.text),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: NexoraSpacing.lg),

                  // Quick Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _copyToClipboard(
                            context,
                            faculty.email,
                            'Email address',
                          ),
                          icon: const Icon(Icons.email_outlined, size: 16),
                          label: const Text('Email'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(NexoraColors.text),
                            side: const BorderSide(color: Color(NexoraColors.border)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: NexoraSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _copyToClipboard(
                            context,
                            faculty.phone,
                            'Phone number',
                          ),
                          icon: const Icon(Icons.phone_outlined, size: 16),
                          label: const Text('Call / SMS'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(NexoraColors.text),
                            side: const BorderSide(color: Color(NexoraColors.border)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: NexoraSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _copyToClipboard(
                            context,
                            '${faculty.name} (${faculty.id})\n${faculty.email}\n${faculty.phone}\nCabin: ${faculty.cabin}',
                            'Faculty credentials',
                          ),
                          icon: const Icon(Icons.copy_outlined, size: 16),
                          label: const Text('Copy Info'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(NexoraColors.text),
                            side: const BorderSide(color: Color(NexoraColors.border)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: NexoraSpacing.xl),

                  // Section 1: Official Faculty Credentials
                  const Text(
                    'Faculty Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(NexoraColors.text),
                    ),
                  ),
                  const SizedBox(height: NexoraSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(NexoraSpacing.md),
                    decoration: BoxDecoration(
                      color: const Color(NexoraColors.inputBackground),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(NexoraColors.border).withOpacity(0.6),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow('Faculty ID', faculty.id),
                        const Divider(color: Color(NexoraColors.divider), height: 16),
                        _buildInfoRow('Department', faculty.department),
                        const Divider(color: Color(NexoraColors.divider), height: 16),
                        _buildInfoRow('Qualifications', faculty.qualification),
                        const Divider(color: Color(NexoraColors.divider), height: 16),
                        _buildInfoRow('Experience', '${faculty.experienceYears} Years'),
                        const Divider(color: Color(NexoraColors.divider), height: 16),
                        _buildInfoRow('Specialization', faculty.specialization),
                        const Divider(color: Color(NexoraColors.divider), height: 16),
                        _buildInfoRow('Cabin / Room', faculty.cabin),
                      ],
                    ),
                  ),

                  const SizedBox(height: NexoraSpacing.xl),

                  // Section 2: App & AI Knowledge Contribution
                  const Text(
                    'Nexora App & AI Integration',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(NexoraColors.text),
                    ),
                  ),
                  const SizedBox(height: NexoraSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(NexoraSpacing.lg),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4), // Light green tint
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFBBF7D0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.verified_outlined,
                              color: Color(0xFF16A34A),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Verified Faculty Contributor',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: NexoraSpacing.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildAppMetricTile(
                              '${faculty.totalMaterialsUploaded}',
                              'Notes Uploaded',
                              Icons.description_outlined,
                              const Color(0xFF16A34A),
                            ),
                            Container(width: 1, height: 36, color: const Color(0xFFBBF7D0)),
                            _buildAppMetricTile(
                              '${faculty.totalStudentViews}',
                              'Student Reads',
                              Icons.group_outlined,
                              const Color(0xFF2563EB),
                            ),
                            Container(width: 1, height: 36, color: const Color(0xFFBBF7D0)),
                            _buildAppMetricTile(
                              '100%',
                              'Anti-Spam Dedup',
                              Icons.security_outlined,
                              const Color(0xFF7C3AED),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: NexoraSpacing.xl),

                  // Section 3: Subjects & Syllabus Progress
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Assigned Subjects & Syllabus',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(NexoraColors.text),
                        ),
                      ),
                      Text(
                        '${faculty.subjects.length} Subjects',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(NexoraColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: NexoraSpacing.sm),

                  ...faculty.subjects.map((subject) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: NexoraSpacing.sm),
                      padding: const EdgeInsets.all(NexoraSpacing.md),
                      decoration: BoxDecoration(
                        color: const Color(NexoraColors.inputBackground),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(NexoraColors.border).withOpacity(0.6),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  subject.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(NexoraColors.text),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(NexoraColors.primaryLight).withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  subject.code,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(NexoraColors.primaryDark),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${subject.yearSemester} • ${subject.sections.join(', ')}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(NexoraColors.textSecondary),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Progress Bar
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: subject.completionPercentage,
                                    backgroundColor: const Color(NexoraColors.border),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      subject.completionPercentage >= 0.8
                                          ? const Color(0xFF16A34A)
                                          : const Color(NexoraColors.primary),
                                    ),
                                    minHeight: 6,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${subject.unitsCompleted}/${subject.totalUnits} Units',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(NexoraColors.text),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${subject.materialsUploaded} lecture note files uploaded to Nexora AI',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(NexoraColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),

                  const SizedBox(height: NexoraSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(NexoraColors.textSecondary),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(NexoraColors.text),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppMetricTile(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(NexoraColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

