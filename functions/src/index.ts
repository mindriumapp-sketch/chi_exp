import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import dotenv from "dotenv";
import OpenAI from "openai";

admin.initializeApp();

// ✅ .env 파일 로드
dotenv.config();

// ✅ 환경변수에서 OpenAI Key 읽기
const apiKey = process.env.OPENAI_API_KEY;
if (!apiKey) {
  throw new Error("❌ OpenAI API Key is missing. Set it in your .env file as OPENAI_API_KEY=...");
}

const openai = new OpenAI({ apiKey });

export const onAbcReportGenerated = functions
  .region("asia-northeast3")
  .firestore.document("chi_users/{userId}/abc_models/{abcId}")
  .onWrite(async (
    change: functions.Change<functions.firestore.DocumentSnapshot>,
    context: functions.EventContext
  ) => {
    const afterData = change.after.data();
    if (!afterData) return;

    const activatingEvent = afterData["activatingEvent"] ?? "";
    const belief = afterData["belief"] ?? "";
    const c1_physical = afterData["c1_physical"] ?? "";
    const c2_emotion = afterData["c2_emotion"] ?? "";
    const c3_behavior = afterData["c3_behavior"] ?? "";

    // completedAt 없으면 실행 안 함
    if (!afterData["completedAt"]) return;

    const beforeData = change.before.data();
    const reportExists = !!afterData["report"];
    let shouldUpdateReport = false;

    if (!reportExists) {
      shouldUpdateReport = true;
    } else if (beforeData) {
      if (
        beforeData["activatingEvent"] !== activatingEvent ||
        beforeData["belief"] !== belief ||
        beforeData["c1_physical"] !== c1_physical ||
        beforeData["c2_emotion"] !== c2_emotion ||
        beforeData["c3_behavior"] !== c3_behavior
      ) {
        shouldUpdateReport = true;
      }
    }

    if (!shouldUpdateReport) return;

    // ✅ 프롬프트 생성
    const prompt = `
상황:
${activatingEvent}
생각:
${belief}
신체:
${c1_physical}
감정:
${c2_emotion}
행동:
${c3_behavior}

너는 심리상담 전문가야.  
위 데이터는 사용자가 작성한 CBT 기반 ABC 감정일기야.  

너의 임무는 이 데이터를 바탕으로 사용자가 쓴 일기를 읽고 상담사가 짧게 정리해 주는 리포트를 작성하는 것이다.  

출력 규칙:  
1) 반드시 **줄글 문단**으로 작성하고, 목록·번호·기호는 사용하지 않는다.  
2) 길이는 5~6줄 내외여야 한다.  
3) 구조: 상황 요약 → 생각·감정 해석 → 행동과 감정의 연결 → 마지막에 1~2개의 현실적인 조언.  
4) 어조는 따뜻하고 공감적이며 전문 용어 없이 일상적인 언어로 작성.  
5) 예시 리포트 톤과 길이를 그대로 참고.

`;

    try {
      const response = await openai.chat.completions.create({
        model: "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        max_tokens: 700,
      });

      const report = response.choices[0].message?.content ?? "";

      // ✅ OpenAI 호출 성공했을 때만 Firestore 업데이트
      await change.after.ref.update({
        report,
        reportGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (e: any) {
      console.error("❌ OpenAI 호출 실패:", e.message, e.response?.status, e.response?.data);
      // 실패 시 Firestore에 아무것도 저장하지 않음
      return;
    }
  });
