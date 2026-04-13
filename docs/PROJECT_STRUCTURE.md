# WJMarkdown Project Structure

## Root overview

```text
WJMarkdown
├── AppScope
├── docs
│   ├── AI_CHAT_TODO.md
│   └── PROJECT_STRUCTURE.md
├── entry
│   ├── src
│   │   ├── main
│   │   │   ├── ets
│   │   │   │   ├── components
│   │   │   │   │   ├── ChatBubble.ets
│   │   │   │   │   └── MarkdownMessage.ets
│   │   │   │   ├── models
│   │   │   │   │   ├── ChatModels.ets
│   │   │   │   │   ├── CodeHighlightModels.ets
│   │   │   │   │   └── MarkdownModels.ets
│   │   │   │   ├── pages
│   │   │   │   │   └── Index.ets
│   │   │   │   └── utils
│   │   │   │       ├── CodeHighlighter.ets
│   │   │   │       └── MarkdownParser.ets
│   │   │   ├── module.json5
│   │   │   └── resources
│   │   └── test
│   │       ├── List.test.ets
│   │       ├── LocalUnit.test.ets
│   │       └── MarkdownParser.test.ets
├── hvigor
├── oh_modules
├── build-profile.json5
├── hvigorfile.ts
└── oh-package.json5
```

## Directory purpose

- `docs`
  - Project-facing engineering notes and task list for the AI chat feature.
- `entry/src/main/ets/components`
  - Reusable UI building blocks for chat bubbles and markdown rendering.
- `entry/src/main/ets/data`
  - Local demo conversation and response-building helpers.
- `entry/src/main/ets/models`
  - Core data models for chat messages, parsed markdown blocks, and code highlighting.
- `entry/src/main/ets/pages`
  - Page-level composition. `Index.ets` is now the chat home page.
- `entry/src/main/ets/utils`
  - Pure utility logic. The markdown parser and code highlighter live here to stay testable.
- `entry/src/test`
  - Unit tests, including parser coverage for common markdown shapes.
