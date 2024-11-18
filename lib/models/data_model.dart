import 'package:flutter/material.dart';

class Todo {
  final String id;
  final String title;
  final DateTime date;

  Todo({required this.id, required this.title, required this.date});
}

class Reminder {
  final String id;
  final String title;
  final DateTime date;
  final String notes;

  Reminder({required this.id, required this.title, required this.date, required this.notes});
}

class EventData with ChangeNotifier {
  List<Todo> todos = [];
  List<Reminder> reminders = [];

  void addTodo(Todo todo) {
    todos.add(todo);
    notifyListeners();
  }

  void addReminder(Reminder reminder) {
    reminders.add(reminder);
    notifyListeners();
  }

  // Method to delete a reminder
  void deleteReminder(Reminder reminder) {
    reminders.removeWhere((r) => r.id == reminder.id);
    notifyListeners();
  }

  List<Todo> getTodosByDate(DateTime date) {
    return todos.where((todo) => todo.date.day == date.day &&
        todo.date.month == date.month && todo.date.year == date.year).toList();
  }

  List<Reminder> getRemindersByDate(DateTime date) {
    return reminders.where((reminder) => reminder.date.day == date.day &&
        reminder.date.month == date.month && reminder.date.year == date.year).toList();
  }
}
