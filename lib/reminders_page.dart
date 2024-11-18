import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/data_model.dart';
import 'package:intl/intl.dart';

class RemindersPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final reminders = Provider.of<EventData>(context).reminders;
    
    return Scaffold(
      appBar: AppBar(title: Text('Reminders')),
      body: reminders.isEmpty
          ? Center(child: Text("No reminders set."))
          : ListView.builder(
              itemCount: reminders.length,
              itemBuilder: (context, index) {
                final reminder = reminders[index];
                return ListTile(
                  title: Text(reminder.title),
                  subtitle: Text('${DateFormat('yyyy-MM-dd – hh:mm a').format(reminder.date)} - ${reminder.notes}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editReminder(context, reminder),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _showDeleteDialog(context, reminder),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _editReminder(BuildContext context, Reminder reminder) {
    // Here you would implement functionality to edit the reminder
  }

  void _showDeleteDialog(BuildContext context, Reminder reminder) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Reminder'),
          content: Text('Are you sure you want to delete this reminder?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () {
                Provider.of<EventData>(context, listen: false).deleteReminder(reminder);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
