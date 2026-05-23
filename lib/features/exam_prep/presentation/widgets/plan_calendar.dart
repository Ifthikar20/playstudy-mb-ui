import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../data/models/exam_plan.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Month calendar showing scheduled study days, completed days, and the
/// exam date. Tap a day to jump to that day's session (today only).
class PlanCalendar extends StatefulWidget {
  final ExamPlan plan;
  const PlanCalendar({super.key, required this.plan});

  @override
  State<PlanCalendar> createState() => _PlanCalendarState();
}

class _PlanCalendarState extends State<PlanCalendar> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = _dateOnly(DateTime.now());
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = widget.plan;
    final scheduled = plan.scheduledDays.map(_dateOnly).toSet();
    final completed = plan.results.entries
        .where((e) => e.value.completed)
        .map((e) => _parseKey(e.key))
        .toSet();

    return TableCalendar(
      firstDay: plan.createdAt.subtract(const Duration(days: 30)),
      lastDay: plan.examDate.add(const Duration(days: 30)),
      focusedDay: _focusedDay,
      selectedDayPredicate: (d) =>
          _selectedDay != null && isSameDay(d, _selectedDay),
      calendarFormat: CalendarFormat.month,
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      onDaySelected: (sel, focused) {
        setState(() {
          _selectedDay = sel;
          _focusedDay = focused;
        });
        if (isSameDay(sel, DateTime.now())) {
          context.go('/exam/${plan.id}/today');
        }
      },
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, _) => _dayCell(
          day,
          scheduled: scheduled.contains(_dateOnly(day)),
          completed: completed.contains(_dateOnly(day)),
          isExam: isSameDay(day, plan.examDate),
          theme: theme,
        ),
        todayBuilder: (context, day, _) => _dayCell(
          day,
          scheduled: scheduled.contains(_dateOnly(day)),
          completed: completed.contains(_dateOnly(day)),
          isExam: isSameDay(day, plan.examDate),
          isToday: true,
          theme: theme,
        ),
        selectedBuilder: (context, day, _) => _dayCell(
          day,
          scheduled: scheduled.contains(_dateOnly(day)),
          completed: completed.contains(_dateOnly(day)),
          isExam: isSameDay(day, plan.examDate),
          isSelected: true,
          theme: theme,
        ),
      ),
    );
  }

  Widget _dayCell(
    DateTime day, {
    required bool scheduled,
    required bool completed,
    required bool isExam,
    bool isToday = false,
    bool isSelected = false,
    required ThemeData theme,
  }) {
    Color? bg;
    Color fg = theme.colorScheme.onSurface;
    if (isExam) {
      bg = theme.colorScheme.error;
      fg = Colors.white;
    } else if (completed) {
      bg = theme.colorScheme.tertiary;
      fg = Colors.white;
    } else if (isSelected) {
      bg = theme.colorScheme.primary;
      fg = Colors.white;
    } else if (isToday) {
      bg = theme.colorScheme.primary.withOpacity(0.18);
      fg = theme.colorScheme.primary;
    } else if (scheduled) {
      bg = theme.colorScheme.primary.withOpacity(0.08);
    }

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: fg,
            fontWeight: isToday || isSelected || isExam || completed
                ? FontWeight.w700
                : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  DateTime _parseKey(String k) {
    final parts = k.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }
}
