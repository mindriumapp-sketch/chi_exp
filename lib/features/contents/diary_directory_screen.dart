import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/features/llm/abc_complete.dart';
import 'package:intl/intl.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_input_screen_chip.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_input_screen_text.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';

class AbcModel {
  final String id;
  final dynamic activatingEvent;
  final dynamic belief;
  final dynamic cPhysical;
  final dynamic cEmotion;
  final dynamic cBehavior;
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
      cPhysical: normalizeField(data['c1_physical']),
      cEmotion: normalizeField(data['c2_emotion']),
      cBehavior: normalizeField(data['c3_behavior']),
      completedAt: parseDate(data['completedAt']),
      startedAt: parseDate(data['startedAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }
}

class AbcStreamList extends StatefulWidget {
  final String uid;
  final DateTimeRange? selectedRange;

  const AbcStreamList({super.key, required this.uid, this.selectedRange});

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
      return base
          .where('completedAt', isGreaterThanOrEqualTo: widget.selectedRange!.start)
          .where('completedAt', isLessThanOrEqualTo: widget.selectedRange!.end)
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
        if (docs.isEmpty) {
          return const Center(child: Text('저장된 일기가 없습니다'));
        }

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
              padding: const EdgeInsets.all(16),
              child: Text(
                widget.selectedRange == null
                    ? '날짜 필터: 전체 ($total개)'
                    : '날짜 필터: ${DateFormat('yyyy-MM-dd').format(widget.selectedRange!.start)} ~ ${DateFormat('yyyy-MM-dd').format(widget.selectedRange!.end)} ($total개)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                    AppSizes.padding, 0, AppSizes.padding, AppSizes.padding),
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final model = items[i];
                  return _AbcCard(model: model, index: i + 1);
                },
                separatorBuilder: (ctx, i) => const SizedBox(height: 16),
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

    // 코드 확인
    String? code;
    try {
      final userSnap = await userDoc.get();
      code = userSnap.data()?['code']?.toString();
    } catch (_) {}

    if (!mounted) return;

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
    }
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

  @override
  Widget build(BuildContext context) {
    final m = widget.model;

    final titleDate = m.completedAt != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(m.completedAt!)
        : '작성 날짜 없음';

    String situationText = '-';
    if (m.activatingEvent is List && (m.activatingEvent as List).isNotEmpty) {
      situationText = (m.activatingEvent as List).first.toString();
    } else if (m.activatingEvent is String) {
      situationText = m.activatingEvent;
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          child: Row(
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
                      situationText,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      titleDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopupMenuButton<String>(
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
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('수정하기')),
                      const PopupMenuItem(value: 'delete', child: Text('삭제하기')),
                    ],
                    child: const Icon(Icons.more_vert, size: 20, color: Colors.black),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(_expanded ? '접기 ▲' : '펼치기 ▼'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_expanded)
          Container(
            margin: const EdgeInsets.only(top: 8, left: 4, right: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionBox('A (상황)', m.activatingEvent, Icons.event_note),
                const SizedBox(height: 16),
                _sectionBox('B (생각)', m.belief, Icons.psychology),
                const SizedBox(height: 16),
                _sectionCBox(m),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.indigo,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    icon: const Icon(Icons.analytics, color: Colors.white, size: 20),
                    label: const Text('리포트 보기',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      final userId = FirebaseAuth.instance.currentUser?.uid;
                      if (userId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AbcCompleteScreen(userId: userId, abcId: m.id),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  // 🔹 헬퍼 위젯들
  Widget _sectionBox(String title, dynamic value, IconData icon) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.indigo.shade50,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.indigo, size: 20),
            const SizedBox(width: 6),
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.indigo)),
          ],
        ),
        const SizedBox(height: 8),
        if (value is String)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [_chipBox(value)],
          )
        else if (value is List)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: value.map<Widget>((chip) => _chipBox(chip)).toList(),
          )
        else
          const Text('-'),
      ],
    ),
  );
}

Widget _sectionCBox(AbcModel m) {
  Widget render(String label, dynamic v, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.indigo, size: 18),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.indigo)),
            ],
          ),
          const SizedBox(height: 6),
          if (v is String)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [_chipBox(v)],
            )
          else if (v is List)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: v.map<Widget>((chip) => _chipBox(chip)).toList(),
            )
          else
            const Text('-'),
        ],
      ),
    );
  }

  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.indigo.shade50,  // ✅ A, B와 동일
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.summarize, color: AppColors.indigo, size: 20),
            SizedBox(width: 6),
            Text("C (결과)",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.indigo)),
          ],
        ),
        render("신체 증상", m.cPhysical, Icons.favorite),
        render("감정", m.cEmotion, Icons.mood),
        render("행동", m.cBehavior, Icons.directions_walk),
      ],
    ),
  );
}



  Widget _chipBox(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.indigo)),
    );
  }
}

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
      start: now.subtract(const Duration(days: 7)),
      end: now,
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _selectedRange ?? initialRange,
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
          appBar: CustomAppBar(
            title: "일기 목록",
            onBack: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',   // ✅ 홈 라우트로 이동
                (route) => false,
              );
            },
            extraIcon: Icons.calendar_today,
            onExtraPressed: _pickDateRange,
          ),
          body: SafeArea(
            child: AbcStreamList(uid: uid, selectedRange: _selectedRange),
          ),
        );

  }
}
