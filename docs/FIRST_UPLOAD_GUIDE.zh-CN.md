# 第一次上传 GitHub

仓库名建议使用 `litrun`。

## 准备

- 完成 `docs/RELEASE_CHECKLIST.md`。
- 运行 `RUN_LIVE_TESTS=1 RUN_LAUNCH_SMOKE=1 ./scripts/package_release.sh`。
- 只发布当前项目文件夹；不要上传外层工作区、证书、密码或密钥。

## 上传

- 在 GitHub 创建空仓库，不重复生成 README、License 或 `.gitignore`。
- 上传源码时保留 `build/` 和 `dist/` 的忽略规则。
- 创建标签与 Release：`v3.0.0` / `不熄！ / LitRun! 3.0.0`。
- 上传 `dist/LitRun-v3.0.0-macOS13-universal.zip`、`dist/LitRun-v3.0.0-macOS13-universal.dmg` 及各自对应的 `.sha256`。

未使用 Developer ID 签名和公证时，只能把 Release 标为技术测试包，并明确说明 Gatekeeper 通常会拦截首次打开；不能宣传为普通用户双击即用。提交、打标签和推送前应完成最终检查。
