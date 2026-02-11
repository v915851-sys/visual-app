import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';
import 'login_screen.dart';
import 'firebase_options.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Хранит текст ошибки инициализации Firebase (если она произошла)
String? _firebaseInitError;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool _firebaseInitialized = false;

  try {
    // Рекомендуемый способ для web: инициализация с опциями, сгенерированными FlutterFire
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _firebaseInitialized = true;
    } on UnsupportedError catch (_) {
      // Если DefaultFirebaseOptions не настроен (placeholder), попробуем дефолтную инициализацию (для мобильных платформ с google-services.json / plist)
      await Firebase.initializeApp();
      _firebaseInitialized = true;
    }
  } catch (e) {
    // ignore: avoid_print
    print('Firebase initialize error: $e');
    _firebaseInitError = e.toString();
  }

  // Если Firebase не инициализирован — показываем дружелюбный экран с инструкцией,
  // чтобы не было предупреждающего красного экрана '[core/no-app] No Firebase App...'
  if (!_firebaseInitialized) {
    runApp(MaterialApp(
      title: 'Ошибка Firebase',
      home: Scaffold(
        appBar: AppBar(title: const Text('Ошибка конфигурации Firebase')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 56, color: Colors.red),
                const SizedBox(height: 12),
                const Text(
                  'Firebase не настроен для этой платформы',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Для запуска на Web необходимо сгенерировать `firebase_options.dart`\nили добавить конфигурацию Firebase в `web/index.html`.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text('Подробно: run `flutterfire configure`\nили см. https://firebase.google.com/docs/web/setup', textAlign: TextAlign.center),
                const SizedBox(height: 18),
                if (_firebaseInitError != null)
                  Text('Ошибка: $_firebaseInitError', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    ));
    return;
  }

  // On web, check for a pending redirect sign-in result so redirect sign-ins complete.
  if (kIsWeb) {
    try {
      final redirectResult = await FirebaseAuth.instance.getRedirectResult();
      if (redirectResult.user != null) {
        print('Redirect sign-in successful for: ${redirectResult.user!.email}');
      }
    } catch (e) {
      print('getRedirectResult error: $e');
    }
  }

  runApp(const BibleAppYearly());
}

class BibleAppYearly extends StatelessWidget {
  const BibleAppYearly({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Библия за год',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const BibleHomeScreen(),
    );
  }
}

// Ежедневные библейские чтения на год
class DailyBibleReading {
  final int dayNumber;
  final String date;
  final String oldTestament;
  final String newTestament;
  final String psalm;
  bool isRead = false;

  DailyBibleReading({
    required this.dayNumber,
    required this.date,
    required this.oldTestament,
    required this.newTestament,
    required this.psalm,
  });
}

class BibleReadingsData {
  static final List<DailyBibleReading> readings = _generateYearlyReadings();

  static List<DailyBibleReading> _generateYearlyReadings() {
    final readings = <DailyBibleReading>[];
    final months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
                    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
    final daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

    final otBooks = [
      'Бытие', 'Исход', 'Левит', 'Числа', 'Второзаконие', 'Иисус Навин',
      'Судьи', 'Руфь', '1 Самуила', '2 Самуила', '1 Царств', '2 Царств',
      '1 Паралипоменон', '2 Паралипоменон', 'Ездра', 'Неемия', 'Есфирь',
      'Иов', 'Псалтирь', 'Притчи', 'Экклезиаст', 'Песнь Песней', 'Исаия',
      'Иеремия', 'Плач Иеремии', 'Иезекииль', 'Даниил', 'Осия', 'Иоиль',
      'Амос', 'Авдий', 'Иона', 'Михей', 'Наум', 'Аввакум', 'Софония',
      'Аггей', 'Захария', 'Малахия'
    ];

    final ntBooks = [
      'От Матфея', 'От Марка', 'От Луки', 'От Иоанна', 'Деяния', 'Послание Иакова',
      '1 Петра', '2 Петра', '1 Иоанна', '2 Иоанна', '3 Иоанна', 'Послание Иуды',
      'К Римлянам', '1 Коринфянам', '2 Коринфянам', 'К Галатам', 'К Ефесянам',
      'К Филиппийцам', 'К Колоссянам', '1 Фессалоникийцам', '2 Фессалоникийцам',
      '1 Тимофею', '2 Тимофею', 'К Титу', 'К Филимону', 'К Евреям', 'Откровение'
    ];

    int dayCounter = 1;
    int otBookIndex = 0;
    int ntBookIndex = 0;
    int otChapter = 1;
    int ntChapter = 1;
    int psalmStart = 1;

    for (int month = 0; month < 12; month++) {
      for (int day = 1; day <= daysInMonth[month]; day++) {
        if (dayCounter > 365) break;

        final otEndChapter = otChapter + (dayCounter % 3);
        final ntEndChapter = ntChapter + (dayCounter % 2);
        final psalmEnd = math.min(psalmStart + 2, 150);

        final date = '$day ${months[month]}';
        final otText = '${otBooks[otBookIndex]} $otChapter' + 
                       (otEndChapter > otChapter ? '-$otEndChapter' : '');
        final ntText = '${ntBooks[ntBookIndex]} $ntChapter' + 
                       (ntEndChapter > ntChapter ? '-$ntEndChapter' : '');
        final psalmText = psalmStart == psalmEnd 
                          ? 'Псалом $psalmStart'
                          : 'Псалом $psalmStart-$psalmEnd';

        readings.add(DailyBibleReading(
          dayNumber: dayCounter,
          date: date,
          oldTestament: otText,
          newTestament: ntText,
          psalm: psalmText,
        ));

        otChapter = otEndChapter + 1;
        ntChapter = ntEndChapter + 1;
        psalmStart = psalmEnd + 1;

        if (psalmStart > 150) psalmStart = 1;
        if (otChapter > 40) {
          otBookIndex++;
          otChapter = 1;
          if (otBookIndex >= otBooks.length) otBookIndex = 0;
        }
        if (ntChapter > 21) {
          ntBookIndex++;
          ntChapter = 1;
          if (ntBookIndex >= ntBooks.length) ntBookIndex = 0;
        }

        dayCounter++;
      }
      if (dayCounter > 365) break;
    }

    return readings;
  }
}

class BibleHomeScreen extends StatefulWidget {
  const BibleHomeScreen({Key? key}) : super(key: key);

  @override
  State<BibleHomeScreen> createState() => _BibleHomeScreenState();
}

class _BibleHomeScreenState extends State<BibleHomeScreen> {
  late List<DailyBibleReading> readings;
  int todayDayOfYear = 0;
  final Map<int, int> _durations = {}; // seconds per day
  int? _runningDay; // dayNumber currently timing
  Stopwatch? _stopwatch;
  Timer? _uiTimer;
  final ScrollController _listController = ScrollController();
  DateTime? _userStartDate; // дата начала плана (День 1)
  Timer? _notificationTimer; // таймер для периодических уведомлений
  StreamSubscription<DocumentSnapshot>? _progressSubscription; // подписка на прогресс в облаке

  @override
  void initState() {
    super.initState();
    readings = BibleReadingsData.readings;
    // set local date as fallback, then try to get online time and load saved data
    todayDayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays + 1;
    _initWithOnlineDate();
    
    // Показать уведомление о сегодняшнем чтении
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _showNotificationIfNeeded();
        
        // Если дата уже выбрана и планировщик не запущен, запустить его
        if (_userStartDate != null && _notificationTimer == null) {
          _setupNotificationScheduler();
        }
      });
    });
  }

  Future<void> _initWithOnlineDate() async {
    final online = await _determineOnlineDate();
    if (online != null) {
      setState(() {
        todayDayOfYear = online.difference(DateTime(online.year, 1, 1)).inDays + 1;
      });
    }
    
    // Загрузить сохранённые данные
    await _loadSavedData();
    
    // Если пользователь авторизован — загружаем прогресс и подписываемся
    if (FirebaseAuth.instance.currentUser != null) {
      await _onUserLoggedIn();
    } else {
      // Требовать авторизацию — показываем экран входа и очищаем стек
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => LoginScreen(onLoginSuccess: () async {
              await _onUserLoggedIn();
            }),
          ),
          (route) => false,
        );
      });
    }
    
    // Если пользователь ещё не выбрал дату начала плана, показать диалог
    if (_userStartDate == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDateSelectionDialog();
      });
    } else {
      // Если дата уже выбрана, запустить планировщик уведомлений
      _setupNotificationScheduler();
    }
  }

  Future<void> _showDateSelectionDialog() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        _userStartDate = pickedDate;
      });
      await _saveUserStartDate(pickedDate);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Дата начала установлена: ${DateFormat('d MMMM yyyy', 'ru').format(pickedDate)}')),
        );
      }
      // Рассчитать день плана и прокрутить к нему
      _scrollToTodayAfterDelay();
      
      // Запустить планировщик уведомлений
      _setupNotificationScheduler();
    }
  }

  Future<void> _saveUserStartDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_start_date', date.toIso8601String());
    
    // Сохранить в облако
    if (FirebaseAuth.instance.currentUser != null) {
      await _saveProgressToCloud();
    }
  }

  Future<void> _saveProgressToCloud() async {
    try {
      // Подготовить данные длительностей
      final durations = <String, int>{};
      _durations.forEach((key, value) {
        durations[key.toString()] = value;
      });

      // Подготовить статус прочитанного
      final isReadMap = <String, bool>{};
      for (int i = 0; i < readings.length; i++) {
        isReadMap[readings[i].dayNumber.toString()] = readings[i].isRead;
      }

      await FirebaseService.saveProgressToCloud(
        durations: durations,
        isReadStatus: isReadMap,
        userStartDate: _userStartDate,
      );
    } catch (e) {
      print('Error saving progress to cloud: $e');
    }
  }

  Future<void> _onUserLoggedIn() async {
    try {
      final data = await FirebaseService.loadProgressFromCloud();
      if (data == null) {
        // Нет данных в облаке — загружаем локальные данные в облако
        await _saveProgressToCloud();
      } else {
        final prog = data['progress'] as Map<String, dynamic>?;
        if (prog != null) {
          final durations = prog['durations'] as Map<String, dynamic>?;
          final isRead = prog['isRead'] as Map<String, dynamic>?;
          final userStartDateStr = prog['userStartDate'] as String?;
          final prefs = await SharedPreferences.getInstance();
          setState(() {
            if (durations != null) {
              durations.forEach((key, val) {
                final day = int.tryParse(key) ?? -1;
                if (day > 0) {
                  final sec = (val is int) ? val : int.tryParse(val.toString()) ?? 0;
                  _durations[day] = sec;
                  prefs.setInt('duration_$day', sec);
                }
              });
            }
            if (isRead != null) {
              isRead.forEach((key, val) {
                final day = int.tryParse(key) ?? -1;
                if (day > 0) {
                  final read = val == true || val.toString() == 'true';
                  readings[day - 1].isRead = read;
                  prefs.setBool('isRead_$day', read);
                }
              });
            }
            if (userStartDateStr != null) {
              _userStartDate = DateTime.tryParse(userStartDateStr);
              if (_userStartDate != null) {
                prefs.setString('user_start_date', _userStartDate!.toIso8601String());
              }
            }
          });
        }
      }

      _progressSubscription?.cancel();
      _progressSubscription = FirebaseService.getUserProgressStream().listen((doc) async {
        final cloudData = doc.data() as Map<String, dynamic>?;
        if (cloudData == null) return;
        final prog = cloudData['progress'] as Map<String, dynamic>?;
        if (prog == null) return;
        final durations = prog['durations'] as Map<String, dynamic>?;
        final isRead = prog['isRead'] as Map<String, dynamic>?;
        final userStartDateStr = prog['userStartDate'] as String?;
        final prefs = await SharedPreferences.getInstance();
        setState(() {
          if (durations != null) {
            durations.forEach((key, val) {
              final day = int.tryParse(key) ?? -1;
              if (day > 0) {
                final sec = (val is int) ? val : int.tryParse(val.toString()) ?? 0;
                if (sec > (_durations[day] ?? 0)) {
                  _durations[day] = sec;
                  prefs.setInt('duration_$day', sec);
                }
              }
            });
          }
          if (isRead != null) {
            isRead.forEach((key, val) {
              final day = int.tryParse(key) ?? -1;
              if (day > 0) {
                final read = val == true || val.toString() == 'true';
                if (read && !readings[day - 1].isRead) {
                  readings[day - 1].isRead = read;
                  prefs.setBool('isRead_$day', read);
                }
              }
            });
          }
          if (userStartDateStr != null) {
            final parsed = DateTime.tryParse(userStartDateStr);
            if (parsed != null) {
              _userStartDate = parsed;
              prefs.setString('user_start_date', _userStartDate!.toIso8601String());
            }
          }
        });
      });

      // Обновить UI и показать подтверждение входа пользователю
      if (mounted) {
        setState(() {});
        final email = FirebaseAuth.instance.currentUser?.email;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(email != null ? 'Вход выполнен как $email' : 'Вход выполнен')),
        );
      }
    } catch (e) {
      print('Error synchronizing progress: $e');
    }
  }

  int _calculateCurrentDayOfPlan() {
    if (_userStartDate == null) return 1;
    final today = DateTime.now();
    return _calculateDayFor(today);
  }

  // Helper to compute day-of-plan for any date (useful for tests)
  int _calculateDayFor(DateTime date) {
    if (_userStartDate == null) return 1;
    final startWithoutTime = DateTime(_userStartDate!.year, _userStartDate!.month, _userStartDate!.day);
    final todayWithoutTime = DateTime(date.year, date.month, date.day);
    final daysDiff = todayWithoutTime.difference(startWithoutTime).inDays;
    return (daysDiff + 1).clamp(1, 365);
  }

  void _scrollToTodayAfterDelay() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!_listController.hasClients) return;
        final dayOfPlan = _calculateCurrentDayOfPlan();
        final itemHeight = 90.0;
        final offset = (dayOfPlan - 1) * itemHeight;
        final max = _listController.position.maxScrollExtent;
        final scrollOffset = offset.clamp(0.0, max);
        _listController.animateTo(
          scrollOffset,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      });
    });
  }

  void _showNotificationIfNeeded() {
    if (_userStartDate == null) return;
    
    final currentDayOfPlan = _calculateCurrentDayOfPlan();
    if (currentDayOfPlan > readings.length) return;
    
    final today = readings[currentDayOfPlan - 1];
    if (today.isRead) return; // Уже прочитано, не показываем напоминание
    
    // Показать уведомление в приложении
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📖 Напоминание'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('День ${currentDayOfPlan} (${_getDateForPlanDay(currentDayOfPlan)})', 
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Сегодня нужно прочитать:'),
            const SizedBox(height: 8),
            Text('• ${today.oldTestament}'),
            Text('• ${today.newTestament}'),
            Text('• ${today.psalm}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Позже'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _scrollToTodayAfterDelay();
            },
            child: const Text('Начать читать'),
          ),
        ],
      ),
    );
  }

  void _setupNotificationScheduler() {
    // Проверять каждый час нужно ли показать напоминание
    _notificationTimer = Timer.periodic(const Duration(hours: 1), (_) {
      if (_userStartDate != null && mounted) {
        final currentDayOfPlan = _calculateCurrentDayOfPlan();
        if (currentDayOfPlan <= readings.length) {
          final today = readings[currentDayOfPlan - 1];
          if (!today.isRead) {
            // Показать диалоговое уведомление
            if (mounted) {
              _showNotificationIfNeeded();
            }
          }
        }
      }
    });
  }

  Future<DateTime?> _determineOnlineDate() async {
    try {
      final uri = Uri.parse('https://worldtimeapi.org/api/ip');
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final dtStr = data['datetime'] as String?;
        if (dtStr != null) {
          final dt = DateTime.parse(dtStr);
          return dt.toLocal();
        }
      }
    } catch (_) {
      // ignore and fallback to local time
    }
    return null;
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _listController.dispose();
    _notificationTimer?.cancel();
    _progressSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (var r in readings) {
        final keyDur = 'duration_${r.dayNumber}';
        final keyRead = 'isRead_${r.dayNumber}';
        _durations[r.dayNumber] = prefs.getInt(keyDur) ?? 0;
        r.isRead = prefs.getBool(keyRead) ?? false;
      }
      final running = prefs.getInt('running_day');
      if (running != null && running > 0) {
        prefs.remove('running_day');
      }
      
      // Загрузить сохранённую дату начала плана
      final savedDateStr = prefs.getString('user_start_date');
      if (savedDateStr != null) {
        _userStartDate = DateTime.parse(savedDateStr);
      }
    });
  }

  Future<void> _saveDuration(int dayNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('duration_$dayNumber', _durations[dayNumber] ?? 0);
    
    // Сохранить в облако
    if (FirebaseAuth.instance.currentUser != null) {
      await _saveProgressToCloud();
    }
  }

  Future<void> _saveIsRead(int dayNumber, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isRead_$dayNumber', value);
    
    // Сохранить в облако
    if (FirebaseAuth.instance.currentUser != null) {
      await _saveProgressToCloud();
    }
  }

  void toggleReadingStatus(int index) {
    setState(() {
      readings[index].isRead = !readings[index].isRead;
      _saveIsRead(readings[index].dayNumber, readings[index].isRead);
    });
  }

  void _startTimerForDay(int dayNumber) {
    if (_runningDay == dayNumber) return;
    if (_runningDay != null) _stopTimer();

    _runningDay = dayNumber;
    _stopwatch = Stopwatch()..start();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {});
    });
  }

  void _stopTimer() {
    if (_runningDay == null || _stopwatch == null) return;
    _stopwatch!.stop();
    final elapsed = _stopwatch!.elapsed.inSeconds;
    _durations[_runningDay!] = (_durations[_runningDay!] ?? 0) + elapsed;
    _saveDuration(_runningDay!);
    _stopwatch = null;
    _uiTimer?.cancel();
    _uiTimer = null;
    _runningDay = null;
    setState(() {});
  }

  String _getDateForPlanDay(int planDayNum) {
    if (_userStartDate == null) {
      return 'Дата не выбрана';
    }
    final dateForPlan = _userStartDate!.add(Duration(days: planDayNum - 1));
    final months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
                    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
    return '${dateForPlan.day} ${months[dateForPlan.month - 1]}';
  }

  String _formatDurationSeconds(int seconds) {
    final d = Duration(seconds: seconds);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.inHours}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📖 Библия за год', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade800, Colors.blue.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          // Яркая кнопка с информацией об аккаунте — сразу видно, вошли ли вы
          TextButton(
            onPressed: () {
              if (FirebaseAuth.instance.currentUser == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => LoginScreen(onLoginSuccess: _onUserLoggedIn),
                    fullscreenDialog: true,
                  ));
                });
              } else {
                final email = FirebaseAuth.instance.currentUser?.email ?? '—';
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Вход как $email')));
              }
            },
            child: Text(
              FirebaseAuth.instance.currentUser?.email ?? 'Войти',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'profile') {
                  if (FirebaseAuth.instance.currentUser == null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => LoginScreen(onLoginSuccess: _onUserLoggedIn),
                        fullscreenDialog: true,
                      ));
                    });
                  } else {
                    final email = FirebaseAuth.instance.currentUser?.email ?? '—';
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Аккаунт'),
                        content: Text('Email: $email'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ОК')),
                        ],
                      ),
                    );
                  }
                } else if (value == 'set_start') {
                  _showDateSelectionDialog();
                } else if (value == 'test_9feb') {
                  final testDate = DateTime(2026, 2, 9);
                  setState(() {
                    _userStartDate = testDate;
                  });
                  await _saveUserStartDate(testDate);
                  _scrollToTodayAfterDelay();
                  _setupNotificationScheduler();

                  final dayOn9 = _calculateDayFor(DateTime(2026, 2, 9));
                  final dayOn10 = _calculateDayFor(DateTime(2026, 2, 10));

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Тест: дата начала установлена: 9 фев 2026')),
                    );
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Результат теста'),
                        content: Text('9 фев 2026 → День $dayOn9\n10 фев 2026 → День $dayOn10'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ОК')),
                        ],
                      ),
                    );
                  }
                } else if (value == 'logout') {
                  await FirebaseService.signOut();
                  _progressSubscription?.cancel();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => LoginScreen(onLoginSuccess: () async {
                          await _onUserLoggedIn();
                        }),
                      ),
                      (route) => false,
                    );
                  });
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem(
                  value: 'profile',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.person, size: 20),
                        const SizedBox(width: 12),
                        Text(FirebaseAuth.instance.currentUser?.email ?? 'Аккаунт'),
                      ],
                    ),
                  ),
                ),
                PopupMenuItem(
                  value: 'set_start',
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20),
                      const SizedBox(width: 12),
                      const Text('Изменить дату начала'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'test_9feb',
                  child: Row(
                    children: const [
                      Icon(Icons.bug_report, size: 20),
                      SizedBox(width: 12),
                      Text('Тест: установить 9 фев 2026'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 20),
                      SizedBox(width: 12),
                      Text('Выход'),
                    ],
                  ),
                ),
              ],
              icon: CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.3),
                radius: 18,
                child: const Icon(Icons.account_circle, color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Карточка сегодняшнего чтения
            _buildTodayCard(),
            // Список всех чтений
            Expanded(
              child: _buildReadingsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayCard() {
    final currentDayOfPlan = _calculateCurrentDayOfPlan();
    
    if (currentDayOfPlan > readings.length) {
      return Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade400, Colors.green.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                const Text(
                  'Поздравляем!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Вы прочитали Библию за целый год!',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final today = readings[currentDayOfPlan - 1];
    final isCompleted = today.isRead;
    final baseSeconds = _durations[today.dayNumber] ?? 0;
    final runningSeconds = (_runningDay == today.dayNumber && _stopwatch != null)
        ? _stopwatch!.elapsed.inSeconds
        : 0;
    final totalSeconds = baseSeconds + runningSeconds;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCompleted 
            ? [Colors.green.shade400, Colors.green.shade600]
            : [Colors.blue.shade400, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isCompleted ? Colors.green.withOpacity(0.3) : Colors.blue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Сегодня читаем:',
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    if (_userStartDate != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'День ${currentDayOfPlan}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            _getDateForPlanDay(currentDayOfPlan),
                            style: const TextStyle(fontSize: 14, color: Colors.white70),
                          ),
                        ],
                      ),
                  ],
                ),
                Row(
                  children: [
                    Icon(
                      isCompleted ? Icons.check_circle : Icons.book,
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.calendar_today, color: Colors.white),
                      tooltip: 'Изменить дату начала',
                      onPressed: _showDateSelectionDialog,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildReadingTextCard('Ветхий Завет:', today.oldTestament),
            const SizedBox(height: 8),
            _buildReadingTextCard('Новый Завет:', today.newTestament),
            const SizedBox(height: 8),
            _buildReadingTextCard('Псалом:', today.psalm),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('⏱️ Время чтения', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(
                      _formatDurationSeconds(totalSeconds),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  icon: Icon(_runningDay == today.dayNumber ? Icons.stop : Icons.play_arrow),
                  label: Text(_runningDay == today.dayNumber ? 'Стоп' : 'Старт'),
                  onPressed: () {
                    if (_runningDay == today.dayNumber) {
                      _stopTimer();
                    } else {
                      _startTimerForDay(today.dayNumber);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: isCompleted ? Colors.green.shade600 : Colors.blue.shade600,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingTextCard(String label, String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingsList() {
    final currentDayOfPlan = _calculateCurrentDayOfPlan();
    
    return ListView.builder(
      controller: _listController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: readings.length,
      itemBuilder: (context, index) {
        final planDayNum = index + 1;
        final reading = readings[index];
        final isToday = planDayNum == currentDayOfPlan;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: isToday ? Colors.blue.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: isToday ? Colors.blue.shade50 : Colors.white,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: reading.isRead
                        ? [Colors.green.shade400, Colors.green.shade600]
                        : isToday
                            ? [Colors.blue.shade400, Colors.blue.shade600]
                            : [Colors.grey.shade300, Colors.grey.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    planDayNum.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              title: Text(
                'День $planDayNum - ${_getDateForPlanDay(planDayNum)}',
                style: TextStyle(
                  fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                  fontSize: 14,
                  color: isToday ? Colors.blue.shade800 : Colors.black87,
                  decoration: reading.isRead ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: Text(
                '${reading.oldTestament}, ${reading.newTestament}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: reading.isRead ? Colors.grey : Colors.grey.shade600,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formatDurationSeconds(_durations[reading.dayNumber] ?? 0),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      reading.isRead ? Icons.check_circle : Icons.circle_outlined,
                      color: reading.isRead ? Colors.green : Colors.grey.shade400,
                      size: 24,
                    ),
                    onPressed: () => toggleReadingStatus(index),
                    padding: const EdgeInsets.all(0),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              onTap: () {
                _showReadingDetails(reading, planDayNum);
              },
            ),
          ),
        );
      },
    );
  }

  void _showReadingDetails(DailyBibleReading reading, int planDayNum) {
    final secondsForDay = _durations[reading.dayNumber] ?? 0;
    final runningForDay = (_runningDay == reading.dayNumber && _stopwatch != null)
        ? _stopwatch!.elapsed.inSeconds
        : 0;
    final displaySeconds = secondsForDay + runningForDay;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [Colors.blue.shade50, Colors.blue.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'День $planDayNum',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getDateForPlanDay(planDayNum),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildReadingTextCard('Ветхий Завет', reading.oldTestament),
                    const SizedBox(height: 12),
                    _buildReadingTextCard('Новый Завет', reading.newTestament),
                    if (reading.psalm.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildReadingTextCard('Псалмы', reading.psalm),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade300, width: 1),
                      ),
                      child: Text(
                        'Время чтения: ${_formatDurationSeconds(displaySeconds)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(
                              _runningDay == reading.dayNumber
                                  ? Icons.pause_circle
                                  : Icons.play_circle,
                            ),
                            label: Text(
                              _runningDay == reading.dayNumber ? 'Стоп' : 'Старт',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              if (_runningDay == reading.dayNumber) {
                                _stopTimer();
                              } else {
                                _startTimerForDay(reading.dayNumber);
                              }
                              Navigator.pop(context);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Сброс'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade500,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () async {
                              _durations[reading.dayNumber] = 0;
                              await _saveDuration(reading.dayNumber);
                              setState(() {});
                              Navigator.pop(context);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.close),
                            label: const Text('Закрыть'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
