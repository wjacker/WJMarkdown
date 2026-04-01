# WJMarkdown AI Chat TODO

## Current status

- Project baseline: HarmonyOS Stage template with a single `Index.ets` page.
- Current implementation in this round:
  - Added a chat-style page shell.
  - Added chat message model and demo data.
  - Added a markdown block parser for AI chat rendering.
  - Added streaming typing simulation for assistant replies.
  - Added parser unit tests.

## Phase 1: chat shell and rendering foundation

- [x] Replace template page with a chat-oriented home page.
- [x] Add message model to distinguish user and assistant roles.
- [x] Add reusable bubble component for chat messages.
- [x] Add demo input area and local assistant response generator.

## Phase 2: markdown rendering in chat

- [x] Support paragraph blocks.
- [x] Support heading blocks.
- [x] Support block quotes.
- [x] Support unordered and ordered lists.
- [x] Support fenced code blocks.
- [x] Support dividers.
- [x] Support lightweight tables.
- [x] Support inline bold, italic, inline code, strike and links.
- [ ] Add nested lists and nested block quotes.
- [x] Add task list syntax like `- [x]`.
- [x] Add image rendering and remote image placeholder strategy.
- [x] Add syntax highlighting for fenced code blocks.

## Phase 3: streaming and user experience

- [x] Support character-by-character typing effect.
- [x] Re-parse markdown during streaming.
- [x] Auto-scroll to the newest message while streaming.
- [ ] Add pause, resume and cancel streaming controls.
- [ ] Add copy actions for code blocks and full messages.
- [ ] Add markdown error tolerance metrics for incomplete streaming chunks.

## Phase 4: production integration

- [ ] Replace local timer stream with real model streaming callbacks.
- [ ] Introduce message persistence for local session history.
- [ ] Add request lifecycle states: sending, streaming, retry, failed.
- [ ] Add SSE or WebSocket service layer for AI responses.
- [ ] Add token usage, latency and trace logging.
- [ ] Add configuration layer for model, endpoint and auth.

## Phase 5: quality and engineering

- [x] Add parser unit tests for common block and inline cases.
- [ ] Add more test coverage for partial markdown during typing.
- [ ] Add snapshot or UI tests for chat bubbles and tables.
- [ ] Split theme tokens into dedicated resources.
- [ ] Extract chat feature into an independent module if this app grows.
