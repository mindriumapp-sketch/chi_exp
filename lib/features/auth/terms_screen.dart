import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/aspect_viewport.dart';

/// 약관 동의 화면
class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool agreedTerms = false;
  bool agreedPrivacy = false;
  bool agreedSensitive = false;

//   // ===== 약관/정책 전문 (요약 포함) =====
//   final String _termsContent = '''
// [이용약관 요약]
// - 본 서비스는 ABC 모델 기반 감정일기 연구용 소프트웨어입니다.
// - 의료 상담·진단·치료 서비스를 제공하지 않습니다. 위기 시 112/119 또는 1393(자살예방상담) 등 긴급 서비스를 이용하세요.
// - 만 19세 이상만 이용 가능합니다.

// [전문]
// 1) 목적과 성격
// 본 서비스(이하 "서비스")는 UI 입력 방식(자유 텍스트 vs 사용자 정의 칩)이 감정일기 기록 행동 및 경험에 미치는 영향을 탐구하기 위한 연구용 서비스입니다. 의료적 판단·진단을 제공하지 않습니다.

// 2) 계정 및 보안
// 이메일/비밀번호 등 계정 정보는 이용자가 관리합니다. 타인 정보 도용 또는 허위정보 가입은 금지됩니다.

// 3) 제공 범위
// - ABC 구조(사건·생각·감정·신체증상·행동) 일기 작성 및 목록 열람
// - 튜토리얼/가이드
// - 실험 조건에 따라 2가지 입력 조건 중 1종 제공
// - LLM 보조 입력 기능은 선택 제공

// 4) 금지행위
// 불법·유해정보 게시, 타인권리 침해, 서비스 방해(과도한 스크래핑·리버스엔지니어링 등), 연구 왜곡 목적의 허위 대량 입력을 금지합니다.

// 5) 데이터 활용(연구 목적)
// 서비스 이용 중 생성되는 데이터는 개인정보 처리방침과 동의 범위 내에서 가명·익명 처리 후 연구 분석·학술 발표·논문 게재에 활용될 수 있습니다.

// 6) 책임 제한
// 서비스는 연구용 시제품으로 중단·오류·기능 변경이 발생할 수 있습니다. 본 서비스를 근거로 한 의사결정 결과에 대해 책임을 지지 않습니다.

// 7) 해지/정지
// 이용자는 언제든 계정을 삭제할 수 있습니다. 약관 위반 또는 연구 왜곡 우려 시 이용을 제한·해지할 수 있습니다.

// 8) 약관 변경
// 중요한 변경은 시행 7일 전 공지합니다. 변경 후 계속 이용 시 동의한 것으로 간주합니다.

// 9) 준거법·분쟁
// 본 연구는 대한민국법을 준거법으로 진행합니다.

// 10) 연락처·시행일
// 운영자: 성균관대학교 대학원 LAMDA Lab  이메일: Mindriumapp@gmail.com  전화: 010-8793-8165
// 시행일: 2025.08.20
// ''';

//   final String _privacyContent = '''
// [개인정보 처리방침 요약]
// - 목적: 회원관리, 서비스 제공(일기/알림), 연구 데이터 생성 및 분석
// - 항목: 이메일, 닉네임, 나이대, 사용 로그(작성 빈도/시간/길이/이벤트), 기기·브라우저 정보
// - 민감정보(정신건강 설문·일기 내용)는 별도 동의 후 처리
// - 보유기간: 연구 종료 후 1년

// [전문]
// 1) 처리 목적
// 회원관리·인증, 서비스 제공(일기 저장·목록·알림), 연구 수행(통계·학술 발표, 가명·익명 처리), 서비스 개선(집계 분석·오류 모니터링).

// 2) 수집 항목
// - 필수: 이메일, 비밀번호(해시), 닉네임, 나이대/만나이, 가명키, 사용 로그(작성 빈도·일수, 시작~저장 시각, 입력 길이, 편집 이벤트, 알림 로그, 접속 IP, 기기/OS/브라우저, 쿠키)
// - 민감정보(별도 동의): GAD-7, PHQ-9, 일기 내용(ABC)
// - 선택: 선호 디바이스, 타이핑 숙련도, 기존 일기 습관, 온보딩 피드백 등

// 3) 보유기간
// 연구 종료 후 1년 보관 후 지체 없이 파기(법령·IRB 기준에 따름). 동의 철회/삭제 요청 시 허용 범위 내 파기 또는 가명·익명화.

// 4) 제3자 제공/위탁
// 원칙적으로 동의 없이 제공하지 않습니다. 클라우드/로그/LLM 보조 입력 등은 위탁할 수 있으며, 보안·재위탁 제한을 계약에 명시합니다. 법령 요청 또는 긴급 안전 사유는 예외.

// 5) 국외 이전(해외)
// 서버 또는 LLM 처리 서버가 해외인 경우 이전받는 자/국가/항목/보유기간을 고지하고 동의를 받습니다. 동의 거부 시 해당 기능이 제한될 수 있습니다.

// 6) 이용자 권리
// 열람·정정·삭제·처리정지·동의철회 권리가 있으며, 이메일(mindriumapp@gmail.com)을 통해 요청할 수 있습니다.

// 7) 안전성 확보 조치
// 전송구간 암호화(TLS), 암호화 저장, 접근통제(RBAC 최소권한), 접근기록 보관/점검, 침해사고 대응, 정기 취약점 점검, 가명·익명 처리.

// 8) 파기
// 전자파일은 복구 불가 방식으로, 문서는 분쇄/소각으로 파기합니다. 백업본은 순차 파기됩니다.

