# SOURCE NOTES

仅使用 TrollStore 官方仓库作为 marker 语义依据：

- Repository: `opa334/TrollStore`
- Inspected commit: `88424f683b2a08f34a3f88985f790f97d84ce1df`
- `Shared/TSUtil.h` 定义 `TS_MARKER` 为 `_TrollStore`、`TS_LITE_MARKER` 为 `_TrollStoreLite`。
- `RootHelper/main.m` 在应用 bundle container 写入 active marker，并用它识别 TrollStore 管理的应用。
- Source URLs:
  - https://github.com/opa334/TrollStore/blob/88424f683b2a08f34a3f88985f790f97d84ce1df/Shared/TSUtil.h
  - https://github.com/opa334/TrollStore/blob/88424f683b2a08f34a3f88985f790f97d84ce1df/RootHelper/main.m

本提案只复用两个标记文件名和公开安装语义，没有复制 TrollStore 实现代码，也没有引入第三方二进制或许可证负担。
