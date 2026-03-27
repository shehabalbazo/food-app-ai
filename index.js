const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { HfInference } = require("@huggingface/inference");

admin.initializeApp();

const client = new HfInference("");

function normalizeText(text) {
  return (text || "")
    .toLowerCase()
    .trim()
    .replace(/[^\p{L}\p{N}\s]/gu, "");
}

async function getMenuData() {
  const collections = ["Pizza", "Burger", "Salad", "Ice-cream"];
  const items = [];

  for (const col of collections) {
    const snapshot = await admin.firestore().collection(col).get();

    snapshot.forEach((doc) => {
      const data = doc.data();
      items.push({
        category: col,
        name: data.Name || "",
        price: data.Price || "",
        detail: data.Detail || "",
      });
    });
  }

  return items;
}

// بحث مباشر فقط عن المنتجات والقوائم والأسعار
function searchFoodInMenu(userMessage, menuItems) {
  const msg = normalizeText(userMessage);

  const categories = ["Pizza", "Burger", "Salad", "Ice-cream"];

  for (const category of categories) {
    const catNorm = normalizeText(category);

    if (msg.includes(catNorm)) {
      const filtered = menuItems.filter(
        (item) => normalizeText(item.category) === catNorm
      );

      if (filtered.length === 0) return null;

      return {
        type: "category",
        category,
        items: filtered,
      };
    }
  }

  for (const item of menuItems) {
    const itemName = normalizeText(item.name);
    const words = itemName.split(" ").filter((w) => w.trim() !== "");

    let matched = 0;
    for (const word of words) {
      if (msg.includes(word)) matched++;
    }

    if (words.length > 0 && matched === words.length) {
      return {
        type: "product",
        item,
      };
    }
  }

  return null;
}

// الموديل هو الذي يصيغ الرد بنفس لغة المستخدم
async function askModel(messages, extraContext = "") {
  const result = await client.chatCompletion({
    provider: "cohere",
    model: "CohereLabs/c4ai-command-a-03-2025",
    messages: [
      {
        role: "system",
        content: `You are an AI assistant inside a food ordering mobile application. 

the application name is Noria Eats

You can:
- Help users find and order food
- Suggest meals from the menu
- Guide users inside the app (profile, cart, home, categories)
- Answer questions about the app

Reply in the EXACT same language as the user's last message.
If the user writes in Arabic, reply only in Arabic.
If the user writes in Turkish, reply only in Turkish.
If the user writes in English, reply only in English.

Keep the answer short, natural, and helpful.
Do not switch languages unless the user does.

If the user asks to open or go to a page, respond naturally and briefly.
If the request is about navigating inside the app, respond briefly and do not suggest food unless asked.

${extraContext}`
      },
      ...messages,
    ],
    max_tokens: 150,
  });

  return (
    result?.choices?.[0]?.message?.content ||
    "AI could not generate a response."
  );
}

exports.chatWithAI = functions.https.onCall(async (data, context) => {
  try {
    const messages = data.data?.messages;

    if (!messages || !Array.isArray(messages) || messages.length === 0) {
      return { reply: "Messages are required" };
    }

    const lastUserMessage =
      [...messages].reverse().find((m) => m.role === "user")?.content || "";

    const navigationResult = detectNavigationAction(lastUserMessage);
    if (navigationResult) {
      return navigationResult;
    }

    const menuItems = await getMenuData();

    // 1) حاول بحث مباشر
    const directMatch = searchFoodInMenu(lastUserMessage, menuItems);

    // 2) إذا وجدنا نتيجة مباشرة، نعطيها للموديل ليصيغها بنفس لغة المستخدم
    if (directMatch) {
      let directContext = "";

      if (directMatch.type === "category") {
        const itemsText = directMatch.items
          .map((item) => `${item.name} - $${item.price}`)
          .join("\n");

        directContext = `The user is asking about the ${directMatch.category} menu.
Use ONLY these items in your reply:
${itemsText}

If the user wants the menu, show the items with prices.
Keep it short.`;
      }

      if (directMatch.type === "product") {
        directContext = `The user is asking about this product:
${directMatch.item.name} - $${directMatch.item.price}

Tell the user the price clearly and briefly.`;
      }

      const reply = await askModel(messages, directContext);
      return { reply };
    }

    // 3) إذا ما في نتيجة مباشرة، ابعث المنيو كلها للموديل
    const menuText = menuItems
      .map(
        (item) =>
          `- ${item.name} | Category: ${item.category} | Price: $${item.price}`
      )
      .join("\n");

    const reply = await askModel(
      messages,
      `Use ONLY items from this menu when giving recommendations.
Always mention the item name and price if recommending food.

Menu:
${menuText}`
    );

    return { reply };
  } catch (error) {
    console.error("HF ERROR:", error);
    return {
      reply: "AI ERROR: " + (error.message || "Unknown error"),
    };
  }
});

