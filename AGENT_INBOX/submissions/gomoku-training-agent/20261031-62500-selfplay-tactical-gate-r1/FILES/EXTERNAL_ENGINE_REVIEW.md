# External engine/model shortlist (research only)

1. Rapfi — https://github.com/dotb1ue/rapfi — strong alpha-beta + classical/NNUE, supports freestyle Gomoku and Renju variants; explicitly GPL-3.0. Use as **external benchmark/training teacher**, not vendored iOS binary, until license+rules+hardware verified.
2. AlphaZero_Gomoku — https://github.com/junxiaosong/AlphaZero_Gomoku — self-play + MCTS + PyTorch, but older small-board examples; do not assume 15x15 weights work or are competitive.
3. Alpha-Zero-Gomoku — https://github.com/Augustusmyc/Alpha-Zero-Gomoku — C++ self-play, PyTorch training, ONNX runtime, README MIT; supports Gomoku+Xiangqi, but deployment/performance/rules/weights require audit.
4. 15x15 checkpoint candidate — https://huggingface.co/maojh15/GomokuZeroAI — public 15x15 PyTorch checkpoint described; licensing/provenance and native inference are unverified. No checkpoint downloaded or embedded.

Decision: recommend a separate research branch to benchmark against Rapfi and train a 15x15 network with independent label rules; keep shipping native engine unless that candidate is objectively better. No binary weights in Inbox.
