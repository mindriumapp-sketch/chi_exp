// ─────────────────────────  Dart Std  ─────────────────────────
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

// ─────────────────────────  Flutter  ──────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;

// ─────────────────────  3rd‑party Packages  ───────────────────
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:geolocator/geolocator.dart';
import 'package:geofence_service/geofence_service.dart' as gf;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────  Local  ────────────────────────────
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/app.dart';

/// ───────────────────────── MODELS ─────────────────────────
enum RepeatOption { none, daily, weekly }

class NotificationSetting {
  // final DateTime startDate;
  final RepeatOption repeatOption; 
  final List<int> weekdays; 
  final TimeOfDay? time;
  final String? location;
  final double? latitude;
  final double? longitude;
  final int? reminderMinutes;
  final String? description; 
  final String? id;
  final String? abcId;
  final DateTime savedAt;
  final String? cause;
  final bool notifyEnter;
  final bool notifyExit;

  NotificationSetting({
    this.cause,
    this.time,
    // DateTime? startDate,
    this.repeatOption = RepeatOption.none,
    this.weekdays = const [],
    this.location,
    this.latitude,
    this.longitude,
    this.description,
    this.reminderMinutes,
    this.id,
    this.abcId,
    DateTime? savedAt,
    required this.notifyEnter,
    required this.notifyExit,
  })  : //startDate = startDate ?? DateTime.now(),
        savedAt = savedAt ?? DateTime.now();

  Map<String, dynamic> toJson({bool includeSavedAt = true}) {
    final map = <String, dynamic>{
      // 'startDate': Timestamp.fromDate(startDate),
      'reminderMinutes': reminderMinutes,
    };
    if (includeSavedAt) {
      map['savedAt'] = Timestamp.fromDate(savedAt);
    }

    if (abcId != null) map['abcId'] = abcId;
    debugPrint('[NOTI] abcId=$abcId');

    // ── 시간(시각) 정보 ──
    if (time != null) {
      map['time'] =
          '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}';
      map['repeatOption'] = repeatOption.name;
      if (repeatOption == RepeatOption.weekly && weekdays.isNotEmpty) {
        map['weekdays'] = weekdays;
      }
    }

    // ── 위치(좌표) 정보 ──
    if (latitude != null && longitude != null) {
      map
        ..['latitude'] = latitude
        ..['longitude'] = longitude
        ..['location'] = location;
      if (description != null) {
        map['description'] = description;
      }
    }
    if (cause != null) {
      map['cause'] = cause;
    }
    // Location timing flags
    map['notifyEnter'] = notifyEnter;
    map['notifyExit']  = notifyExit;
    return map;
  }

  

  /// Same as [toJson] but kept for backward‑compat. UI 코드에서 사용됩니다.
  Map<String, dynamic> toMap({bool includeSavedAt = true}) =>
      toJson(includeSavedAt: includeSavedAt);

  factory NotificationSetting.fromJson(Map<String, dynamic> json,
      {String? id,}) {
    TimeOfDay? tod;
    // DateTime sd = DateTime.now();
    RepeatOption ro = RepeatOption.none;
    List<int> wd = [];
    final int? rm = json['reminderMinutes'] as int?;
    // 시간 관련 필드 (method 관계없이 존재하면 파싱)
    if (json['time'] != null) {
      final p = (json['time'] as String).split(':');
      tod = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    }
    // if (json['startDate'] != null) {
    //   sd = (json['startDate'] as Timestamp).toDate();
    // }
    if (json['repeatOption'] != null) {
      ro = RepeatOption.values
          .firstWhere((e) => e.name == json['repeatOption']);
    }
    if (ro == RepeatOption.weekly && json['weekdays'] is List) {
      wd = List<int>.from(json['weekdays']);
    }
    return NotificationSetting(
      time: tod,
      // startDate: sd,
      repeatOption: ro,
      weekdays: wd,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      location: json['location'] as String?,
      cause: json['cause'] as String?,
      description: json['description'] as String?,
      id: id,
      abcId: json['abcId'] as String?,
      reminderMinutes: rm,
      savedAt: (json['savedAt'] as Timestamp?)?.toDate(),
      notifyEnter: json['notifyEnter'] as bool? ?? false,
      notifyExit: json['notifyExit'] as bool? ?? false,
    );
  }

