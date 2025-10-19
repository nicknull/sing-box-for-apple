# 脚本使用说明

## bump_build_version.sh

用于批量更新 Xcode 工程 (`sing-box.xcodeproj/project.pbxproj`) 中的 `CURRENT_PROJECT_VERSION`：

```bash
# 默认将当前 build 版本的最后一段数字 +1
scripts/bump_build_version.sh

# 手动指定目标 build 版本
scripts/bump_build_version.sh --set 4.2.0

# 指定其它工程文件
scripts/bump_build_version.sh --project path/to/other.xcodeproj/project.pbxproj
```

脚本会自动选择工程文件中最高的数字/语义版本作为基准，只更新与之相同的条目，其他保持不变。
