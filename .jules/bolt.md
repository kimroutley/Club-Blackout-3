## 2024-05-22 - Nested BackdropFilter Performance
**Learning:** Nested `BackdropFilter` widgets, especially inside `ListView` or `SliverList`, cause significant performance degradation due to repeated `saveLayer` calls.
**Action:** Avoid using `BackdropFilter` inside list items. If the background is already blurred, use semi-transparent colors instead.