  /// Firestore 문서 -> NotificationSetting (id 포함)
factory NotificationSetting.fromDoc(DocumentSnapshot doc) {
  final parent = doc.reference.parent.parent;         
  final setting = NotificationSetting.fromJson(
    doc.data() as Map<String, dynamic>,
    id: doc.id,
  );
  return setting.copyWith(abcId: parent?.id);
}
}

/// ───────────────────────── PROVIDER ─────────────────────────
class NotificationProvider extends ChangeNotifier {
  static final NotificationProvider _inst = NotificationProvider._internal();
  factory NotificationProvider() => _inst;
  NotificationProvider._internal() {
    _ready = _init();
  }

  late final Future<void> _ready;
  NotificationSetting? _current;
  NotificationSetting? get current => _current;
  bool _educationOk = false; // completed_education >= 3 ?

  final _fln = FlutterLocalNotificationsPlugin();
  final _geofence = gf.GeofenceService.instance.setup(
    interval: 60000,
    accuracy: 100,
    loiteringDelayMs: 10000,
  );

  // 위치+시간 전용 스케줄 타이머 저장
  final List<Timer> _locationTimeTimers = [];

  /* ─────────── 초기화 ─────────── */
  Future<void> _init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    // ★ Ask for all required permissions at app start
    await _requestEssentialPermissions();

    await _fln.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        debugPrint('[NOTI] rawPayload=${resp.payload}');
        if (payload == null || !payload.startsWith('/') || navigatorKey.currentState == null) {
          return;
        }
        final uri = Uri.parse(payload);
        debugPrint('[NAV] path=${uri.path} params=${uri.queryParameters}');

