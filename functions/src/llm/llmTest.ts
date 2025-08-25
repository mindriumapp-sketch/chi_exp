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

// 사용자 정보 (예시: chi_users에서 가져온 값)
const user = {
  id: "/chi_users/S5draTQ07OZarEme44UzionN7u42",
  name: "태훈", // 실제 데이터에서 가져오는 값이라고 가정
};

// 이름 + 존칭
const userDisplayName = `${user.name}님`;

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

너는 심리상담 전문가다.
위 데이터는 CBT 기반 ABC 감정일기다.

너의 임무는 이 일기 내용을 깊이 있게 이해하고 정리하여, 상담사가 직접 작성하는 듯한 심리 리포트를 작성하는 것이다.

출력 규칙:
1) 문단은 2개로 나누고, 줄글로 작성하며 목록·번호·기호는 사용하지 않는다.
2) 길이는 6~8줄 내외여야 한다.
3) 구조:
   - 첫 번째 문단: ${userDisplayName}이 직면한 상황과 그에 따른 생각, 그리고 감정의 흐름을 객관적으로 요약한다.
   - 두 번째 문단: 그 생각과 감정이 신체적 반응과 행동으로 어떻게 이어졌는지 분석하고, 마지막에 현실적인 조언이나 통찰을 덧붙인다.
4) 어조는 따뜻하고 공감적이며, 전문 용어 없이 일상적인 언어로 작성한다. 
   ${userDisplayName}을 직접 지칭하며 대화하는 것처럼 표현한다.
5) 예시 스타일을 반드시 참고하여 같은 톤과 길이로 작성할 것.
6) 내담자를 지칭할 때는 반드시 '${userDisplayName}'만 사용한다. "당신", "여러분" 같은 표현은 절대 쓰지 않는다.
`;

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

async function testLlm() {
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

  console.log("--- LLM Response ---");
  console.log(response.choices[0].message?.content);
}

testLlm().catch(console.error);


