import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'models/data_model.dart';
import 'generated/l10n.dart';

class CalendarHomePage extends StatefulWidget {
  final Function(Locale) onLocaleChange;

  CalendarHomePage({required this.onLocaleChange});

  @override
  _CalendarHomePageState createState() => _CalendarHomePageState();
}

class _CalendarHomePageState extends State<CalendarHomePage> with SingleTickerProviderStateMixin {
  Map<DateTime, List<String>> holidays = {};
  Map<DateTime, GlobalKey> dateKeys = {};
  DateTime? selectedDay;
  String _selectedLanguage = 'en';
  bool _showMonthYearPicker = false;
  String? sunriseTime;
  String? sunsetTime;

  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  final Map<String, String> languages = {
    'en': 'English',
    'ja': 'Japanese',
    'zh': 'Chinese',
    'th': 'Thai',
    'hi': 'Hindi',
    'ms': 'Malay',
    'ru': 'Russian',
    'es': 'Spanish',
    'fr': 'French',
    'pt': 'Portuguese',
    'ar': 'Arabic'
  };

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    _initializeLocationAndFetchHolidays();
  }

  Future<void> _initializeLocationAndFetchHolidays() async {
    try {
      Position position = await _determinePosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      String countryCode = placemarks.first.isoCountryCode ?? 'US';
      Map<DateTime, List<String>> fetchedHolidays = await fetchHolidays(countryCode);
      setState(() {
        holidays = fetchedHolidays;
      });
      await fetchSunriseSunset(position.latitude, position.longitude, selectedDay ?? DateTime.now());
    } catch (e) {
      print(e);
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<Map<DateTime, List<String>>> fetchHolidays(String countryCode) async {
    final response = await http.get(Uri.parse('https://holidayapi.com/v1/holidays?country=$countryCode&year=2024&key=7f07c38f-13c8-4a1e-851e-338b708243f1'));

    if (response.statusCode == 200) {
      Map<String, dynamic> holidaysData = jsonDecode(response.body);
      Map<DateTime, List<String>> holidays = {};

      for (var holiday in holidaysData['holidays']) {
        DateTime date = DateTime.parse(holiday['date']);
        if (holidays.containsKey(date)) {
          holidays[date]!.add(holiday['name']);
        } else {
          holidays[date] = [holiday['name']];
        }
      }
      return holidays;
    } else {
      throw Exception('Failed to load holidays');
    }
  }

  Future<void> fetchSunriseSunset(double latitude, double longitude, DateTime date) async {
    final response = await http.get(Uri.parse('https://api.sunrise-sunset.org/json?lat=$latitude&lng=$longitude&date=${date.toIso8601String().substring(0, 10)}&formatted=0'));

    if (response.statusCode == 200) {
      Map<String, dynamic> data = jsonDecode(response.body);
      setState(() {
        sunriseTime = DateTime.parse(data['results']['sunrise']).toLocal().toString().substring(11, 16);
        sunsetTime = DateTime.parse(data['results']['sunset']).toLocal().toString().substring(11, 16);
      });
    } else {
      throw Exception('Failed to load sunrise and sunset times');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleMonthYearPicker() {
    setState(() {
      _showMonthYearPicker = !_showMonthYearPicker;
      if (_showMonthYearPicker) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).calendarTitle),
        actions: <Widget>[
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedLanguage,
              icon: Icon(Icons.language, color: Colors.white),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedLanguage = newValue!;
                  widget.onLocaleChange(Locale(_selectedLanguage));
                });
              },
              items: languages.entries.map<DropdownMenuItem<String>>((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
            ),
          ),
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: _toggleMonthYearPicker
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _showMonthYearPicker ? MonthYearPicker(
                initialDate: selectedDay ?? DateTime.now(),
                onMonthYearSelected: (newDate) {
                  setState(() {
                    selectedDay = newDate;
                    sunriseTime = null; // Hide sunrise and sunset during transition
                    sunsetTime = null;  // Hide sunrise and sunset during transition
                    _toggleMonthYearPicker();
                  });
                },
              ) : TableCalendar(
                firstDay: DateTime.utc(2000, 1, 1),
                lastDay: DateTime.utc(2100, 12, 31),
                focusedDay: selectedDay ?? DateTime.now(),
                selectedDayPredicate: (day) => isSameDay(selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    this.selectedDay = selectedDay; // Update the selected day
                  });
                  _showEventPopup(context, selectedDay);
                  _fetchAdditionalInfo(selectedDay);
                },
                holidayPredicate: (day) {
                  return holidays.containsKey(day);
                },
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    var isSelected = isSameDay(selectedDay, day);
                    dateKeys[day] = GlobalKey();  // Assign a GlobalKey for each date
                    return Container(
                      key: dateKeys[day],
                      margin: EdgeInsets.all(4.0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? Colors.blue[200]?.withOpacity(0.5) : Colors.transparent,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        day.day.toString(),
                        style: TextStyle(color: isSelected ? Colors.white : Colors.black),
                      ),
                    );
                  },
                  holidayBuilder: (context, day, focusedDay) {
                    return Stack(
                      children: [
                        Container(
                          margin: EdgeInsets.all(4.0),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.blue[200]?.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            day.day.toString(),
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                eventLoader: (day) {
                  return holidays[day] ?? [];
                },
              ),
            ),
          ),
          if (selectedDay != null && !_showMonthYearPicker)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (sunriseTime != null)
                        Column(
                          children: [
                            Icon(Icons.wb_sunny, color: Colors.orange),
                            Text('Sunrise: $sunriseTime'),
                          ],
                        ),
                      if (sunsetTime != null)
                        Column(
                          children: [
                            Icon(Icons.nights_stay, color: Colors.blue),
                            Text('Sunset: $sunsetTime'),
                          ],
                        ),
                    ],
                  ),
                  if (holidays[selectedDay!] != null)
                    Column(
                      children: holidays[selectedDay!]!.map((holiday) {
                        return Text(
                          'Holiday: $holiday',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _fetchAdditionalInfo(DateTime selectedDay) async {
    try {
      Position position = await _determinePosition();
      await fetchSunriseSunset(position.latitude, position.longitude, selectedDay);
    } catch (e) {
      print(e);
    }
  }

  void _showEventPopup(BuildContext context, DateTime selectedDay) {
    List<String> holidayList = holidays[selectedDay] ?? [];
    final RenderBox? renderBox = dateKeys[selectedDay]?.currentContext?.findRenderObject() as RenderBox?;
    final offset = renderBox?.localToGlobal(Offset.zero);

    List<PopupMenuEntry<Object>> menuItems = [
      if (holidayList.isNotEmpty)
        PopupMenuItem(
          child: Text("Holidays: ${holidayList.join(', ')}", style: TextStyle(color: Colors.red)),
          enabled: false,
        ),
      PopupMenuItem(
        value: 'todo',
        child: ListTile(
          leading: Icon(Icons.note_add),
          title: Text(S.of(context).addTodo),
        ),
      ),
      PopupMenuItem(
        value: 'reminder',
        child: ListTile(
          leading: Icon(Icons.alarm_add),
          title: Text(S.of(context).addReminder),
        ),
      ),
    ];

    if (offset != null) {
      showMenu(
        context: context,
        position: RelativeRect.fromLTRB(offset.dx, offset.dy, offset.dx + 200, offset.dy + 60),
        items: menuItems,
        elevation: 8.0,
      ).then((value) {
        if (value == 'todo') {
          _showAddTodoDialog(context, selectedDay);
        } else if (value == 'reminder') {
          _showAddReminderDialog(context, selectedDay);
        }
      });
    }
  }

  void _showAddTodoDialog(BuildContext context, DateTime date) {
    TextEditingController todoController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(S.of(context).addTodo),
          content: TextField(
            controller: todoController,
            decoration: InputDecoration(hintText: S.of(context).enterTodo),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(S.of(context).add),
              onPressed: () {
                if (todoController.text.isNotEmpty) {
                  Provider.of<EventData>(context, listen: false).addTodo(
                    Todo(id: DateTime.now().toString(), title: todoController.text, date: date)
                  );
                  Navigator.of(context).pop();
                }
              },
            ),
            TextButton(
              child: Text(S.of(context).close),
              onPressed: () {
                Navigator.of(context). pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showAddReminderDialog(BuildContext context, DateTime date) {
    TextEditingController reminderController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(S.of(context).addReminder),
          content: TextField(
            controller: reminderController,
            decoration: InputDecoration(hintText: S.of(context).enterReminder),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(S.of(context).add),
              onPressed: () {
                if (reminderController.text.isNotEmpty) {
                  Provider.of<EventData>(context, listen: false).addReminder(
                  Reminder(id: DateTime.now().toString(), title: reminderController.text, date: date, notes: reminderController.text)
                  );
                  Navigator.of(context).pop();
                }
              },
            ),
            TextButton(
              child: Text(S.of(context).close),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

class MonthYearPicker extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime) onMonthYearSelected;

  MonthYearPicker({required this.initialDate, required this.onMonthYearSelected});

  @override
  _MonthYearPickerState createState() => _MonthYearPickerState();
}

class _MonthYearPickerState extends State<MonthYearPicker> {
  late int selectedYear;
  bool showMonths = false;

  @override
  void initState() {
    super.initState();
    selectedYear = widget.initialDate.year;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: showMonths ? _buildMonthPicker() : _buildYearPicker(),
    );
  }

  Widget _buildYearPicker() {
    return ListView.builder(
      key: ValueKey('YearPicker'),
      itemCount: 101, // From year 2000 to 2100 inclusive
      itemBuilder: (context, index) {
        int year = 2000 + index;
        return ListTile(
          title: Text(year.toString()),
          onTap: () {
            setState(() {
              selectedYear = year;
              showMonths = true;
            });
          },
        );
      },
    );
  }

  Widget _buildMonthPicker() {
    return GridView.builder(
      key: ValueKey('MonthPicker'),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            widget.onMonthYearSelected(DateTime(selectedYear, index + 1));
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[300], // Light grey for non-selected months
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              DateFormat('MMM').format(DateTime(selectedYear, index + 1)),
              style: TextStyle(
                color: Colors.black, // Dark text for better readability
                fontSize: 16,
              ),
            ),
          ),
        );
      },
    );
  }
}