        navigatorKey.currentState!.pushNamedAndRemoveUntil(
          uri.path,
          (r) => r.isFirst,
          arguments: uri.queryParameters.isEmpty ? null : uri.queryParameters,
        );
      },
    );

    // 앱이 알림 클릭으로 시작된 경우 라우트 처리
    final launchDetails = await _fln.getNotificationAppLaunchDetails();
    final initialResp   = launchDetails?.notificationResponse;
    final initialPayload = initialResp?.payload;

    if ((launchDetails?.didNotificationLaunchApp ?? false) &&
        initialPayload?.startsWith('/') == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final uri = Uri.parse(initialPayload!);
        navigatorKey.currentState?.pushNamed(
          uri.path,
          arguments: uri.queryParameters,
        );
      });
    }

    // await Geolocator.requestPermission();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      // 사용자의 학습 완료 단계 확인 (completed_education ≥ 3)
      try {
        final uDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final edu = (uDoc.data()?['completed_education'] ?? 0) as num;
        _educationOk = edu >= 3;
        debugPrint('[NOTI] completed_education=$edu -> enabled=$_educationOk');
      } catch (_) {
        _educationOk = false; // 오류 시 비활성화
      }

      if (!_educationOk) {
        notifyListeners(); // 상태만 알리고 얼리 리턴
        return;
      }

      final snap = await FirebaseFirestore.instance
          .collectionGroup('notification_settings')
          .get();

      DocumentSnapshot<Map<String, dynamic>>? latest;
      for (final d in snap.docs) {
        if (d.reference.path.contains('/users/$uid/')) {
          latest = d;
          break;
        }
      }

      if (latest != null) {
        _current = NotificationSetting.fromDoc(latest);
        await _applySetting(_current!);
      }
    }
    notifyListeners();
  }

  /* ─────────── 권한 헬퍼 ─────────── */
  Future<bool> _ensure(Permission p) async =>
      (await p.status).isGranted || (await p.request()).isGranted;

  /* ─────────── App‑startup permission batch ─────────── */
  Future<void> _requestEssentialPermissions() async {
    final perms = <Permission>[
      Permission.notification,
      Permission.scheduleExactAlarm,  
      Permission.activityRecognition,
      Permission.locationWhenInUse,
    ];
    for (final p in perms) {
      await _ensure(p);
    }
  }

  // Returns the notification_settings collection for a user's abcId.
  CollectionReference<Map<String, dynamic>> _abcNotiCol(
      String uid, String abcId) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('abc_models')
          .doc(abcId)
          .collection('notification_settings');

  /* ─────────── 새 알림 생성 ─────────── */
  Future<void> createAndSchedule(NotificationSetting setting, {required String abcId}) async {
    await _ready;
    if (!_educationOk) return;
    if (!await _ensure(Permission.notification)) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final NotificationSetting s = setting.copyWith(abcId: abcId);

    // (1) 이미 Firestore 문서가 있는지 먼저 확인 -----------------------------
    String? docId = setting.id;

    if (docId == null) {
      final dup = await _abcNotiCol(uid, abcId)
          .where('latitude', isEqualTo: setting.latitude)
          .where('longitude', isEqualTo: setting.longitude)
          .where('notifyEnter', isEqualTo: setting.notifyEnter)
          .where('notifyExit', isEqualTo: setting.notifyExit)
          .limit(1)
          .get();

      if (dup.docs.isNotEmpty) {
        // 기존 문서 → 업데이트
        docId = dup.docs.first.id;
        await _abcNotiCol(uid, abcId)
            .doc(docId)
            .set(setting.toJson(includeSavedAt: false), SetOptions(merge: true));
      } else {
        // 새 문서 → 추가
        final ref = await _abcNotiCol(uid, abcId).add(setting.toJson());
        docId = ref.id;
      }
    } else {
      // id 가 주어졌으면 그대로 업데이트
      await _abcNotiCol(uid, abcId)
          .doc(docId)
          .set(setting.toJson(includeSavedAt: false), SetOptions(merge: true));
    }

    // (2) 로컬 상태 & 알림 스케줄 ------------------------------------------
    _current = s.copyWith(id: docId);
    await _reSchedule(_current!);
    notifyListeners();
  }

  /// 외부(UI)에서 새 알림을 저장 + 스케줄링할 때 사용
  Future<void> createSchedule(NotificationSetting setting, {required String abcId}) =>
      createAndSchedule(setting, abcId: abcId);
