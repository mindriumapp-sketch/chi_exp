import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/card_container.dart';
import 'package:intl/intl.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_input_screen_chip.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_input_screen_text.dart';

class AbcModel {
  final String id;
  final String activatingEvent;
  final String belief;
  final String cPhysical;
  final String cEmotion;
  final String cBehavior;
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
    DateTime? completedAt;
    final rawCompletedAt = (doc.data() as Map<String, dynamic>)['completedAt'];
    if (rawCompletedAt is Timestamp) {
      completedAt = rawCompletedAt.toDate();
    } else if (rawCompletedAt is String) {
      completedAt = DateTime.tryParse(rawCompletedAt);
    }
    DateTime? startedAt;
    final rawStartedAt = (doc.data() as Map<String, dynamic>)['startedAt'];
    if (rawStartedAt is Timestamp) {
      startedAt = rawStartedAt.toDate();
    } else if (rawStartedAt is String) {
      startedAt = DateTime.tryParse(rawStartedAt);
    }
    DateTime? updatedAt;
    final rawUpdatedAt = (doc.data() as Map<String, dynamic>)['updatedAt'];
    if (rawUpdatedAt is Timestamp) {
      updatedAt = rawUpdatedAt.toDate();
    } else if (rawUpdatedAt is String) {
      updatedAt = DateTime.tryParse(rawUpdatedAt);
    }
    return AbcModel(
      id: doc.id,
      activatingEvent: data['activatingEvent'] as String? ?? '-',
      belief: data['belief'] as String? ?? '-',
      cPhysical: data['c1_physical'] as String? ?? '-',
      cEmotion: data['c2_emotion'] as String? ?? '-',
      cBehavior: data['c3_behavior'] as String? ?? '-',
      completedAt: completedAt,
      startedAt: startedAt,
      updatedAt: updatedAt,
    );
  }
}

/// 공통 ABC 목록 위젯 – 편집 모드 유무만 넘겨주면 재사용 가능
class AbcStreamList extends StatelessWidget {
  final String uid;

  const AbcStreamList({
    super.key,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chi_users')
          .doc(uid)
          .collection('abc_models')
          .snapshots(),
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
                '총 $total개의 일기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold
                )
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                    AppSizes.padding, 0, AppSizes.padding, AppSizes.padding),
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final model = items[i];
                  return _AbcCard(model: model);
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
  const _AbcCard({required this.model});

  @override
  State<_AbcCard> createState() => _AbcCardState();
}

class _AbcCardState extends State<_AbcCard> {

  Future<void> _onEdit(AbcModel m) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final fs = FirebaseFirestore.instance;
    final userDoc = fs.collection('chi_users').doc(uid);
    final docRef = userDoc.collection('abc_models').doc(m.id);
    final backupRef = userDoc.collection('abc_backup').doc(m.id);
    final startedAt = DateTime.now();

    // 1) 기존 일기 백업 (삭제는 하지 않음)
    try {
      final snap = await docRef.get();
      final Map<String, dynamic>? data = snap.data();
      final backup = <String, dynamic>{
        ...?data,
        'backupAt': FieldValue.serverTimestamp(),
      };
      await backupRef.set(backup, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    }

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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
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

      // 백업 데이터: 기존 필드 + 메타 정보
      final copy = <String, dynamic>{
        ...?data,
        'deletedAt': FieldValue.serverTimestamp(),
      };

      final batch = fs.batch();
      batch.set(backupRef, copy, SetOptions(merge: true));
      batch.delete(docRef);
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일기를 삭제했습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 중 오류가 발생했습니다: $e')),
        );
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
        padding: const EdgeInsets.fromLTRB(0,12,8,0),
        child: const Icon(Icons.more_vert, size: 20, color: Colors.black),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.model.completedAt != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(widget.model.completedAt!)
        : '작성 날짜 없음';

    return Stack(
      children: [
        CardContainer(
          title: title,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 1, thickness: 1),
              const SizedBox(height: 12),
              _buildExpandedBody(),
            ],
          ),
        ),
        // 우측 상단 오버레이 (날짜 타이틀 영역 근처)
        Positioned(
          top: 4,
          right: 8,
          child: _moreMenuButton(widget.model),
        ),
      ],
    );
  }

  Widget _buildExpandedBody() {
    final m = widget.model;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _kv('A(상황)', m.activatingEvent),
        const SizedBox(height: 16),
        _kv('B(생각)', m.belief),
        const SizedBox(height: 16),
        _kvC('C(결과)', m.cPhysical, m.cEmotion, m.cBehavior),
      ],
    );
  }

  Widget _kv(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          textAlign: TextAlign.start,
          softWrap: true,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          value.isNotEmpty ? value : '-',
          textAlign: TextAlign.start,
          softWrap: true,
        ),
      ],
    );
  }

  Widget _kvC(String label, String cPhysical, String cEmotion, String cBehavior) {
    String safe(String s) => s.isNotEmpty ? s : '-';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          textAlign: TextAlign.start,
          softWrap: true,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text('신체 증상', style: TextStyle(fontWeight: FontWeight.bold),),
        Text(safe(cPhysical), textAlign: TextAlign.start, softWrap: true),
        const SizedBox(height: 8),
        Text('감정', style: TextStyle(fontWeight: FontWeight.bold),),
        Text(safe(cEmotion), textAlign: TextAlign.start, softWrap: true),
        const SizedBox(height: 8),
        Text('행동', style: TextStyle(fontWeight: FontWeight.bold),),
        Text(safe(cBehavior), textAlign: TextAlign.start, softWrap: true),
      ],
    );
  }
}

/// 알림 목록 조회 및 편집 화면
class NotificationDirectoryScreen extends StatefulWidget {
  const NotificationDirectoryScreen({super.key});

  @override
  State<NotificationDirectoryScreen> createState() =>
      _NotificationDirectoryScreenState();
}

class _NotificationDirectoryScreenState
    extends State<NotificationDirectoryScreen> {

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('로그인이 필요합니다')),
      );
    }
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: AbcStreamList(
                uid: uid,
              ),
            ),
          ],
        ),
      ),
    );
  }
}