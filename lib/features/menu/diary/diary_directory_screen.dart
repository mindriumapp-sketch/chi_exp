import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/card_container.dart';
import 'package:intl/intl.dart';
import 'package:gad_app_team/widgets/aspect_viewport.dart';

/// Firestore의 `abc_models` 문서를 화면용 모델로 매핑
class AbcModel {
  final String id;
  final String activatingEvent;
  final String belief;
  final String cPhysical;
  final String cEmotion;
  final String cBehavior;
  final DateTime? completedAt;

  AbcModel({
    required this.id,
    required this.activatingEvent,
    required this.belief,
    required this.cPhysical,
    required this.cEmotion,
    required this.cBehavior,
    required this.completedAt,
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
    return AbcModel(
      id: doc.id,
      activatingEvent: data['activatingEvent'] as String? ?? '-',
      belief: data['belief'] as String? ?? '-',
      cPhysical: data['c1_physical'] as String? ?? '-',
      cEmotion: data['c2_emotion'] as String? ?? '-',
      cBehavior: data['c3_behavior'] as String? ?? '-',
      completedAt: completedAt,
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
          .orderBy('completedAt', descending: true)
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

  @override
  Widget build(BuildContext context) {
    final title = widget.model.completedAt != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(widget.model.completedAt!)
        : '작성 날짜 없음';

    return CardContainer(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 12),
          _buildExpandedBody(),
        ],
      )
    );
  }

  Widget _buildExpandedBody() {
    final m = widget.model;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _kv('A(상황)', m.activatingEvent),
        const SizedBox(height: 8),
        _kv('B(생각)', m.belief),
        const SizedBox(height: 8),
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
          style: const TextStyle(fontWeight: FontWeight.w600),
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
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text('신체 증상: ${safe(cPhysical)}', textAlign: TextAlign.start, softWrap: true),
        const SizedBox(height: 4),
        Text('감정: ${safe(cEmotion)}', textAlign: TextAlign.start, softWrap: true),
        const SizedBox(height: 4),
        Text('행동: ${safe(cBehavior)}', textAlign: TextAlign.start, softWrap: true),
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
      body: AspectViewport(
        aspect: 9 / 16,
        background: Colors.grey.shade100,
        child:SafeArea(
        child: Column(
          children: [
            Expanded(
              child: AbcStreamList(
                uid: uid,
              ),
            ),
          ],
        ),
      ),)
    );
  }
}