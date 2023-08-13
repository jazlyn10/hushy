import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SleepData(),
    );
  }
}

class SleepData extends StatefulWidget {
  const SleepData({Key? key}) : super(key: key);

  @override
  State<SleepData> createState() => _SleepDataState();
}

class SleepEntry {
  final String date;
  final int sleepDuration;
  final int disturbances;

  SleepEntry({
    required this.date,
    required this.sleepDuration,
    required this.disturbances,
  });

  // Add a toJson method to convert SleepEntry to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'sleepDuration': sleepDuration,
      'disturbances': disturbances,
    };
  }

  // Add a factory constructor to create SleepEntry from a JSON map
  factory SleepEntry.fromJson(Map<String, dynamic> json) {
    return SleepEntry(
      date: json['date'],
      sleepDuration: json['sleepDuration'],
      disturbances: json['disturbances'],
    );
  }

  Future<void> save() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt("sleep_duration_${this.date}", this.sleepDuration);
    await prefs.setInt("disturbances_${this.date}", this.disturbances);
  }

  // Fetch all SleepEntry instances from shared preferences
  static Future<List<SleepEntry>> fetchAll() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Set<String> keys = prefs.getKeys();

    List<SleepEntry> sleepEntries = [];
    for (String key in keys) {
      if (key.startsWith("sleep_duration_")) {
        String dateKey = key.replaceFirst("sleep_duration_", "");
        int sleepDuration = prefs.getInt(key) ?? 0;
        int disturbances = prefs.getInt("disturbances_$dateKey") ?? 0;
        sleepEntries.add(SleepEntry(
          date: dateKey,
          sleepDuration: sleepDuration,
          disturbances: disturbances,
        ));
      }
    }

    return sleepEntries;
  }
}

class _SleepDataState extends State<SleepData> {
  bool isSleeping = false;
  bool previousSleepState = false;
  double sleepThreshold = 0.003;
  DateTime? sleepStartTime;
  DateTime? sleepEndTime;
  List<Duration> sleepDurations = [];
  List<int> sleepDurationsInMinutes = [];
  int disturbanceCounter = 0;
  List<SleepEntry> accumulatedSleepData = [];
  StreamSubscription<UserAccelerometerEvent>? accelerometerSubscription;


  @override
  void initState() {
    super.initState();
    // Initialize accelerometer
    initAccelerometer();
    // Fetch accumulated sleep data
    fetchAccumulatedSleepData();
  }


  @override
  void dispose() {
    // Cancel the accelerometer subscription to prevent calling setState after dispose
    accelerometerSubscription?.cancel();
    super.dispose();
  }

