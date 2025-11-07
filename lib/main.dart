import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.local);

  final NotificationAppLaunchDetails? launchDetails =
  await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

  String? initialPayload;
  if (launchDetails?.didNotificationLaunchApp ?? false) {
    initialPayload = launchDetails!.notificationResponse?.payload;
  }

  await _initNotifications();
  await AlarmDatabase.init();

  runApp(AlarmApp(initialPayload: initialPayload));
}

Future<void> _initNotifications() async {
  const iOS = DarwinInitializationSettings();
  const settings = InitializationSettings(iOS: iOS);

  await flutterLocalNotificationsPlugin.initialize(
    settings,
    onDidReceiveNotificationResponse: (details) {
      final payload = details.payload ?? '';
      if (payload.startsWith('ALARM_')) {
        final id = int.tryParse(payload.split('_').last) ?? 0;
        _navigateToAlarmScreen(id);
      }
    },
  );
}

void _navigateToAlarmScreen(int alarmId) {
  navigatorKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => AlarmRingingPage(alarmId: alarmId),
    ),
        (route) => false,
  );
}

class AlarmApp extends StatelessWidget {
  final String? initialPayload;
  const AlarmApp({super.key, this.initialPayload});

  @override
  Widget build(BuildContext context) {
    int? initialAlarmId;
    if (initialPayload != null && initialPayload!.startsWith('ALARM_')) {
      initialAlarmId = int.tryParse(initialPayload!.split('_').last);
    }

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Alarm Clock',
      home: initialAlarmId != null
          ? AlarmRingingPage(alarmId: initialAlarmId)
          : const AlarmHomePage(),
    );
  }
}

class AlarmHomePage extends StatefulWidget {
  const AlarmHomePage({super.key});

  @override
  State<AlarmHomePage> createState() => _AlarmHomePageState();
}

class _AlarmHomePageState extends State<AlarmHomePage> {
  List<Map<String, dynamic>> _alarms = [];

  @override
  void initState() {
    super.initState();
    _loadAlarms();
  }

  Future<void> _loadAlarms() async {
    _alarms = await AlarmDatabase.getAlarms();
    setState(() {});
  }

  Future<void> _addAlarm(BuildContext ctx) async {
    final picked = await showTimePicker(
      context: ctx,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final id = await AlarmDatabase.insertAlarm(picked.hour, picked.minute);
      await _scheduleAlarm(id, picked.hour, picked.minute);
      _loadAlarms();
    }
  }

  Future<void> _scheduleAlarm(int id, int hour, int minute) async {
    final now = DateTime.now();
    final scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    final tzTime = tz.TZDateTime.from(scheduledDate, tz.local);

    const iosDetails = DarwinNotificationDetails(
      sound: 'alarm_sound.aiff',
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    );
    const details = NotificationDetails(iOS: iosDetails);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      'Alarm',
      'Wake up! ⏰',
      tzTime.isBefore(tz.TZDateTime.now(tz.local))
          ? tzTime.add(const Duration(days: 1))
          : tzTime,
      details,
      payload: 'ALARM_$id',
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alarms')),
      body: ListView.builder(
        itemCount: _alarms.length,
        itemBuilder: (context, index) {
          final alarm = _alarms[index];
          return ListTile(
            title: Text(
                '⏰ ${alarm['hour'].toString().padLeft(2, '0')}:${alarm['minute'].toString().padLeft(2, '0')}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                await AlarmDatabase.deleteAlarm(alarm['id']);
                await flutterLocalNotificationsPlugin.cancel(alarm['id']);
                _loadAlarms();
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: ()=>_addAlarm(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AlarmRingingPage extends StatelessWidget {
  final int alarmId;
  const AlarmRingingPage({super.key, required this.alarmId});

  Future<void> _snooze(int minutes) async {
    await flutterLocalNotificationsPlugin.cancel(alarmId);

    final snoozeTime =
    tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes));

    const iosDetails = DarwinNotificationDetails(
      sound: 'alarm_sound.aiff',
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    );
    const details = NotificationDetails(iOS: iosDetails);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      alarmId,
      'Snoozed Alarm',
      '⏰ Alarm again in $minutes minutes!',
      snoozeTime,
      details,
      payload: 'ALARM_$alarmId',
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );

    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AlarmHomePage()),
          (route) => false,
    );
  }

  Future<void> _dismiss() async {
    await flutterLocalNotificationsPlugin.cancel(alarmId);
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AlarmHomePage()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.alarm, color: Colors.red, size: 100),
            const SizedBox(height: 24),
            const Text(
              'Alarm Ringing!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.cancel),
              label: const Text('Dismiss'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              ),
              onPressed: _dismiss,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.snooze),
              label: const Text('Snooze 5 min'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              ),
              onPressed: () => _snooze(5),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.snooze),
              label: const Text('Snooze 10 min'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding:
                const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              ),
              onPressed: () => _snooze(10),
            ),
          ],
        ),
      ),
    );
  }
}

class AlarmDatabase {
  static Database? _db;

  static Future<void> init() async {
    final path = join(await getDatabasesPath(), 'alarms.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE alarms(id INTEGER PRIMARY KEY AUTOINCREMENT, hour INTEGER, minute INTEGER)',
        );
      },
    );
  }

  static Future<int> insertAlarm(int hour, int minute) async {
    return await _db!.insert('alarms', {'hour': hour, 'minute': minute});
  }

  static Future<List<Map<String, dynamic>>> getAlarms() async {
    return await _db!.query('alarms', orderBy: 'hour, minute');
  }

  static Future<void> deleteAlarm(int id) async {
    await _db!.delete('alarms', where: 'id = ?', whereArgs: [id]);
  }
}