// 9) 문의/시행일
// 개인정보 보호책임자: 성균관대학교 대학원 LAMDA Lab  이메일: mindriumapp@gmail.com  전화: 010-8793-8165
// 시행일: 2025.08.20
// ''';

//   final String _sensitiveConsent = '''
// [민감정보 처리 동의]
// 1) 처리 대상: 정신건강 관련 설문(GAD-7, PHQ-9), 일기 내용(ABC: 사건·생각·감정·신체증상·행동)
// 2) 처리 목적: 입력 방식에 따른 사용자 경험/행동 분석 및 연구 수행(가명·익명 처리 후 통계·학술 발표)
// 3) 보유기간: 연구 종료 후 1년
// 4) 제3자 제공/위탁/국외 이전: 개인정보 처리방침의 규정과 동일(필요 시 사전 고지 및 동의)
// 5) 권리: 동의 거부·철회 가능(단, 기능/연구 참여가 제한될 수 있음)
// ''';

  // ===== 카드 요약 동의문 =====
  final String _termsSummary = '''
- 서비스 이용약관 동의
- 연구용 서비스임을 이해했으며, 응급·진단 목적 서비스가 아님을 확인
- 만 19세 이상이며 본인의 정보로 가입
- 연구 결과 공개(학술 발표/논문) 시 익명 가공 데이터 활용 동의
''';
  final String _privacySummary = '''
- 개인정보 수집·이용 동의 (목적: 회원관리, 서비스 제공(일기/알림), 연구 데이터 생성)
- 수집 항목: 이메일, 닉네임, 나이대, 사용 로그(작성 빈도·시간·길이·이벤트), 기기/브라우저 정보
- 보유기간: 연구 종료 후 1년
- 해외 이전/외부 AI 보조 입력 위탁/2차 연구 활용 동의는 별도 선택
''';
  final String _sensitiveSummary = '''
- 처리 대상: GAD-7/PHQ-9 및 일기 내용(ABC)
- 처리 목적: 입력 방식 효과 분석 및 연구(가명·익명 처리 후 통계·학술 발표)
- 보유기간: 연구 종료 후 최대 1년
- 동의는 언제든 철회 가능(일부 기능/연구 참여 제한 가능)
''';

  // void _showDialog(String title, String content) {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: Text(title),
  //       content: SingleChildScrollView(child: Text(content)),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text('닫기'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, String>;
    final email = args['email']!;
    final password = args['password']!;
    final allAgreed = agreedTerms && agreedPrivacy && agreedSensitive;

    return AspectViewport(
        aspect: 9 / 16,
        background: AppColors.grey100,
        child: Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: CustomAppBar(
        title: '약관 동의',
        showHome: false,
      ),
      body: Padding(
          padding: const EdgeInsets.all(AppSizes.padding),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSizes.space),
                const Icon(Icons.verified_user, size: 100, color: AppColors.indigo),
                const SizedBox(height: AppSizes.space*2),

                _buildCheckTile(
                  title: '이용약관 동의',
                  summary: _termsSummary,
                  value: agreedTerms,
                  onChanged: (v) => setState(() => agreedTerms = v ?? false),
                  // onViewPressed: () {
                  //   _showDialog('이용약관', _termsContent);
                  // },
                  agreeLabel: '이용약관에 동의합니다.',
                ),
                const SizedBox(height: AppSizes.space),

                _buildCheckTile(
                  title: '개인정보 수집 및 이용 동의',
                  summary: _privacySummary,
                  value: agreedPrivacy,
                  onChanged: (v) => setState(() => agreedPrivacy = v ?? false),
                  // onViewPressed: () {
                  //   _showDialog('개인정보 처리방침', _privacyContent);
                  // },
                  agreeLabel: '개인정보 수집·이용에 동의합니다.',
                ),
                const SizedBox(height: AppSizes.space),
                _buildCheckTile(
                  title: '민감정보(정신건강 관련 설문·일기) 처리 동의',
                  summary: _sensitiveSummary,
                  value: agreedSensitive,
                  onChanged: (v) => setState(() => agreedSensitive = (v ?? false)),
                  // onViewPressed: () {
                  //   _showDialog('민감정보 처리 동의', _sensitiveConsent);
                  // },
                  agreeLabel: '민감정보 처리에 동의합니다.',
                ),

                const SizedBox(height: AppSizes.space * 2),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: allAgreed
                        ? () {
                            Navigator.pushNamed(context, '/signup', arguments: {
                              'email': email,
                              'password': password,
                            });
                          }
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                      ),
                      minimumSize: const Size.fromHeight(54),
                    ),
                    child: const Text('다음으로'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 약관 동의 항목 위젯 (체크박스 + 텍스트 + 더보기)
  Widget _buildCheckTile({
    required String title,
    required String summary,
    required bool value,
    required ValueChanged<bool?> onChanged,
    // required VoidCallback onViewPressed,
    String agreeLabel = '위 내용에 동의합니다.',
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16,16,16,6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목
          Text(
            title,
            style: const TextStyle(
              fontSize: AppSizes.fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // 요약 동의문
          Text(
            summary,
            style: const TextStyle(fontSize: AppSizes.fontSize - 4),
          ),
          const Divider(height: 8),
          // 하단: 체크박스 + '전체 보기' 버튼 (우측 정렬)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: Colors.indigo,
              ),
              Expanded(
                child: Text(
                  agreeLabel,
                  style: const TextStyle(fontSize: AppSizes.fontSize),
                ),
              ),
              // TextButton(
              //   onPressed: onViewPressed,
              //   child: const Text('전체 보기', style: TextStyle(color: AppColors.indigo)),
              // ),
            ],
          ),
        ],
      ),
    );
  }
}