  Future<void> saveAccumulatedSleepData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> accumulatedData = accumulatedSleepData.map((entry) => json.encode(entry.toJson())).toList();
    await prefs.setStringList("accumulated_sleep_data", accumulatedData);
  }


  void fetchAccumulatedSleepData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> accumulatedData = prefs.getStringList("accumulated_sleep_data") ?? [];

    for (String entryJson in accumulatedData) {
      Map<String, dynamic> entryMap = json.decode(entryJson);
      SleepEntry entry = SleepEntry.fromJson(entryMap);
      accumulatedSleepData.add(entry);
    }

    setState(() {});
  }

  void onAwakeButtonClicked() async {
    if (sleepStartTime != null) {
      // Create a SleepEntry instance for the current sleep session
      SleepEntry sleepEntry = SleepEntry(
        date: DateFormat.yMd().format(sleepStartTime!),
        sleepDuration: getSleepDuration().inMinutes,
        disturbances: disturbanceCounter,
      );

      // Save the SleepEntry instance to shared preferences
      await sleepEntry.save();

      // Add the new sleep entry to the accumulatedSleepData list
      accumulatedSleepData.add(sleepEntry);

      // Clear the current sleep session data
      sleepStartTime = null;
      sleepEndTime = null;
      disturbanceCounter = 0;

      // Save accumulated sleep data to shared preferences
      await saveAccumulatedSleepData();

      // Navigate to the AllDataPage after saving the data
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AllDataPage(sleepEntries: accumulatedSleepData),
        ),
      );
    }
  }





  void initAccelerometer() {
    // Store the subscription in the instance variable
    accelerometerSubscription = userAccelerometerEvents.listen((UserAccelerometerEvent event) {
      setState(() {
        detectSleep(event);
      });
    });
  }

  Map<DateTime, int> disturbanceData = {};

  void detectSleep(UserAccelerometerEvent event) {
    double magnitude = (event.x * event.x) + (event.y * event.y) + (event.z * event.z);

    if (magnitude < sleepThreshold) {
      setState(() {
        if (!previousSleepState) {
          sleepStartTime = DateTime.now();
          previousSleepState = true;
        }
        isSleeping = true;
      });
    } else {
      setState(() {
        if (previousSleepState) {
          sleepEndTime = DateTime.now();
          if (sleepStartTime != null && sleepEndTime != null) {
            Duration sleepDuration = sleepEndTime!.difference(sleepStartTime!);
            int sleepDurationInMinutes = sleepDuration.inMinutes;
            if (sleepDurationInMinutes >= 2) {
              sleepDurations.add(sleepDuration);
              sleepDurationsInMinutes.add(sleepDurationInMinutes);
              disturbanceData[sleepStartTime!] = disturbanceCounter;

              // Accumulate sleep data during the day
              accumulatedSleepData.add(
                SleepEntry(
                  date: DateFormat.yMd().format(sleepStartTime!),
                  sleepDuration: sleepDurationInMinutes,
                  disturbances: disturbanceCounter,

                ),
              );

              disturbanceCounter = 0;
            }
          }

        }
        isSleeping = false;
      });
      previousSleepState = false;
    }
  }

  String formatTime(DateTime? time) {
    if (time == null) {
      return 'N/A'; // Handle the case when time is null
    }
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }



  String formatDuration(Duration duration) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }

  List<SleepEntry> createSleepEntries() {
    List<SleepEntry> entries = [];

    for (DateTime date in getDailySleepData().keys) {
      String formattedDate = DateFormat.yMd().format(date);
      Duration sleepDuration = getDailySleepData()[date]!; // Sleep duration in minutes
      int disturbances = disturbanceData[date] ?? 0;

      SleepEntry entry = SleepEntry(
        date: formattedDate,
        sleepDuration: sleepDuration.inMinutes, // Convert sleep duration to minutes
        disturbances: disturbances,
      );

      entries.add(entry);
    }

    return entries;
  }

  Duration getTotalSleepDuration() {
    return sleepDurations.fold(Duration.zero, (previous, current) => previous + current);
  }

  Duration getSleepDuration() {
    if (sleepStartTime != null && isSleeping) {
      DateTime currentTime = DateTime.now();
      return currentTime.difference(sleepStartTime!);
    }
    return Duration.zero;
  }





  @override
  Widget build(BuildContext context) {
    List<SleepEntry> sleepEntries = createSleepEntries();

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0xFF233C67),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: Text('Current Sleep Data'),
          actions: [
            IconButton(
              icon: Icon(Icons.data_usage),
              onPressed: () {
                // Navigate to the AllDataPage
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AllDataPage(sleepEntries: accumulatedSleepData),
                  ),
                );
              },
            ),
            TextButton(
              onPressed: onAwakeButtonClicked,
              child: Text(
                'Awake',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],

            // Add the "Awake" button to save accumulated sleep data
          //   TextButton(
          //     onPressed: () {
          //       // Call the function to save accumulated sleep data to shared preferences
          //       saveAccumulatedSleepData();
          //     },
          //     child: Text(
          //       'Awake',
          //       style: TextStyle(fontSize: 16, color: Colors.white),
          //     ),
          //   ),
          // ],

        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isSleeping ? 'Sleeping' : 'Awake',
                  style: TextStyle(fontSize: 24),
                ),
                SizedBox(height: 20),
                Text(
                  isSleeping ? 'Time started sleeping: ${formatTime(sleepStartTime!)}' : 'Time started sleeping: -',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 10),
                Text(
                  isSleeping ? 'Time slept: ${formatDuration(getSleepDuration())}' : 'Time slept: -',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 10),
                Text(
                  'Total Time Slept: ${formatDuration(getTotalSleepDuration())}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                Text(
                  'Sleep Disturbances: ${sleepDurationsInMinutes.length}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  'Sleep durations:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Column(
                  children: sleepDurationsInMinutes.map((durationInMinutes) {
                    return Text(
                      formatDuration(Duration(minutes: durationInMinutes)),
                      style: TextStyle(fontSize: 16),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Map<DateTime, Duration> getDailySleepData() {
    Map<DateTime, Duration> dailySleepData = {};

    if (sleepStartTime != null) {
      for (int i = 0; i < sleepDurations.length; i++) {
        DateTime sleepDate = sleepStartTime!.add(sleepDurations[i]);

        dailySleepData.update(
          DateTime(sleepDate.year, sleepDate.month, sleepDate.day),
              (value) => value + sleepDurations[i],
          ifAbsent: () => sleepDurations[i],
        );
      }
    }

    return dailySleepData;
  }
}
class AllDataPage extends StatelessWidget {
  final List<SleepEntry>? sleepEntries; // Make it nullable

  AllDataPage({required this.sleepEntries});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('All Data'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            // Navigate back to the previous page
            Navigator.pop(context);
          },
        ),
      ),
      body: sleepEntries != null && sleepEntries!.isNotEmpty // Check if sleepEntries is not null and not empty
          ? ListView.builder(
        itemCount: sleepEntries!.length,
        itemBuilder: (context, index) {
          SleepEntry entry = sleepEntries![index];
          return ListTile(
            title: Text(entry.date),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sleep Duration: ${entry.sleepDuration}'),
                Text('Disturbances: ${entry.disturbances}'),
              ],
            ),
          );
        },
      )
          : Center(
        child: Text('No sleep data available.'),
      ),
    );
  }
}






