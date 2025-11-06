import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.local);
  await _initNotifications();
  runApp(const AlarmApp());
}

Future<void> _initNotifications() async {
  const iOS = DarwinInitializationSettings();
  const settings = InitializationSettings(iOS: iOS);
  await flutterLocalNotificationsPlugin.initialize(
    settings,
    onDidReceiveNotificationResponse: (details) {
      if (details.payload == 'ALARM') {
        _showAlarmScreen();
      }
    },
  );
}

void _showAlarmScreen() {
  runApp(const AlarmRingingPage());
}

class AlarmApp extends StatelessWidget {
  const AlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iOS Alarm',
      theme: ThemeData(useMaterial3: true),
      home: const AlarmHomePage(),
    );
  }
}

class AlarmHomePage extends StatefulWidget {
  const AlarmHomePage({super.key});

  @override
  State<AlarmHomePage> createState() => _AlarmHomePageState();
}

class _AlarmHomePageState extends State<AlarmHomePage> {
  TimeOfDay _selectedTime = TimeOfDay.now();

  Future<void> _scheduleAlarm() async {
    final now = DateTime.now();
    final scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final tzTime = tz.TZDateTime.from(scheduledDate, tz.local);
    const iosDetails = DarwinNotificationDetails(
      sound: 'alarm_sound.aiff',
      presentAlert: true,
      presentSound: true,
      presentBadge: false,
    );
    const details = NotificationDetails(iOS: iosDetails);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Alarm',
      'Wake up! ⏰',
      tzTime.isBefore(tz.TZDateTime.now(tz.local))
          ? tzTime.add(const Duration(days: 1))
          : tzTime,
      details,
      payload: 'ALARM',
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Alarm scheduled!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('iOS Alarm App')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Selected time: ${_selectedTime.format(context)}'),
            ElevatedButton(
              onPressed: () async {
                final picked = await showTimePicker(
                    context: context, initialTime: _selectedTime);
                if (picked != null) setState(() => _selectedTime = picked);
              },
              child: const Text('Pick Alarm Time'),
            ),
            ElevatedButton(
              onPressed: _scheduleAlarm,
              child: const Text('Schedule Alarm'),
            ),
          ],
        ),
      ),
    );
  }
}

class AlarmRingingPage extends StatelessWidget {
  const AlarmRingingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red.shade100,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.alarm, size: 100, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Alarm Ringing!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  await flutterLocalNotificationsPlugin.cancelAll();
                  runApp(const AlarmApp());
                },
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
