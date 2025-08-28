import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gad_app_team/common/constants.dart';
// import 'package:gad_app_team/features/llm/abc_complete.dart';
import 'package:intl/intl.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_input_screen_chip.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_input_screen_text.dart';


class AbcModel {
  final String id;
  final dynamic activatingEvent;
  final dynamic belief;
  final dynamic cPhysical;
  final dynamic cEmotion;
  final dynamic cBehavior;
  final String? textDiary;
  final DateTime? completedAt;
  final DateTime? startedAt;
  final DateTime? updatedAt;

  AbcModel({
    required this.id,
    required this.activatingEvent,
    required this.belief,
    required this.cPhysical,
    required this.cEmotion,
    required this.cBehavior,
    required this.textDiary,
    required this.completedAt,
    required this.startedAt,
    required this.updatedAt,
  });

  factory AbcModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    dynamic normalizeField(dynamic v) {
      if (v == null) return '-';
      if (v is String) return v;
      if (v is List) return v.map((e) => e.toString()).toList();
      return v.toString();
    }

    DateTime? parseDate(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is String) return DateTime.tryParse(raw);
      return null;
    }

    return AbcModel(
      id: doc.id,
      activatingEvent: normalizeField(data['activatingEvent']),
      belief: normalizeField(data['belief']),
      cEmotion: normalizeField(data['c1_emotion']),
      cPhysical: normalizeField(data['c2_physical']),
      cBehavior: normalizeField(data['c3_behavior']),
      textDiary: (data['text_diary'] as String?)?.toString(),
      completedAt: parseDate(data['completedAt']),
      startedAt: parseDate(data['startedAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }
}

class AbcStreamList extends StatefulWidget {
  final String uid;
  final DateTimeRange? selectedRange;
  final VoidCallback? onPickDateRange;

  const AbcStreamList({super.key, required this.uid, this.selectedRange, this.onPickDateRange});

  @override
  State<AbcStreamList> createState() => _AbcStreamListState();
}

class _AbcStreamListState extends State<AbcStreamList> {
  Stream<QuerySnapshot> _getStream() {
    final base = FirebaseFirestore.instance
        .collection('chi_users')
        .doc(widget.uid)
        .collection('abc_models');

    if (widget.selectedRange != null) {
      // Normalize to [start-of-day, next-day-start) to include the whole end date
      final start = DateTime(
        widget.selectedRange!.start.year,
        widget.selectedRange!.start.month,
        widget.selectedRange!.start.day,
      );
      final endExclusive = DateTime(
        widget.selectedRange!.end.year,
        widget.selectedRange!.end.month,
        widget.selectedRange!.end.day,
      ).add(const Duration(days: 1));

      return base
          .where('completedAt', isGreaterThanOrEqualTo: start)
          .where('completedAt', isLessThan: endExclusive)
          .snapshots();
    }
    return base.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];

        final items = docs.map(AbcModel.fromDoc).toList();
        int cmp(DateTime? a, DateTime? b) {
          final da = a ?? DateTime.fromMillisecondsSinceEpoch(0);
          final db = b ?? DateTime.fromMillisecondsSinceEpoch(0);
          return db.compareTo(da);
        }
        items.sort((x, y) {
          final c = cmp(x.completedAt, y.completedAt);
          if (c != 0) return c;
          final u = cmp(x.updatedAt, y.updatedAt);
          if (u != 0) return u;
          return cmp(x.startedAt, y.startedAt);
        });
        final total = docs.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  // 좌측: 일기 개수
                  Expanded(
                    child: Text(
                      '일기 $total개',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 우측: 날짜 필터 라벨 + 선택 버튼
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.selectedRange == null
                            ? '날짜 필터: 전체'
                            : '날짜 필터: ${DateFormat('yyyy-MM-dd').format(widget.selectedRange!.start)} ~ ${DateFormat('yyyy-MM-dd').format(widget.selectedRange!.end)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: '날짜 범위 선택',
                        icon: const Icon(Icons.calendar_today, size: 20),
                        onPressed: widget.onPickDateRange,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('저장된 일기가 없습니다'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                          AppSizes.padding, 0, AppSizes.padding, AppSizes.padding),
                      itemCount: items.length,
                      itemBuilder: (ctx, i) {
                        final model = items[i];
                        return _AbcCard(model: model, index: i + 1);
                      },
                      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _AbcCard extends StatefulWidget {
  final AbcModel model;
  final int index;
  const _AbcCard({required this.model, required this.index});

  @override
  State<_AbcCard> createState() => _AbcCardState();
}

class _AbcCardState extends State<_AbcCard> {
  bool _expanded = false;

  Widget _buildCardContent(AbcModel m) {
    final td = m.textDiary?.trim();
    if (td != null && td.isNotEmpty) {
      return Text(
        td,
        style: const TextStyle(fontSize: 16, color: Colors.black),
        textAlign: TextAlign.left,
      );
    }

    List<String> asList(dynamic v) {
      if (v == null) return const [];
      if (v is List) {
        return v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
      if (v is String) {
        final t = v.trim();
        return t.isEmpty ? const [] : [t];
      }
      return [v.toString()];
    }

    final situation = asList(m.activatingEvent).join(', ');
    final thought = asList(m.belief).join(', ');
    final emotion = asList(m.cEmotion).join(', ');
    final physical = asList(m.cPhysical).join(', ');
    final behavior = asList(m.cBehavior).join(', ');

    // Chip-style label used to highlight A/B/C headings inline
    WidgetSpan chipLabel(String text) => WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2 , vertical: 0),
            decoration: BoxDecoration(
              color: AppColors.indigo50,
            ),
            child: Text(
              text,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        );

    // Build narrative with highlighted labels
    final spans = <InlineSpan>[];

    // Line 1: A (상황)
    spans.add(const TextSpan(text: "오늘 나는 "));
    spans.add(chipLabel(situation.isNotEmpty ? situation : '-'));
    spans.add(const TextSpan(text: " (이)라는 일이 있었다."));

    // Line 2: B (생각)
    spans.add(const TextSpan(text: "\n그 상황에서 나는 "));
    spans.add(chipLabel(thought.isNotEmpty ? thought : '-'));
    spans.add(const TextSpan(text: " (이)라는 생각이 떠올랐고,\n"));

    // Line 3: C1 (감정)
    spans.add(chipLabel(emotion.isNotEmpty ? emotion : '-'));
    spans.add(const TextSpan(text: " (이)라는 감정을 느꼈다."));

    // Line 4: C2 (신체증상)
    spans.add(const TextSpan(text: "\n그 순간 몸에서 "));
    spans.add(chipLabel(physical.isNotEmpty ? physical : '-'));
    spans.add(const TextSpan(text: " (이)라는 변화가 있었고,"));

    // Line 5: C3 (행동)
    spans.add(const TextSpan(text: "\n나는 "));
    spans.add(chipLabel( behavior.isNotEmpty ? behavior : '-'));
    spans.add(const TextSpan(text: " (이)라는 행동을 했다."));

    return RichText(
      textAlign: TextAlign.left,
      text: TextSpan(
        style: const TextStyle(fontSize: 16, color: Colors.black),
        children: spans,
      ),
    );
  }

  Future<void> _onEdit(AbcModel m) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final fs = FirebaseFirestore.instance;
    final userDoc = fs.collection('chi_users').doc(uid);
    final docRef = userDoc.collection('abc_models').doc(m.id);
    final backupRef = userDoc.collection('abc_backup').doc(m.id);
    final startedAt = DateTime.now();

    // 기존 데이터 백업
    try {
      final snap = await docRef.get();
      final Map<String, dynamic>? data = snap.data();
      final backup = <String, dynamic>{
        ...?data,
        'backupAt': FieldValue.serverTimestamp(),
      };
      await backupRef.set(backup, SetOptions(merge: true));
    } catch (_) {}

    // 2) chi_users 코드 조회
    String? code;
    try {
      final userSnap = await userDoc.get();
      code = userSnap.data()?['code']?.toString();
    } catch (_) {}

    if (!mounted) return;

    // 3) 코드에 따라 편집 화면 이동
    if (code == '1234') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AbcInputTextScreen(
            abcId: m.id,
            startedAt: startedAt,
            isEditMode: true,
          ),
        ),
      );
    } else if (code == '7890') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AbcInputScreen(
            abcId: m.id,
            startedAt: startedAt,
            isEditMode: true,
          ),
        ),
      );
    } else {}
  }

  Future<void> _onDelete(AbcModel m) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제 확인'),
        content: const Text('선택한 일기를 삭제할까요? 이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final fs = FirebaseFirestore.instance;
    final userDoc = fs.collection('chi_users').doc(uid);
    final docRef = userDoc.collection('abc_models').doc(m.id);
    final backupRef = userDoc.collection('abc_backup').doc(m.id);

    try {
      final snap = await docRef.get();
      final Map<String, dynamic>? data = snap.data();
      final copy = <String, dynamic>{...?data, 'deletedAt': FieldValue.serverTimestamp()};

      final batch = fs.batch();
      batch.set(backupRef, copy, SetOptions(merge: true));
      batch.delete(docRef);
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('일기를 삭제했습니다.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('삭제 중 오류가 발생했습니다: $e')));
      }
    }
  }

  Widget _moreMenuButton(AbcModel m) {
    return PopupMenuButton<String>(
      tooltip: '옵션',
      onSelected: (value) {
        switch (value) {
          case 'edit':
            _onEdit(m);
            break;
          case 'delete':
            _onDelete(m);
            break;
        }
      },
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.grey.shade50,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          height: 20,
          child: Row(
            children: const [
              Icon(Icons.edit_outlined, size: 16, color: Colors.indigo),
              SizedBox(width: 8),
              Text('수정하기'),
            ],
          ),
        ),
        PopupMenuItem(
          enabled: false,
          height: 12,
          child: const Divider(),
        ),
        PopupMenuItem(
          value: 'delete',
          height: 20,
          child: Row(
            children: const [
              Icon(Icons.delete_outline, size: 16, color: Colors.red),
              SizedBox(width: 8),
              Text('삭제하기', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
      // Custom-styled trigger
      child: Container(
        padding: const EdgeInsets.fromLTRB(0,0,0,0),
        child: const Icon(Icons.more_vert, size: 20, color: Colors.black),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model;

    final titleDate = m.completedAt != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(m.completedAt!)
        : '작성 날짜 없음';
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    "${widget.index}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titleDate,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _expanded = !_expanded),
                        child: Text(_expanded ? '접기 ▲' : '펼치기 ▼'),
                      ),
                      _moreMenuButton(m),
                    ],
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    const SizedBox(height: 8),
                    _buildCardContent(m),
                    const SizedBox(height: 8),
                  ],
                ),
                crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 알림 목록 조회 및 편집 화면
class NotificationDirectoryScreen extends StatefulWidget {
  const NotificationDirectoryScreen({super.key});

  @override
  State<NotificationDirectoryScreen> createState() => _NotificationDirectoryScreenState();
}

class _NotificationDirectoryScreenState extends State<NotificationDirectoryScreen> {
  DateTimeRange? _selectedRange;

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialRange = DateTimeRange(
      start: now.subtract(const Duration(days: 10)),
      end: now,
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 14)),
      lastDate: now,
      initialDateRange: _selectedRange ?? initialRange,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: '기간 선택',
      cancelText: '취소',
      saveText: '적용',
      builder: (context, child) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360, maxHeight: 540),
            child: Theme(
              data: Theme.of(context).copyWith(
                dialogTheme: DialogTheme(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              child: child!,
            ),
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('로그인이 필요합니다')));
    }
    return Scaffold(
          backgroundColor: Colors.grey.shade100,
          body: SafeArea(
            child: AbcStreamList(
              uid: uid,
              selectedRange: _selectedRange,
              onPickDateRange: _pickDateRange,
            ),
          ),
        );

  }
}