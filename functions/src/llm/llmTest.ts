import dotenv from "dotenv";
import OpenAI from "openai";

dotenv.config();

// 실제 사용된 칩 데이터 정의 (콤마로 구분된 칩을 배열로 변환)
const activatingEvent = ["주문했던 책이 배송됨"];
const belief = ["시간낭비 드디어 읽고싶던 책을 읽을 수 있겠다. 생각함"];
const c1Physical = ["딱히 입꼬리가 올라가고 몸이 가볍게 느껴짐"];
const c2Emotion = ["설레고 기뻤다."];
const c3Behavior = ["바로 포장을 뜯었다"];

// 칩 배열을 줄바꿈으로 변환
function chipsToLines(chips: string[]) {
  return chips.map((chip) => `- ${chip}`).join("\n");
}

const prompt = `
상황:
${chipsToLines(activatingEvent)}
생각:
${chipsToLines(belief)}
신체:
${chipsToLines(c1Physical)}
감정:
${chipsToLines(c2Emotion)}
행동:
${chipsToLines(c3Behavior)}

너는 심리상담 전문가야.  
위 데이터는 사용자가 작성한 CBT 기반 ABC 감정일기야.  

너의 임무는 이 데이터를 바탕으로 사용자가 쓴 일기를 읽고 상담사가 짧게 정리해 주는 리포트를 작성하는 것이다.  

출력 규칙:  
1) 반드시 **줄글 문단**으로 작성하고, 목록·번호·기호는 사용하지 않는다.  
2) 길이는 5~6줄 내외여야 한다.  
3) 구조: 상황 요약 → 생각·감정 해석 → 행동과 감정의 연결 → 마지막에 1~2개의 현실적인 조언.  
4) 어조는 따뜻하고 공감적이며 전문 용어 없이 일상적인 언어로 작성.  
5) 아래 예시 스타일을 반드시 참고해 같은 톤과 길이로 작성할 것.  

예시 리포트:  
"어떤 일을 하면서 확신이 부족하다고 느끼자 마음이 크게 흔들렸을 거예요. 
스스로 '이게 다 소용없을지도 몰라'라고 생각하면서 불안과 걱정, 짜증이 한꺼번에 몰려온 것 같아요.
몸에는 특별히 반응이 없었지만 마음의 피로는 분명 커졌을 겁니다. 
결국 게임이나 술 같은 방법으로 그 순간을 피하려 했던 것 같아요. 
다음에는 시작 전에 호흡을 가다듬거나, 작은 목표를 하나 정해보는 게 도움이 될 수 있어요. 
작은 준비가 감정의 무게를 줄여주고 자신감을 높여줄 거예요."
`;

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

async function testLlm() {
  const response = await openai.chat.completions.create({
    model: "gpt-4o-mini",
    messages: [{ role: "user", content: prompt }],
    max_tokens: 700,
  });

  console.log("--- LLM Response ---");
  console.log(response.choices[0].message?.content);
}

testLlm().catch(console.error);
