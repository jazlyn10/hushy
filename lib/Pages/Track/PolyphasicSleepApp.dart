import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(PolyphasicSleepApp());

class SleepDataNew {
  final DateTime date;
  int sleepTimeInMinutes;
  int awakeTimeInMinutes;

  SleepDataNew({
    required this.date,
    required this.sleepTimeInMinutes,
    required this.awakeTimeInMinutes,
  });

  String toString() {
    return '${date.millisecondsSinceEpoch}|$sleepTimeInMinutes|$awakeTimeInMinutes';
  }

  static SleepDataNew fromString(String string) {
    List<String> parts = string.split('|');
    DateTime date = DateTime.fromMillisecondsSinceEpoch(int.parse(parts[0]));
    int sleepTime = int.parse(parts[1]);
    int awakeTime = int.parse(parts[2]);
    return SleepDataNew(date: date, sleepTimeInMinutes: sleepTime, awakeTimeInMinutes: awakeTime);
  }
}

class PolyphasicSleepApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Polyphasic Sleep App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: AppBarTheme(
          color: Color(0xFF233C67),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            primary: Color(0xFF233C67),
            textStyle: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
            ),
          ),
        ),
      ),
      home: PolyphasicSleepTracker(),
    );
  }
}

class PolyphasicSleepTracker extends StatefulWidget {
  @override
  _PolyphasicSleepTrackerState createState() => _PolyphasicSleepTrackerState();
}

class _PolyphasicSleepTrackerState extends State<PolyphasicSleepTracker> {
  bool isAwake = true;
  int sleepTimeInMinutes = 90;
  int totalSleepTimeInMinutes = 0;
  int totalAwakeTimeInMinutes = 0;
  DateTime? startTime;
  DateTime? todayStartTime;
  DateTime? todayEndTime;
  List<SleepDataNew> sleepDataList = [];

  @override
  void initState() {
    super.initState();
    loadSleepData();
    setupDayResetTimer();
  }

  void startTimer() {
    setState(() {
      startTime = DateTime.now();
    });
  }

  void endTimer() async {
    if (startTime != null) {
      DateTime endTime = DateTime.now();
      int elapsedTime = endTime.difference(startTime!).inMinutes;
      if (isAwake) {
        totalAwakeTimeInMinutes += elapsedTime;
      } else {
        totalSleepTimeInMinutes += elapsedTime;
      }
      updateSleepDataList(DateTime.now(), isAwake ? 0 : elapsedTime, isAwake ? elapsedTime : 0);
      await saveSleepData();
      setState(() {
        startTime = null;
      });
    }
  }

  Future<void> saveSleepData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> sleepDataStrings = sleepDataList.map((data) => data.toString()).toList();
    await prefs.setStringList('sleepData', sleepDataStrings);
  }

  Future<void> loadSleepData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> sleepDataStrings = prefs.getStringList('sleepData') ?? [];
    sleepDataList = sleepDataStrings.map((data) => SleepDataNew.fromString(data)).toList();
    setState(() {});
  }

  void toggleMode() {
    setState(() {
      isAwake = !isAwake;
    });
  }

  void setupDayResetTimer() {
    final now = DateTime.now();
    todayStartTime = DateTime(now.year, now.month, now.day, 0, 0, 0);
    todayEndTime = todayStartTime!.add(Duration(days: 1));

    final timeToReset = todayEndTime!.difference(now).inMilliseconds;
    Future.delayed(Duration(milliseconds: timeToReset), () {
      resetData();
      setupDayResetTimer();
    });
  }

  void resetData() {
    setState(() {
      totalSleepTimeInMinutes = 0;
      totalAwakeTimeInMinutes = 0;
    });
  }

  void updateSleepDataList(DateTime date, int sleepTime, int awakeTime) {
    int index = sleepDataList.indexWhere((data) =>
    data.date.year == date.year &&
        data.date.month == date.month &&
        data.date.day == date.day);
    if (index != -1) {
      sleepDataList[index].sleepTimeInMinutes += sleepTime;
      sleepDataList[index].awakeTimeInMinutes += awakeTime;
    } else {
      sleepDataList.add(SleepDataNew(
        date: date,
        sleepTimeInMinutes: sleepTime,
        awakeTimeInMinutes: awakeTime,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalMinutes = (totalSleepTimeInMinutes + totalAwakeTimeInMinutes).toDouble();
    double sleepPercentage = totalMinutes > 0 ? (totalSleepTimeInMinutes / totalMinutes) : 0.0;
    double awakePercentage = totalMinutes > 0 ? (totalAwakeTimeInMinutes / totalMinutes) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Polyphasic Sleep App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Polyphasic Sleep Tracker',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Track your sleep and awake periods\nin a polyphasic sleep schedule.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 20),
            Text(
              isAwake ? 'Awake Period' : 'Sleep Period',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              startTime != null ? 'Timer Running...' : 'Press Start',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ElevatedButton(
                  onPressed: () {
                    startTimer();
                  },
                  child: Text('Start'),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () {
                    endTimer();
                  },
                  child: Text('End'),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () {
                    toggleMode();
                  },
                  child: Text(isAwake ? 'Switch to Sleep' : 'Switch to Awake'),
                ),
              ],
            ),
            SizedBox(height: 20),
            SizedBox(
              width: 200,
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 0,
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(
                      value: sleepPercentage,
                      title: 'Sleep',
                      color: Colors.blue,
                    ),
                    PieChartSectionData(
                      value: awakePercentage,
                      title: 'Awake',
                      color: Colors.green,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            for (var data in sleepDataList)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '${data.date.day}/${data.date.month}/${data.date.year}: Sleep Time: ${data.sleepTimeInMinutes ~/ 60}h ${data.sleepTimeInMinutes % 60}m, Awake Time: ${data.awakeTimeInMinutes ~/ 60}h ${data.awakeTimeInMinutes % 60}m',
                  style: TextStyle(fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
