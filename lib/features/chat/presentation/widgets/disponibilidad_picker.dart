import 'package:flutter/material.dart';
import 'package:autodoc/core/utils/l10n_extension.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/theme/app_text_styles.dart';

class DisponibilidadPicker extends StatefulWidget {
  final Function(DateTime fecha, String hora) onConfirm;

  const DisponibilidadPicker({super.key, required this.onConfirm});

  @override
  State<DisponibilidadPicker> createState() => _DisponibilidadPickerState();
}

class _DisponibilidadPickerState extends State<DisponibilidadPicker> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String? _selectedTime;

  final List<String> _availableTimes = [
    '08:00 AM', '09:00 AM', '10:00 AM', '11:00 AM',
    '01:00 PM', '02:00 PM', '03:00 PM', '04:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceContainer : colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Proponer Fecha y Hora',
            style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TableCalendar(
            firstDay: DateTime.now(),
            lastDay: DateTime.now().add(const Duration(days: 90)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                _selectedTime = null; // reset time when day changes
              });
            },
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
          ),
          const SizedBox(height: 24),
          if (_selectedDay != null) ...[
            Text(
              'Horarios Disponibles',
              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _availableTimes.length,
                itemBuilder: (context, index) {
                  final time = _availableTimes[index];
                  final isSelected = _selectedTime == time;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(time),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedTime = selected ? time : null;
                        });
                      },
                      selectedColor: colors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _selectedTime != null
                    ? () {
                        widget.onConfirm(_selectedDay!, _selectedTime!);
                        Navigator.pop(context);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: colors.primary.withValues(alpha: 0.3),
                ),
                child: Text(context.l10n.chatConfirmProposal, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
