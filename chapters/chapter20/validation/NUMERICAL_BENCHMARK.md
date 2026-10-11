# Chapter 20 Independent Numerical Benchmark

Dataset SHA-256: `ed05316c9371b7a6f663c6eb1e6edfb980e0533dafe1c671f6a93e6410eab705`

## Static common-slope benchmark
- Two-way FE slopes: dlvalue = 0.484746682; dlcapital = -0.105150291.
- R-squared = 0.500977273; SSR = 6.543589197; residual df = 160.
- Period-clustered CR1 SEs: 0.078589838, 0.043752066.
- Classical slope-interaction test: F(18,142) = 1.369426153, p = 0.155726828.

## Static heterogeneous estimators
- Raw MG: dlvalue = 0.433118169 (SE 0.124410300); dlcapital = -0.671649512 (SE 0.342368881).
- Time-demeaned MG: dlvalue = 0.526462944 (SE 0.135152962); dlcapital = -0.148821130 (SE 0.072429144).
- Leave-one-firm-out DMG mean ranges: dlvalue [0.470166499, 0.650616311]; dlcapital [-0.196038569, -0.112563706].
- CCEMG: dlvalue = 0.377069366 (SE 0.144618441); dlcapital = -0.594943106 (SE 0.344037241).
- Leave-one-out CCEMG: dlvalue = 0.359163132 (SE 0.129643265); dlcapital = -0.681431864 (SE 0.374234037).

## Dynamic MG / PMG / DFE sensitivity
- MG mean phi = -0.708937893; median phi = -0.506352521; 5/10 adjustment coefficients significant at 5%.
- MG long-run value ratios: mean 1.962358971; median 1.067453542; range [0.401793729, 6.314478224].
- MG long-run capital ratios: mean 0.038200865; median 0.313173264; range [-2.712283799, 0.632279347].
- Transparent PSS-PMG restriction: theta_value = 0.652908123; theta_capital = 0.196112440; teaching NLS SEs = 0.122743533, 0.076724893; SSR = 6.522618428.
- PMG adjustment: 9/10 negative; mean = -0.520057788.
- DFE: phi = -0.284928883; theta_value = 0.871070689; theta_capital = 0.194448438; current dlvalue = 0.631314332; current dlcapital = 0.001873508; SSR = 8.841932634.
- Descriptive PMG-vs-MG restriction: F(18,130) = 1.332094766, p = 0.178435141.
- Descriptive DFE-vs-MG restriction: F(45,130) = 1.749536331, p = 0.007895063.

## Interpretation
The average market-value-growth slope remains positive under common-slope, MG, DMG, and CCE treatments. The capital-growth coefficient is negative on average but substantially more estimator-sensitive. Dynamic long-run ratios are fragile because some firm adjustment coefficients are near zero, and the PSS-PMG result remains a qualified sensitivity given N=10, T=20, cross-sectional dependence, and Chapter 17's conditional cointegration evidence.
