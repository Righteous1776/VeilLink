# Veilopoly Astra B01 v1.1

Owner 授权入库的完整资产包；仅进入独立资产接收目录，尚未接入游戏。原 B01 v1 在本地保留。入库授权与接入边界见 `INTAKE.md`。

本版 91 个 SVG/PNG 资源别名（90 运行 + 1 参考），15 张横屏布局预览；新增 21 个纸质桌游组件，包含五张 256×174pt 紧凑操作主卡。

1. 用浏览器打开 `index.html`，切换三个横屏尺寸查看五个界面。
2. 看 `REFERENCE_DELTA.md` 了解本次参考修订，`MANIFEST.md` 看交付边界。
3. 程序仅导入 `ui/` 中需要的 SVG/PNG；不要把 `previews/` 整屏图片当游戏贴图。
4. `ASSET_MANIFEST.json` 查别名、尺寸、透明区、状态、文字槽、伸缩边距；`SPRITE_MAP.json` 查布局和锚点。
5. 接入前读 `sources/INTEGRATION.md`；本地验证记录见 `VALIDATION.md`。

金额、玩家名称、状态和地产数据全部由程序绑定。银行仅为游戏积分展示，未批准的金融规则保留禁用态。棋盘、城市和模型由 Kimi 提供；包内左侧棋盘线框只是定位标记。

源文件可用 Inkscape、Illustrator 或 Figma 导入编辑。重建依赖 Python 3、Pillow、Inkscape；`sources/build_assets.py` 会重新生成资产，手工修改 SVG 前请先保留副本。`python sources/package_and_verify.py` 校验导出文件并重建清单/ZIP；它不运行 iOS 或游戏测试。
