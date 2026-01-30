## 2024-05-22 - Nested BackdropFilter Performance
**Learning:** Nested `BackdropFilter` widgets, especially inside `ListView` or `SliverList`, cause significant performance degradation due to repeated `saveLayer` calls.
**Action:** Avoid using `BackdropFilter` inside list items. If the background is already blurred, use semi-transparent colors instead.

## 2024-05-23 - Simulation Loop Complexity
**Learning:** `GameEngine.eligibleDayVotesByTarget` was O(N^2) (nested loop over players). While acceptable for UI rendering, it became a bottleneck when called thousands of times inside `MonteCarloSimulator` for live win odds calculation.
**Action:** Always check if a getter or method is used in simulation loops (hot paths) before dismissing O(N^2) logic on small datasets.
