import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'main.dart';

// ...

class AlarmRingingPage extends StatefulWidget {
  final int alarmId;
  const AlarmRingingPage({super.key, required this.alarmId});

  @override
  State<AlarmRingingPage> createState() => _AlarmRingingPageState();
}

class _AlarmRingingPageState extends State<AlarmRingingPage> {
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _playLoopingAlarm();
  }

  Future<void> _playLoopingAlarm() async {
    _audioPlayer = AudioPlayer();
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource('sounds/alarm.mp3'));
  }

  Future<void> _stopAlarm() async {
    await _audioPlayer.stop();
  }

  Future<void> _snooze(int minutes) async {
    await _stopAlarm();
    await flutterLocalNotificationsPlugin.cancel(widget.alarmId);

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
      widget.alarmId,
      'Snoozed Alarm',
      '⏰ Alarm again in $minutes minutes!',
      snoozeTime,
      details,
      payload: 'ALARM_${widget.alarmId}',
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
    await _stopAlarm();
    await flutterLocalNotificationsPlugin.cancel(widget.alarmId);
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AlarmHomePage()),
          (route) => false,
    );
  }

  @override
  void dispose() {
    _stopAlarm();
    _audioPlayer.dispose();
    super.dispose();
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