// import 'package:flutter/material.dart';
// import 'package:sensors_plus/sensors_plus.dart';
// import 'dart:async'; // Import dart:async library for Timer
// import 'package:hush/Pages/Track/AllDataPage.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:hush/Pages/profile.dart';
//
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(); // Initialize Firebase
//   runApp(MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: SleepData(),
//     );
//   }
// }
//
// class SleepData extends StatefulWidget {
//   const SleepData({Key? key}) : super(key: key);
//
//   @override
//   State<SleepData> createState() => _SleepDataState();
// }
//
// class _SleepDataState extends State<SleepData> {
//   bool isSleeping = false;
//   bool previousSleepState = false;
//   double sleepThreshold = 0.003;
//   DateTime? sleepStartTime;
//   DateTime? sleepEndTime;
//   List<Duration> sleepDurations = [];
//   List<int> sleepDurationsInMinutes = [];
//   int intervalsCount = 0;
//   int disturbanceCounter = 0; // Added disturbance counter
//   TimeOfDay nightStartTime = TimeOfDay(hour: 18, minute: 0);
//   TimeOfDay nightEndTime = TimeOfDay(hour: 23, minute: 59);
//
//
//
//   @override
//   void initState() {
//     super.initState();
//     initAccelerometer();
//     saveAndFetchData();
//   }
//
//   void saveAndFetchData() async {
//     Map<DateTime, Duration> dailySleepData = getDailySleepData();
//     await saveDailySleepData(dailySleepData, disturbanceData);
//
//     // Fetch the data from Firebase and update the UI if necessary
//     Map<DateTime, Duration> fetchedData = await getDailySleepDataFromFirestore();
//     setState(() {
//       sleepDurations.clear();
//       sleepDurations.addAll(fetchedData.values);
//     });
//   }
//
//
//   void initAccelerometer() {
//     userAccelerometerEvents.listen((UserAccelerometerEvent event) {
//       setState(() {
//         detectSleep(event);
//       });
//     });
//   }
//
//   Map<DateTime, int> disturbanceData = {};
//
//
//   void detectSleep(UserAccelerometerEvent event) {
//     double magnitude = (event.x * event.x) + (event.y * event.y) + (event.z * event.z);
//
//     if (magnitude < sleepThreshold) {
//       setState(() {
//         if (!previousSleepState) {
//           sleepStartTime = DateTime.now();
//           previousSleepState = true;
//           // Stop the previous timer if any, and start a new timer to update sleep duration and disturbance count every minute.
//           if (timer != null) timer!.cancel();
//           timer = Timer.periodic(Duration(minutes: 1), (timer) {
//             setState(() {});
//           });
//         }
//         isSleeping = true;
//       });
//     } else {
//       setState(() {
//         if (previousSleepState) {
//           sleepEndTime = DateTime.now();
//           if (sleepStartTime != null && sleepEndTime != null) {
//             Duration sleepDuration = sleepEndTime!.difference(sleepStartTime!);
//             int sleepDurationInMinutes = sleepDuration.inMinutes;
//             if (sleepDurationInMinutes >= 2) {
//               sleepDurations.add(sleepDuration);
//               sleepDurationsInMinutes.add(sleepDurationInMinutes);
//               disturbanceData[sleepStartTime!] = disturbanceCounter; // Store the disturbance count for the current sleep session
//               disturbanceCounter = 0; // Reset the disturbance counter
//             }
//             // Cancel the timer once the user wakes up.
//             if (timer != null) timer!.cancel();
//           }
//         }
//         isSleeping = false;
//       });
//       previousSleepState = false;
//     }
//   }
//
//   Timer? timer;
//
//   String formatTime(DateTime time) {
//     return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
//   }
//
//   String formatDuration(Duration duration) {
//     return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: Scaffold(
//         appBar: AppBar(
//           backgroundColor: Color(0xFF233C67), // Set the background color to #233C67
//           leading: IconButton( // Add a back icon button to the left
//             icon: Icon(Icons.arrow_back),
//             onPressed: () {
//               Navigator.pop(context);
//             },
//           ),
//           title: Text('Current Sleep Data'),
//           actions: [ // Add the "All Data" button to the app bar
//             IconButton(
//               icon: Icon(Icons.data_usage),
//               onPressed: () {
//                 // Navigate to the AllDataPage when the "All Data" button is clicked
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => AllDataPage(),
//                   ),
//                 );
//               },
//             ),
//           ],
//
//         ),
//         body: Padding(
//           padding: const EdgeInsets.all(12.0), // Add 12px space below the app bar
//           child: Center(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Text(
//                   isSleeping ? 'Sleeping' : 'Awake',
//                   style: TextStyle(fontSize: 24),
//                 ),
//                 SizedBox(height: 20),
//                 Text(
//                   isSleeping
//                       ? 'Time started sleeping: ${formatTime(sleepStartTime!)}'
//                       : 'Time started sleeping: -',
//                   style: TextStyle(fontSize: 18),
//                 ),
//                 SizedBox(height: 10),
//                 Text(
//                   isSleeping ? 'Time slept: ${formatDuration(getSleepDuration())}' : 'Time slept: -',
//                   style: TextStyle(fontSize: 18),
//                 ),
//                 SizedBox(height: 10),
//                 Text(
//                   'Total Time Slept: ${formatDuration(getTotalSleepDuration())}',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                 ),
//                 SizedBox(height: 20),
//                 Text(
//                   'Sleep Disturbances: ${sleepDurationsInMinutes.length}',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                 ),
//                 SizedBox(height: 10),
//                 Text(
//                   'Sleep durations:',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                 ),
//                 Column(
//                   children: sleepDurationsInMinutes.map((durationInMinutes) {
//                     return Text(
//                       formatDuration(Duration(minutes: durationInMinutes)),
//                       style: TextStyle(fontSize: 16),
//                     );
//                   }).toList(),
//                 ),
//
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//
//   Duration getTotalSleepDuration() {
//     return sleepDurations.fold(Duration.zero, (previous, current) => previous + current);
//   }
//
//   Duration getSleepDuration() {
//     if (sleepStartTime != null && isSleeping) {
//       DateTime currentTime = DateTime.now();
//       return currentTime.difference(sleepStartTime!);
//     }
//     return Duration.zero;
//   }
//
//   @override
//   void dispose() {
//     timer?.cancel();
//     super.dispose();
//   }
//
//   Map<DateTime, Duration> getDailySleepData() {
//     Map<DateTime, Duration> dailySleepData = {};
//
//     for (int i = 0; i < sleepDurations.length; i++) {
//       DateTime sleepDate = sleepStartTime!.add(sleepDurations[i]);
//       DateTime startOfDay = DateTime(sleepDate.year, sleepDate.month, sleepDate.day, 18, 0);
//       DateTime endOfDay = DateTime(sleepDate.year, sleepDate.month, sleepDate.day + 1, 21, 59);
//
//       if (sleepDate.isAfter(startOfDay) && sleepDate.isBefore(endOfDay)) {
//         dailySleepData.update(
//           DateTime(sleepDate.year, sleepDate.month, sleepDate.day),
//               (value) => value + sleepDurations[i],
//           ifAbsent: () => sleepDurations[i],
//         );
//       }
//     }
//
//     return dailySleepData;
//   }
//
//
//   Future<void> saveDailySleepData(Map<DateTime, Duration> dailySleepData, Map<DateTime, int> disturbanceData) async {
//     FirebaseFirestore firestore = FirebaseFirestore.instance;
//     CollectionReference sleepDataCollection = firestore.collection('sleep_data');
//
//     dailySleepData.forEach((date, duration) async {
//       await sleepDataCollection.doc(date.toString()).set({
//         'date': date.toString(),
//         'duration_in_minutes': duration.inMinutes,
//         'disturbances': disturbanceData[date], // Store the number of disturbances for the current date
//       });
//     });
//   }
//
//
//   Future<Map<DateTime, Duration>> getDailySleepDataFromFirestore() async {
//     FirebaseFirestore firestore = FirebaseFirestore.instance;
//     CollectionReference sleepDataCollection = firestore.collection('sleep_data');
//
//     QuerySnapshot snapshot = await sleepDataCollection.get();
//
//     Map<DateTime, Duration> dailySleepData = {};
//
//     snapshot.docs.forEach((doc) {
//       Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
//       if (data != null) {
//         DateTime? date = DateTime.tryParse(data['date'] ?? '');
//         int? durationInMinutes = data['duration_in_minutes'];
//
//         if (date != null && durationInMinutes != null) {
//           dailySleepData[date] = Duration(minutes: durationInMinutes);
//         }
//       }
//     });
//
//     return dailySleepData;
//   }
//
// }
//
