# Trae IDE 自定义模型 (BYOM) 计费说明

**来源**: 用户提供的对话截图 (SOLO Coder)
**日期**: 2026-01-23

关于在 Trae IDE 中添加和使用自定义模型（BYOM - Bring Your Own Model）的计费问题，根据截图内容整理如下：

## 核心结论
费用通过 **【对应的模型服务商】** 直接结算。

## 详细解释

### 1. API Key 的作用
*   当您在“添加模型”窗口中选择“服务商”（例如 Gemini, OpenAI, Anthropic）并输入 API 密钥（API Key）时，您实际上是在告诉 Trae IDE：“请使用我个人的账号去调用这个模型的接口。”
*   Trae IDE 只是一个客户端工具，它把你的请求转发给模型服务商。

### 2. 计费逻辑
*   **Trae 方面**：Trae 通常不会因为您使用了自己的 API Key 而向您额外收费（除非它有特殊的“网关费”，但目前主流 IDE 如 VS Code, Cursor 等都不收这笔钱）。Trae 的 Pro 订阅费用通常只包含它自身的默认模型或使用服务。
*   **服务商方面**：您的每一次对话、每一次代码生成，都会消耗您在 Google (Gemini) 或 OpenAI 等平台的 API 额度。
*   **扣费对象**：如果您绑定了信用卡在 Google Cloud 或 OpenAI Platform，费用会直接从您的绑定的信用卡扣除。

### 3. 举例说明
*   如果您在 Trae 里添加了自己的 Gemini Pro API Key。
*   您问了一个问题，消耗了 1000 Tokens。
*   Google Cloud 会在您的账单上记一笔（按 Gemini API 定价）。
*   Trae 不会扣除您的 Trae 会员费用，也不会向您收费。

## 总结建议
如果您使用“添加模型”功能填入了自己的 Key，**请务必关注对应服务商（如 Google AI Studio, OpenAI）的后台账单**，确保余额充足，以免 API 调用失败。Trae 会员订阅费仅覆盖 Trae 官方提供的内置服务。
