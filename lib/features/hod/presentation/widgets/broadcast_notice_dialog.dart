import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../models/hod_models.dart';

/// Dialog enabling HOD to broadcast department announcements
class BroadcastNoticeDialog extends StatefulWidget {
  final String departmentCode;
  final Function(String title, String description, NoticePriority priority, String targetAudience) onBroadcast;

  const BroadcastNoticeDialog({
    Key? key,
    required this.departmentCode,
    required this.onBroadcast,
  }) : super(key: key);

  @override
  State<BroadcastNoticeDialog> createState() => _BroadcastNoticeDialogState();
}

class _BroadcastNoticeDialogState extends State<BroadcastNoticeDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  NoticePriority _priority = NoticePriority.normal;
  String _targetAudience = 'All Faculty & Students';

  final List<String> _audienceOptions = [
    'All Faculty & Students',
    'Department Faculty Only',
    'Final Year Students',
    '2nd & 3rd B.Tech Students',
    'Lab Coordinators',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(NexoraColors.surface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(NexoraColors.primaryLight).withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.campaign_outlined,
              color: Color(NexoraColors.primaryDark),
              size: 24,
            ),
          ),
          const SizedBox(width: NexoraSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Department Broadcast',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(NexoraColors.text),
                  ),
                ),
                Text(
                  'Send alert to ${widget.departmentCode} department',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(NexoraColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Notice Title
            const Text(
              'Notice Title',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(NexoraColors.text),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'e.g. Mid-Term Question Bank Deadline',
                hintStyle: const TextStyle(color: Color(NexoraColors.textMuted), fontSize: 13),
                filled: true,
                fillColor: const Color(NexoraColors.inputBackground),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(NexoraColors.border)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(NexoraColors.border)),
                ),
              ),
            ),

            const SizedBox(height: NexoraSpacing.md),

            // Notice Message
            const Text(
              'Detailed Description',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(NexoraColors.text),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter complete announcement instructions...',
                hintStyle: const TextStyle(color: Color(NexoraColors.textMuted), fontSize: 13),
                filled: true,
                fillColor: const Color(NexoraColors.inputBackground),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(NexoraColors.border)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(NexoraColors.border)),
                ),
              ),
            ),

            const SizedBox(height: NexoraSpacing.md),

            // Priority Selection
            const Text(
              'Notice Priority',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(NexoraColors.text),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildPriorityChip(NoticePriority.normal, 'General'),
                const SizedBox(width: 8),
                _buildPriorityChip(NoticePriority.academic, 'Academic'),
                const SizedBox(width: 8),
                _buildPriorityChip(NoticePriority.urgent, 'Urgent'),
              ],
            ),

            const SizedBox(height: NexoraSpacing.md),

            // Target Audience
            const Text(
              'Target Audience',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(NexoraColors.text),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(NexoraColors.inputBackground),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(NexoraColors.border)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _targetAudience,
                  isExpanded: true,
                  style: const TextStyle(
                    color: Color(NexoraColors.text),
                    fontSize: 13,
                  ),
                  items: _audienceOptions.map((opt) {
                    return DropdownMenuItem<String>(
                      value: opt,
                      child: Text(opt),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _targetAudience = val);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Color(NexoraColors.textSecondary)),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            final title = _titleController.text.trim();
            final desc = _descriptionController.text.trim();
            if (title.isEmpty || desc.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter title and description.')),
              );
              return;
            }
            widget.onBroadcast(title, desc, _priority, _targetAudience);
            Navigator.pop(context);
          },
          icon: const Icon(Icons.send_rounded, size: 16),
          label: const Text('Broadcast'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(NexoraColors.primary),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityChip(NoticePriority priority, String label) {
    final isSelected = _priority == priority;
    return InkWell(
      onTap: () => setState(() => _priority = priority),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? priority.color.withOpacity(0.12) : const Color(NexoraColors.inputBackground),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? priority.color : const Color(NexoraColors.border),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? priority.color : const Color(NexoraColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

