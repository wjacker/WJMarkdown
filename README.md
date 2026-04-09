# WJMarkdown

一个基于 HarmonyOS ArkTS 的 AI 聊天示例项目，重点能力是：

- AI 聊天界面
- Markdown 完整渲染
- 流式打字输出
- 数学公式渲染
- 多回答版本切换
- 点赞、点踩、删除、重新生成、播报等操作

当前主页面入口是 [entry/src/main/ets/pages/agent/Index.ets](/Users/Jack/Jack/ai-project/WJMarkdown/entry/src/main/ets/pages/agent/Index.ets)。

## 项目结构

核心代码已经按 Agent 聊天能力拆分到 `pages/agent` 下：

- [entry/src/main/ets/pages/agent/Index.ets](/Users/Jack/Jack/ai-project/WJMarkdown/entry/src/main/ets/pages/agent/Index.ets)
  页面编排、消息状态流转、输入区与消息列表
- [entry/src/main/ets/pages/agent/components](/Users/Jack/Jack/ai-project/WJMarkdown/entry/src/main/ets/pages/agent/components)
  聊天气泡、Markdown 渲染、数学公式渲染、操作栏分发
- [entry/src/main/ets/pages/agent/models](/Users/Jack/Jack/ai-project/WJMarkdown/entry/src/main/ets/pages/agent/models)
  聊天消息、Markdown、代码高亮、HiAgent 数据模型
- [entry/src/main/ets/pages/agent/utils](/Users/Jack/Jack/ai-project/WJMarkdown/entry/src/main/ets/pages/agent/utils)
  Markdown 解析、HTML 渲染、SSE 解析、代码高亮
- [entry/src/main/ets/pages/agent/services](/Users/Jack/Jack/ai-project/WJMarkdown/entry/src/main/ets/pages/agent/services)
  AI 接口调用与流式请求封装
- [entry/src/main/ets/pages/agent/data](/Users/Jack/Jack/ai-project/WJMarkdown/entry/src/main/ets/pages/agent/data)
  本地演示数据

页面入口配置：

- [entry/src/main/ets/entryability/EntryAbility.ets](/Users/Jack/Jack/ai-project/WJMarkdown/entry/src/main/ets/entryability/EntryAbility.ets)
- [entry/src/main/resources/base/profile/main_pages.json](/Users/Jack/Jack/ai-project/WJMarkdown/entry/src/main/resources/base/profile/main_pages.json)

## 功能说明

### 1. AI 聊天

- 支持用户提问与助手流式回复
- 支持停止回复
- 支持历史消息同步
- 支持会话恢复

### 2. Markdown 渲染

支持常见 Markdown 能力：

- 标题
- 段落
- 引用
- 无序列表 / 有序列表
- 任务列表
- 代码块
- 表格
- 图片
- 粗体 / 斜体 / 删除线 / 行内代码 / 链接

### 3. 数学公式

- 支持块级公式与行内公式渲染
- 流式阶段优先保证正文稳定显示
- 完整输出后统一进行公式渲染

### 4. 回复操作

- 复制
- 重新生成
- 删除当前回复
- 点赞 / 点踩
- 播报
- 多版本分页切换

## 接口接入

项目已经预留 AI 接口配置区，运行时需要填写：

- `Api URL`
- `ApiKey`
- `UserID`

说明：

- 文档里如果区分了请求头鉴权和请求体 `AppKey`，当前实现默认复用同一份配置值
- 接口地址请按你的部署环境填写
- README 不写死任何具体地址，避免和不同环境耦合

当前服务封装位于：

- [HiAgentService.ets](/Users/Jack/Jack/ai-project/WJMarkdown/entry/src/main/ets/pages/agent/services/HiAgentService.ets)

## 运行方式

建议使用 DevEco Studio 打开项目后直接运行。

如果使用命令行方式，可按本机 DevEco 环境执行构建脚本，例如使用 DevEco 自带 `node` 与 `hvigorw.js`。

## 说明

- 网络权限已在模块配置中声明
- 当前项目更偏向聊天渲染与交互验证
- 如果要上线使用，建议继续补充签名配置、异常兜底、接口鉴权和日志策略

