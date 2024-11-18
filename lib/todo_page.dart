import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/data_model.dart';

class TodoPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final todos = Provider.of<EventData>(context).todos;
    return Scaffold(
      appBar: AppBar(title: Text('To-Do List')),
      body: ListView.builder(
        itemCount: todos.length,
        itemBuilder: (context, index) => ListTile(
          title: Text(todos[index].title),
          subtitle: Text('${todos[index].date.toIso8601String()}'),
        ),
      ),
    );
  }
}
