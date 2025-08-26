import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/features/llm/abc_complete.dart';
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

    String situationText = '-';
    if (m.activatingEvent is List && (m.activatingEvent as List).isNotEmpty) {
      situationText = (m.activatingEvent as List).first.toString();
    } else if (m.activatingEvent is String) {
      situationText = m.activatingEvent;
    }

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
                    SizedBox(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                          child: Column(
                          children: [
                            _sectionABox(m),
                            const SizedBox(height: 16),
                            _sectionBBox(m),
                            const SizedBox(height: 16),
                            _sectionCBox(m),
                          ],
                        ),
                      )
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.indigo,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

  // 🔹 헬퍼 위젯들

  Widget _sectionCBox(AbcModel m) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Circle badge 'C'
        CircleAvatar(
          backgroundColor: Colors.indigo.shade500,
          radius: 20,
          child: const Text(
            'C',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Right content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 신체
              const Row(
                children: [
                  SizedBox(width: 4),
                  Text(
                    '신체 증상',
                    style: TextStyle(
                      color: Colors.indigo,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _chipWidgets(m.cPhysical),
              ),

              const SizedBox(height: 10),

              // 감정
              const Row(
                children: [
                  SizedBox(width: 4),
                  Text(
                    '감정',
                    style: TextStyle(
                      color: Colors.indigo,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _chipWidgets(m.cEmotion),
              ),

              const SizedBox(height: 10),

              // 행동
              const Row(
                children: [
                  SizedBox(width: 4),
                  Text(
                    '행동',
                    style: TextStyle(
                      color: Colors.indigo,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _chipWidgets(m.cBehavior),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // A 섹션 (상황) — AbcCompact 스타일
  Widget _sectionABox(AbcModel m) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: Colors.indigo.shade100,
          radius: 20,
          child: const Text(
            'A',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '상황',
                style: TextStyle(
                  color: Colors.indigo,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _chipWidgets(m.activatingEvent),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // B 섹션 (생각) — AbcCompact 스타일
  Widget _sectionBBox(AbcModel m) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: Colors.indigo.shade300,
          radius: 20,
          child: const Text(
            'B',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '생각',
                style: TextStyle(
                  color: Colors.indigo,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _chipWidgets(m.belief),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 공용: dynamic 값을 칩 위젯 리스트로 변환
  List<Widget> _chipWidgets(dynamic v) {
    if (v == null) return [const Text('-')];
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? [const Text('-')] : [_autoChipBox(t)];
    }
    if (v is List) {
      final list = v
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      return list.isEmpty
          ? [const Text('-')]
          : list.map((chip) => _autoChipBox(chip)).toList();
    }
    return [const Text('-')];
  }

  Widget _autoChipBox(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12, width: 1),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w500,
          fontSize: 14,
          fontFamily: 'Pretendard',
        ),
      ),
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
      firstDate: now.subtract(const Duration(days: 10)),
      lastDate: now,
      initialDateRange: _selectedRange ?? initialRange,
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