function detectNavigationAction(userMessage) {
  const msg = userMessage.toLowerCase();

  // Profile
  if (
    msg.includes("profile") ||
    msg.includes("account") ||
    msg.includes("profil") ||
    msg.includes("hesap") ||
    msg.includes("البروفايل") ||
    msg.includes("الحساب") ||
    msg.includes("take me to profile") ||
    msg.includes("go to profile")
  ) {
    return {
      action: "open_profile",
      reply: "Opening your profile."
    };
  }

  // Home
  if (
    msg.includes("home") ||
    msg.includes("ana sayfa") ||
    msg.includes("homepage") ||
    msg.includes("الرئيسية") ||
    msg.includes("go home") ||
    msg.includes("take me home")
  ) {
    return {
      action: "open_home",
      reply: "Opening home page."
    };
  }

  // Cart
  if (
    msg.includes("cart") ||
    msg.includes("basket") ||
    msg.includes("sepet") ||
    msg.includes("السلة") ||
    msg.includes("go to cart") ||
    msg.includes("open cart")
  ) {
    return {
      action: "open_cart",
      reply: "Opening your cart."
    };
  }

  // Wallet
  if (
    msg.includes("wallet") ||
    msg.includes("money") ||
    msg.includes("cüzdan") ||
    msg.includes("محفظة") ||
    msg.includes("go to wallet") ||
    msg.includes("open wallet")
  ) {
    return {
      action: "open_wallet",
      reply: "Opening your wallet."
    };
  }

  // Burger
  if (
    msg.includes("open burger") ||
    msg.includes("go to burger") ||
    msg.includes("burgere git") ||
    msg.includes("اذهب الى البرغر") ||
    msg.includes("burger category") ||
    msg.includes("burger")
  ) {
    return {
      action: "open_burger",
      reply: "Opening burger category.",
    };
  }

  // Pizza
  if (
    msg.includes("open pizza") ||
    msg.includes("go to pizza") ||
    msg.includes("pizzaya git") ||
    msg.includes("اذهب الى البيتزا") ||
    msg.includes("pizza category")
  ) {
    return {
      action: "open_pizza",
      reply: "Opening pizza category.",
    };
  }

  //Salad
  if (
    msg.includes("open salad") ||
    msg.includes("go to salad") ||
    msg.includes("salataya git") ||
    msg.includes("اذهب الى السلطة") ||
    msg.includes("salad category")
  ) {
    return {
      action: "open_salad",
      reply: "Opening salad category.",
    };
  }

  //Ice Cream
  if (
    msg.includes("open ice cream") ||
    msg.includes("go to ice cream") ||
    msg.includes("dondurmaya git") ||
    msg.includes("اذهب الى البوظة") ||
    msg.includes("ice cream category") ||
    msg.includes("open icecream")
  ) {
    return {
      action: "open_icecream",
      reply: "Opening ice cream category.",
    };
  }

  return null;
}

