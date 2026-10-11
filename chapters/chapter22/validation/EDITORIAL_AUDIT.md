# Chapter 22 Editorial Audit

- Added a publisher-style chapter abstract.
- Retained the potential-outcomes foundation, 2x2 DiD derivation, identification assumptions, bad-control warning, common-adoption TWFE, event studies, few-cluster inference, and staggered-adoption limitations.
- Rebuilt the empirical example directly from the raw Grunfeld CSV and renamed log-difference variables to the book-wide `dlinvest`, `dlvalue`, and `dlcapital` convention.
- States repeatedly that teaching label 2018 corresponds to original Grunfeld 1947 and is not a modern intervention date.
- States explicitly that the original Grunfeld data contain no real treatment metadata and therefore cannot identify an actual causal DiD effect.
- Replaced the complete legacy software workflow with R/RStudio code.
- Reframed permutation calculations as hypothetical assignment references because the teaching assignment was deterministic.
- Added an exhaustive restricted firm-level wild-cluster-t calculation for ten treatment clusters.
- Added current R templates for Callaway--Sant'Anna group-time ATT and Sun--Abraham event studies without applying them falsely to the common-adoption synthetic case.
- Retained careful log-point versus exact percentage interpretation.
- Reader-facing manuscript contains no legacy menu, project-object, freeze, or spool commands.
