import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:android_alarm_manager/android_alarm_manager.dart';
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

const String countKey = 'count';

const String isolateName = 'isolate';

final ReceivePort port = ReceivePort();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  IsolateNameServer.registerPortWithName(
    port.sendPort,
    isolateName,
  );
  runApp(FajrAlarm());
}

class FajrAlarm extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'منبه صلاة الفجر',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        primaryColor: Color(0xff135775),
        brightness: Brightness.dark,
      ),
      home: FajrPrayer(),
    );
  }
}

class FajrPrayer extends StatefulWidget {
  @override
  _FajrPrayerState createState() => _FajrPrayerState();
}

class _FajrPrayerState extends State<FajrPrayer> {
  static bool _alarmIsPlaying;
  TimeOfDay _prayerTime;
  bool _activeAlarm;

  @override
  void initState() {
    super.initState();

    AndroidAlarmManager.initialize();
    _getSelectedData();
  }

  void _getSelectedData() async {
    final prefs = await SharedPreferences.getInstance();
    final prayerHour = prefs.getInt('prayerHour');
    final prayerMinute = prefs.getInt('prayerMinute');
    setState(() {
      _alarmIsPlaying = prefs.getBool('alarmIsPlaying') ?? false;
      if (prayerHour == null || prayerMinute == null) return;
      _activeAlarm = prefs.getBool('activeAlarm') ?? false;
      _prayerTime = TimeOfDay(
        hour: prayerHour,
        minute: prayerMinute,
      );
    });
  }

  void _pickTime() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (selectedTime == null) return;
    setState(() {
      _prayerTime = selectedTime;
    });
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('prayerHour', selectedTime.hour);
    prefs.setInt('prayerMinute', selectedTime.minute);
    if (_prayerTime != null) _toggleAlarm(true);
  }

  void _toggleAlarm(bool value) async {
    setState(() {
      _activeAlarm = value;
    });
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('activeAlarm', value);
    if (_activeAlarm) {
      final id = Random().nextInt(pow(2, 31));
      prefs.setInt('alarmID', id);
      final now = DateTime.now();
      final alarmTime = DateTime(
        now.year,
        now.month,
        now.day,
        _prayerTime.hour,
        _prayerTime.minute,
      );
      await AndroidAlarmManager.oneShotAt(
        alarmTime,
        id,
        callback,
        exact: true,
        wakeup: true,
      );
      Future.delayed(alarmTime.difference(DateTime.now()), () {
        if (!mounted) return;
        setState(() {
          _alarmIsPlaying = true;
        });
      });
    } else {
      final id = prefs.getInt('alarmID');
      AndroidAlarmManager.cancel(id);
      prefs.remove('alarmID');
    }
  }

  static Future<void> callback() async {
    // print('--- play alarm');
    final assetsAudioPlayer = AssetsAudioPlayer();
    assetsAudioPlayer.open(
      Audio("audio/alarm.mp3"),
    );
    assetsAudioPlayer.play();
    final prefs = await SharedPreferences.getInstance();
    _alarmIsPlaying = true;
    prefs.setBool('alarmIsPlaying', true);
    prefs.remove('prayerHour');
    prefs.remove('prayerMinute');
    prefs.remove('activeAlarm');
    Future.delayed(Duration(minutes: 10), () {
      _alarmIsPlaying = false;
      prefs.setBool('alarmIsPlaying', false);
      // print('--- stop alarm');
      assetsAudioPlayer.stop();
    });
  }

  void _stopAlarm() async {
    setState(() {
      _alarmIsPlaying = false;
    });
    final assetsAudioPlayer = AssetsAudioPlayer();
    assetsAudioPlayer.stop();
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('alarmIsPlaying', false);
    final id = prefs.getInt('alarmID');
    if (id == null) return;
    AndroidAlarmManager.cancel(id);
    prefs.remove('alarmID');
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.title;
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (cxt, constraints) => Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Column(
                  children: <Widget>[
                    Image.asset(
                      'images/muslim-prayer-1571228-1330433.webp',
                      width: constraints.maxWidth * 0.5,
                    ),
                    const SizedBox(height: 20),
                    FlatButton(
                      padding: const EdgeInsets.all(0),
                      onPressed: _pickTime,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            'وقت صلاة الفجر',
                            style: titleStyle,
                          ),
                          Text(
                            _prayerTime == null
                                ? '--:--'
                                : '${_prayerTime.hour}:${_prayerTime.minute}',
                            style: titleStyle,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'تشغيل المنبه',
                          style: titleStyle,
                        ),
                        Switch.adaptive(
                          value: _activeAlarm ?? false,
                          onChanged: _toggleAlarm,
                          activeTrackColor: Colors.white,
                          activeColor: Color(0xff4e7094),
                        ),
                      ],
                    ),
                    if (_alarmIsPlaying ?? false)
                      RaisedButton.icon(
                        onPressed: _stopAlarm,
                        icon: Icon(Icons.alarm_off),
                        label: Text('إقاف المنبه'),
                        color: Colors.red,
                      )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