// ───────────────────────── 기존 알림 업데이트 + 재스케줄 ─────────────────────────
  Future<void> updateAndSchedule(NotificationSetting setting, {required String abcId}) async {
    await _ready;                               // 초기화 보장
    if (!_educationOk) return;

    // 1) 문서 ID가 없으면 새로 추가
    if (setting.id == null) {
      await createAndSchedule(setting, abcId: abcId);
      return;
    }

    // Firestore 문서는 createAndSchedule 에서 처리됨.

    // 3) 로컬 상태 갱신 + 스케줄 다시 등록
    _current = setting;
    await _reSchedule(_current!);
    notifyListeners();
  }

  /// 외부(UI)에서 기존 알림을 갱신 + 재스케줄 할 때 사용
  Future<void> updateSchedule(NotificationSetting setting, {required String abcId}) =>
      updateAndSchedule(setting, abcId: abcId);

  /// ★ 시간만 수정
  Future<void> updateTimeOfDay(String abcId, String docId, TimeOfDay t) async {
    await _ready;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _abcNotiCol(uid, abcId)
        .doc(docId)
        .update({'time': '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'});

    _current = _current?.copyWith(time: t);
    await _reSchedule(_current!);
    notifyListeners();
  }

  /// ★ 위치 알림 설명만 수정
  Future<void> updateLocationDescription(String abcId, String docId, String desc) async {
    await _ready;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _abcNotiCol(uid, abcId)
        .doc(docId)
        .update({'description': desc});

    _current = _current?.copyWith(description: desc);
    notifyListeners();
  }

  // ───────────────────────── 스케줄 적용/갱신 ─────────────────────────
  Future<void> _reSchedule(NotificationSetting s) async {
    await _cancelAll();
    await _applySetting(s);
  }

  /// Applies a [NotificationSetting] by scheduling the appropriate notification(s)
  /// based on time, location, or both.
  Future<void> _applySetting(NotificationSetting s) async {
    if (!_educationOk) return; // 학습 단계 미충족 시 알림 미적용
    final hasTime   = s.time != null;
    final hasCoords = s.latitude != null && s.longitude != null;
    final hasAddr   = (s.location?.isNotEmpty ?? false);

    // ── 분기 ──
    if (hasTime && hasCoords) {
      // 위치 + 시간 → 지정 시각에 위치 검사
      _scheduleDailyLocationCheck(s.time!, s);
      return;
    }

    // 시간만
    if (hasTime) {
      await _scheduleDaily(s.time!, s);
      return;
    }

    // 위치만
    if (hasCoords) {
      await _startGeofenceLatLng(
        address: s.description ?? s.location ?? '',
        lat: s.latitude!,
        lng: s.longitude!,
        setting: s,
      );
    } else if (hasAddr) {
      await _startGeofenceFromAddress(s.location!, setting: s);
    }
  }

  // ─────────────────────────  Title / Body Helpers  ─────────────────────────
  String _titleFor(NotificationSetting? s) {
    // 모든 (리마인더 제외) 알림의 제목은 고정
    return '걱정 일기 알림';
  }

  String _bodyFor(NotificationSetting? s) {
    if (s?.cause != null && s!.cause!.trim().isNotEmpty) {
      // 원인(걱정 내용)이 있으면 그 내용을 강조
      return '"${s.cause}"에 대한 알림이에요!';
    }
    // 원인이 없으면 기본 문구
    return '불안에 대해 집중해 보세요!';
  }

  /// Returns the great‑circle distance between two lat/lng pairs **in metres**
  /// using the Haversine formula.
  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6_371_000; // metres
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.pow(math.sin(dLon / 2), 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  /// Degrees → Radians
  double _degToRad(double deg) => deg * math.pi / 180;

  /// Schedules a daily check at [tod] to determine if user is near a location.
  void _scheduleDailyLocationCheck(TimeOfDay tod, NotificationSetting s) {
    // calculate next trigger datetime
    final now = DateTime.now();
    DateTime next = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
    if (next.isBefore(now)) next = next.add(const Duration(days: 1));

    Duration wait = next.difference(now);
    _locationTimeTimers.add(Timer(wait, () async {
      // fetch current position
      try {
        final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.low));
        final dist = _haversineDistance(
            pos.latitude, pos.longitude, s.latitude!, s.longitude!);

        if (dist <= 100) {
          _showNow(
            title: _titleFor(s),
            body: _bodyFor(s),
            reminderMinutes: s.reminderMinutes,
          );
        }
      } catch (_) {
        // ignore location errors
      }
      // Re‑schedule tomorrow at the same time
      _scheduleDailyLocationCheck(tod, s);
    }));
  }

  // ───────────────────────── 시간 알림 스케줄 ─────────────────────────
  Future<void> _scheduleDaily(TimeOfDay tod, [NotificationSetting? s]) async {
    final now = tz.TZDateTime.now(tz.local);
    var first = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, tod.hour, tod.minute);
    if (first.isBefore(now)) first = first.add(const Duration(days: 1));

    final id = first.millisecondsSinceEpoch % 1000000000;
    final exact = await _ensure(Permission.scheduleExactAlarm);
    final reminderMinutes = s?.reminderMinutes;
    try {
      await _fln.zonedSchedule(
        id,
        _titleFor(s),
        _bodyFor(s),
        first,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_channel',
            'Daily Notification',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: '/before_sud?abcId=${s?.abcId ?? ''}',
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle
      );
      // Add reminder if needed
      if (reminderMinutes != null && reminderMinutes > 0) {
        final reminderDate = first.add(Duration(minutes: reminderMinutes));
        await _fln.zonedSchedule(
          id + 1,
          '다시 알림: ${_titleFor(s)}',
          '조금 전 알림을 다시 알려드려요.',
          tz.TZDateTime.from(reminderDate, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'daily_channel',
              'Daily Notification',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          payload: '/before_sud?abcId=${s?.abcId ?? ''}',
          androidScheduleMode: exact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle
          // no repeat for reminder
        );
      }
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') {
        await _fln.zonedSchedule(
          id,
          _titleFor(s),
          _bodyFor(s),
          first,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'daily_channel',
              'Daily Notification',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          payload: '/before_sud?abcId=${s?.abcId ?? ''}',
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle
        );
        // Add reminder if needed (fallback)
        if (reminderMinutes != null && reminderMinutes > 0) {
          final reminderDate = first.add(Duration(minutes: reminderMinutes));
          await _fln.zonedSchedule(
            id + 1,
            '다시 알림: ${_titleFor(s)}',
            '조금 전 알림을 다시 알려드려요.',
            tz.TZDateTime.from(reminderDate, tz.local),
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'daily_channel',
                'Daily Notification',
                importance: Importance.defaultImportance,
                priority: Priority.defaultPriority,
              ),
              iOS: DarwinNotificationDetails(),
            ),
            payload: '/before_sud?abcId=${s?.abcId ?? ''}',
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle
            // no repeat for reminder
          );
        }
      } else {
        rethrow;
      }
    }
    return;
  }

  // ───────────────────────── 지오펜스 ─────────────────────────
  Future<void> _startGeofenceFromAddress(String addr, {NotificationSetting? setting}) async {
    try {
      final key = vworldApiKey;
      final uri = Uri.parse(
        'http://api.vworld.kr/req/address'
        '?service=address&request=getcoord'
        '&address=${Uri.encodeComponent(addr)}'
        '&type=road&inputCoordSystem=WGS84GEO&output=json&key=$key',
      );
      final res = await http.get(uri);
      if (res.statusCode != 200) return;

      final j = json.decode(res.body) as Map<String, dynamic>;
      final p = j['response']?['result']?['point'] as Map<String, dynamic>?;
      final lat = double.tryParse(p?['y']?.toString() ?? '');
      final lng = double.tryParse(p?['x']?.toString() ?? '');
      if (lat == null || lng == null) return;

      await _startGeofenceLatLng(address: addr, lat: lat, lng: lng, setting: setting);
    } catch (_) {}
    return;
  }

  // 위치 도착/이탈 알림 (notifyEnter/notifyExit)
  Future<void> _startGeofenceLatLng({
    required String address,
    required double lat,
    required double lng,
    NotificationSetting? setting,
  }) async {
    if (!await _ensure(Permission.activityRecognition)) return;
    if (!await _ensure(Permission.locationWhenInUse)) return;

    final region = gf.Geofence(
      id: 'record_region',
      latitude: lat,
      longitude: lng,
      radius: [gf.GeofenceRadius(id: '100m', length: 100)],
    );
    final s = setting ?? _current;
    _geofence.addGeofenceStatusChangeListener((g, r, status, loc) async {
      // 위치 알림은 시간 조건과 무관하게 작동
      if (status == gf.GeofenceStatus.ENTER || status == gf.GeofenceStatus.DWELL) {
        if (s?.notifyEnter ?? true) {
          _showNow(
            title: _titleFor(s),
            body: _bodyFor(s),
            reminderMinutes: s?.reminderMinutes,
            abcId: s?.abcId,
          );
        }
      }

      if (status == gf.GeofenceStatus.EXIT && (s?.notifyExit ?? false)) {
        _showNow(
          title: _titleFor(s),
          body: _bodyFor(s),
          reminderMinutes: s?.reminderMinutes,
          abcId: s?.abcId,
        );
      }
    });
    await _geofence.start([region]);
    return; 
  }

  // ───────────────────────── 즉시 푸시 ─────────────────────────
  Future<void> _showNow({
    required String title, 
    required String body, 
    int? reminderMinutes,
    String? abcId,
  }) async {
    if (!_educationOk) return; // 학습 단계 미충족이면 즉시 알림도 무시
    final route = '/before_sud?abcId=${abcId ?? _current?.abcId ?? ''}';
    debugPrint('[NOTI] payload=$route'); 
    await _fln.show(
      DateTime.now().millisecondsSinceEpoch % 1000000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'instant_channel',
          'Instant Push',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: route
    );

    if (reminderMinutes != null && reminderMinutes > 0) {
      final when = DateTime.now().add(Duration(minutes: reminderMinutes));
      await _fln.zonedSchedule(
        DateTime.now().millisecondsSinceEpoch % 1000000 + 1,
        '다시 알림: $title',
        body,
        tz.TZDateTime.from(when, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'instant_channel',
            'Instant Push',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: route,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  // ───────────────────────── 취소 ─────────────────────────
  Future<void> _cancelAll() async {
    await _fln.cancelAll();
    await _geofence.stop();
    _geofence.clearAllListeners();
    _geofence.clearGeofenceList();
    for (final t in _locationTimeTimers) {
      t.cancel();
    }
    _locationTimeTimers.clear();
  }
  /* ─────────── 단일 스케줄 취소 ─────────── */
  /// 특정 알림 문서(id) 하나만 취소합니다.
  /// 🔹 [id]      : Firestore notification_settings 문서 ID  
  /// 🔹 [abcId]   : 상위 ABC 모델 ID (사용하지 않더라도 시그니처 유지)
  Future<void> cancelSchedule({
    required String id,
    required String abcId,
  }) async {
    await _ready;

    // id → int 로 변환 (hashCode 사용)  
    // 실제 스케줄 생성 시 hashCode 를 알림 ID로 썼다면 동일하게 대응 가능
    final int base = id.hashCode & 0x7fffffff;

    try {
      // 주 알림 + “다시 알림” 쌍( +1 ) 둘 다 취소
      await _fln.cancel(base);
      await _fln.cancel(base + 1);
    } catch (_) {
      // 이미 취소되었거나 존재하지 않는 경우 무시
    }

    // 현재 캐시에 같은 알림이 있으면 초기화
    if (_current?.id == id && _current?.abcId == abcId) {
      _current = null;
      notifyListeners();
    }
  }
  // ───────────────────────── 모든 스케줄 취소 ─────────────────────────
  /// ABC 상세 화면에서 “알림을 설정하지 않을래요” 체크 시 호출
  Future<void> cancelAllSchedules({required String abcId}) async {
    await _ready;          // 초기화 보장

    // 1) 등록된 모든 로컬 알림 & 지오펜스 취소
    await _cancelAll();

    // 2) 내부 캐시 초기화
    _current = null;
    notifyListeners();
  }
}

// 확장: 어디서든 사용할 수 있는 copyWith
extension NotificationSettingCopyExt on NotificationSetting {
  NotificationSetting copyWith({
    String? id,
    String? abcId,
    TimeOfDay? time,
    // DateTime? startDate,
    RepeatOption? repeatOption,
    List<int>? weekdays,
    double? latitude,
    double? longitude,
    String? location,
    int? reminderMinutes,
    String? description,
    String? cause,
    DateTime? savedAt,
    bool? notifyEnter,
    bool? notifyExit,
  }) {
    return NotificationSetting(
      id: id ?? this.id,
      abcId: abcId ?? this.abcId,
      time: time ?? this.time,
      // startDate: startDate ?? this.startDate,
      repeatOption: repeatOption ?? this.repeatOption,
      weekdays: weekdays ?? this.weekdays,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      location: location ?? this.location,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      description: description ?? this.description,
      cause: cause ?? this.cause,
      savedAt: savedAt ?? this.savedAt,
      notifyEnter: notifyEnter ?? this.notifyEnter,
      notifyExit:  notifyExit  ?? this.notifyExit,
    );
  }
}