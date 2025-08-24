import * as admin from "firebase-admin";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import OpenAI from "openai";

const db = admin.firestore();
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY, // 환경변수에 키 저장 필요
});

/**
 * Firestore 트리거: abc_models 문서 생성/수정 시 실행
 */
export const onAbcCreatedOrUpdated = onDocumentWritten(
  "chi_users/{uid}/abc_models/{abcId}",
  async (event) => {
    console.log("🔥 Trigger fired:", event.params);

    const { uid, abcId } = event.params;
    const afterData = event.data?.after?.data();

    if (!afterData) return;

    const completedAt = afterData["completedAt"];
    const report = afterData["report"];

    // 조건: completedAt이 있고 report가 없을 때만 실행
    if (!completedAt || report) return;

    // 프롬프트 구성
    const activatingEvent = afterData["activatingEvent"] ?? "";
    const belief = afterData["belief"] ?? "";
    const c1Physical = afterData["c1_physical"] ?? "";
    const c2Emotion = afterData["c2_emotion"] ?? "";
    const c3Behavior = afterData["c3_behavior"] ?? "";

    const prompt = `
상황:
- ${activatingEvent}
생각:
- ${belief}
신체:
- ${c1Physical}
감정:
- ${c2Emotion}
행동:
- ${c3Behavior}

위 내용을 바탕으로:
1. 간단한 요약
2. 반복되는 패턴
3. 개선 제안
`;

    // OpenAI LLM 호출
    let aiReport = "";
    try {
      const response = await openai.chat.completions.create({
        model: "gpt-4o",
        messages: [{ role: "user", content: prompt }],
        max_tokens: 500,
      });
      aiReport = response.choices[0].message?.content ?? "";
    } catch (e) {
      console.error("OpenAI 호출 실패:", e);
      aiReport = "AI 리포트 생성에 실패했습니다.";
    }

    // Firestore에 report 필드 생성 및 저장
    await db
      .collection("chi_users")
      .doc(uid)
      .collection("abc_models")
      .doc(abcId)
      .update({
        report: aiReport,
        reportGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    console.log("✅ AI 리포트 저장 완료:", abcId);
  }
);
