import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../models/hod_models.dart';

/// Card displaying faculty profile summary in the HOD monitor list
class FacultyCard extends StatelessWidget {
  final FacultyProfile faculty;
  final VoidCallback onTap;

  const FacultyCard({
    Key? key,
    required this.faculty,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: NexoraSpacing.md),
      decoration: BoxDecoration(
        color: const Color(NexoraColors.surface),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: faculty.isHod
              ? const Color(NexoraColors.primary).withOpacity(0.6)
              : const Color(NexoraColors.border).withOpacity(0.8),
          width: faculty.isHod ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(NexoraSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Avatar, Info, Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar Initials
                    Stack(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: faculty.isHod
                                ? const Color(NexoraColors.primary)
                                : const Color(0xFF6366F1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              faculty.initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        // Status Indicator Dot
                        Positioned(
                          right: -1,
                          bottom: -1,
                          child: Container(
                            width: 15,
                            height: 15,
                            decoration: BoxDecoration(
                              color: faculty.status.color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(NexoraColors.surface),
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: NexoraSpacing.md),

                    // Name, Designation & Badges
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  faculty.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(NexoraColors.text),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (faculty.isHod) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(NexoraColors.primaryLight).withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(NexoraColors.primary),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Text(
                                    'HOD',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(NexoraColors.primaryDark),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            faculty.designation,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(NexoraColors.textSecondary),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 13,
                                color: Color(NexoraColors.textMuted),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  faculty.cabin,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(NexoraColors.textMuted),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: faculty.status.backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        faculty.status.displayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: faculty.status.color,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: NexoraSpacing.md),

                // Subjects Tag Chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: faculty.subjects.map((sub) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(NexoraColors.inputBackground),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(NexoraColors.border).withOpacity(0.6),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.menu_book,
                            size: 11,
                            color: Color(NexoraColors.textSecondary),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            sub.name,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(NexoraColors.text),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: NexoraSpacing.md),
                const Divider(color: Color(NexoraColors.divider), height: 1),
                const SizedBox(height: NexoraSpacing.sm),

                // Bottom Metrics Row: App Materials, Views, Syllabus Progress
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Study Materials Uploaded
                    Row(
                      children: [
                        const Icon(
                          Icons.cloud_upload_outlined,
                          size: 14,
                          color: Color(0xFF2E7D32),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${faculty.totalMaterialsUploaded} Notes',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(NexoraColors.text),
                          ),
                        ),
                      ],
                    ),

                    // Student Views
                    Row(
                      children: [
                        const Icon(
                          Icons.visibility_outlined,
                          size: 14,
                          color: Color(0xFF1976D2),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${faculty.totalStudentViews} Reads',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(NexoraColors.text),
                          ),
                        ),
                      ],
                    ),

                    // Syllabus Coverage Percentage
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 14,
                          color: Color(NexoraColors.primaryDark),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${(faculty.averageSyllabusCoverage * 100).toInt()}% Covered',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(NexoraColors.primaryDark),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

