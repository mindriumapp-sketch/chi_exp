import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import dotenv from "dotenv";
import OpenAI from "openai";

admin.initializeApp();
dotenv.config();

const apiKey = process.env.OPENAI_API_KEY;
if (!apiKey) {
  throw new Error("❌ OpenAI API Key is missing. Set it in your .env file as OPENAI_API_KEY=...");
}

const openai = new OpenAI({ apiKey });

function normalizeField(value: any): string[] {
  if (!value) return [];
  if (Array.isArray(value)) {
    return value.map((v) => String(v).trim()).filter((v) => v.length > 0);
  }
  if (typeof value === "string") {
    return [value.trim()].filter((v) => v.length > 0);
  }
  return [String(value).trim()];
}

function isEqualArray(a: any, b: any): boolean {
  return JSON.stringify(a ?? []) === JSON.stringify(b ?? []);
}

export const onAbcReportGeneratedV2 = functions
  .region("asia-northeast3")
  .firestore.document("chi_users/{userId}/abc_models/{abcId}")
  .onWrite(async (change, context) => {
    const afterData = change.after.data();
    if (!afterData) return;

    if (!afterData["completedAt"]) return;

    const beforeData = change.before.data();

    const userId = context.params.userId;
    const userDoc = await admin.firestore().doc(`chi_users/${userId}`).get();
    const userName = userDoc.get("name") || "사용자";
    const userDisplayName = `${userName}님`;

    const activatingEvent = normalizeField(afterData["activatingEvent"]);
    const belief = normalizeField(afterData["belief"]);
    const c1_physical = normalizeField(afterData["c1_physical"]);
    const c2_emotion = normalizeField(afterData["c2_emotion"]);
    const c3_behavior = normalizeField(afterData["c3_behavior"]);

    const reportExists = !!afterData["report"];
    let shouldUpdateReport = false;

    if (!reportExists) {
      shouldUpdateReport = true;
    } else if (beforeData) {
      const coreFieldsChanged =
        !isEqualArray(beforeData["activatingEvent"], afterData["activatingEvent"]) ||
        !isEqualArray(beforeData["belief"], afterData["belief"]) ||
        !isEqualArray(beforeData["c1_physical"], afterData["c1_physical"]) ||
        !isEqualArray(beforeData["c2_emotion"], afterData["c2_emotion"]) ||
        !isEqualArray(beforeData["c3_behavior"], afterData["c3_behavior"]);

      if (coreFieldsChanged) {
        shouldUpdateReport = true;
      }
    }

    if (!shouldUpdateReport) {
      console.log("⚠️ No relevant field changed, skipping report update");
      return;
    }

    const prompt = `
상황:
${activatingEvent.join(", ")}
생각:
${belief.join(", ")}
신체:
${c1_physical.join(", ")}
감정:
${c2_emotion.join(", ")}
행동:
${c3_behavior.join(", ")}

너는 심리상담 전문가야.  
위 데이터는 ${userDisplayName}이 작성한 CBT 기반 ABC 감정일기야.  

너의 임무는 이 데이터를 바탕으로 ${userDisplayName}이 쓴 일기를 읽고, 상담사가 직접 작성하는 듯한 심리 리포트를 작성하는 것이다.  

출력 규칙:  
1) 반드시 **줄글 문단**으로 작성하고, 목록·번호·기호는 사용하지 않는다.  
2) 길이는 6~8줄 내외여야 한다.  
3) 구조: 상황 요약 → 생각·감정 해석 → 행동과 감정의 연결 → 마지막에 1~2개의 현실적인 조언.  
4) 어조는 따뜻하고 공감적이며 전문 용어 없이 일상적인 언어로 작성.  
5) 내담자를 지칭할 때는 반드시 '${userDisplayName}'만 사용한다. "당신", "여러분", "사용자" 같은 표현은 절대 쓰지 않는다.  
6) 아래 예시 리포트 톤과 길이를 그대로 참고.  
7) 문단사이에 들여쓰기 필수  

예시 리포트 (부정적 감정일기):  
스스로 확신이 부족하다는 생각이 들자 마음이 크게 흔들렸던 순간이 있었을 것 같습니다. ‘이게 다 소용없을지도 몰라’라는 비합리적인 생각이 스쳐 지나가면서 불안과 걱정, 짜증이 한꺼번에 밀려왔을 것 같아요. 감정이 한순간에 커져버리니 몸도 무겁게 느껴지고 집중이 어려웠을 수도 있겠네요.  

이러한 내면의 혼란은 문제를 피하려는 행동으로 이어져, 게임이나 술과 같은 방식으로 순간을 모면하려 했던 것 같습니다. 하지만 이런 방식은 일시적으로는 마음을 잊게 해주지만, 장기적으로는 불안을 더 키울 수 있습니다. 이런 때는 행동으로 옮기기 전에 스스로에게 ‘지금 떠오른 무기력한 생각이 사실일까?’라고 질문해보는 것도 도움이 돼요. 그렇게 감정을 차분히 바라보는 연습이 반복된다면, 감정의 무게를 덜어내는 첫걸음을 내딛을 수 있을 것입니다.  

예시 리포트 (긍정적 감정일기):  
기다리던 책을 손에 넣었을 때 얼마나 설렘이 컸을지 잘 느껴집니다. ‘드디어 읽을 수 있겠구나’라는 생각은 마음에 큰 기쁨을 가져왔고, 오랫동안 품어온 갈망이 채워지는 순간이었을 거예요. 기대와 기쁨이 겹쳐지면서 몸이 가볍게 느껴지고, 표정에도 자연스러운 미소가 번졌을 것 같습니다.  

이 긍정적인 감정은 곧바로 행동으로 이어져, 책을 포장지에서 꺼내는 순간까지 즐거움이 계속 흘러갔네요. 이렇게 일상의 작은 성취에서 느낀 만족과 행복은 앞으로의 생활에도 긍정적인 힘을 주는 중요한 자원이 됩니다. ${userDisplayName}이 이런 경험을 의식적으로 떠올리고 기록한다면, 힘든 순간에도 마음을 회복하는 좋은 버팀목이 될 수 있을 거예요.  
`;

    try {
      const response = await openai.chat.completions.create({
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content: `너는 심리상담 전문가이며, 반드시 내담자를 '${userDisplayName}'으로만 지칭해야 한다.`,
          },
          { role: "user", content: prompt },
        ],
        max_tokens: 700,
      });

      const report = response.choices[0].message?.content ?? "";

      await change.after.ref.update({
        report,
        reportGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (e: any) {
      console.error("❌ OpenAI 호출 실패:", e.message, e.response?.status, e.response?.data);
      await change.after.ref.update({
        report: "리포트 생성 실패",
        reportGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });
