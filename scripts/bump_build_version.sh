#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
用法: bump_build_version.sh [--set <version>] [--project <pbxproj路径>]

- 不带参数时，自动查找 Xcode 工程的 build 版本并将最后一位数字 +1。
- 通过 --set 指定目标版本，例如 --set 4.0.0。
- 如需指定其它工程文件，使用 --project。
USAGE
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="$ROOT_DIR/sing-box.xcodeproj/project.pbxproj"
TARGET_VERSION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --set)
      [[ $# -ge 2 ]] || { echo "缺少版本号" >&2; exit 1; }
      TARGET_VERSION="$2"
      shift 2
      ;;
    --project)
      [[ $# -ge 2 ]] || { echo "缺少工程文件路径" >&2; exit 1; }
      PROJECT_FILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

python3 - "$PROJECT_FILE" "$TARGET_VERSION" <<'PY'
import re
import sys
from pathlib import Path

project_path = Path(sys.argv[1])
if not project_path.exists():
    sys.stderr.write(f"找不到工程文件: {project_path}\n")
    sys.exit(1)

requested_version = sys.argv[2] or None
content = project_path.read_text(encoding="utf-8")
pattern = re.compile(r"(CURRENT_PROJECT_VERSION = )([0-9A-Za-z_.-]+)(;)")
matches = list(pattern.finditer(content))
if not matches:
    sys.stderr.write("未在工程文件中找到 CURRENT_PROJECT_VERSION\n")
    sys.exit(1)

versions = [m.group(2) for m in matches]

def parse_version(value: str):
    parts = value.split('.')
    parsed = []
    for part in parts:
        if part.isdigit():
            parsed.append(int(part))
        else:
            return None
    return parsed

parse_results = [(parse_version(v), v) for v in versions]
numeric_versions = [item for item in parse_results if item[0] is not None]
if not numeric_versions:
    sys.stderr.write("无法解析 build 版本，请改用 --set 指定\n")
    sys.exit(1)

numeric_versions.sort(key=lambda item: (len(item[0]), item[0]))
current_version = numeric_versions[-1][1]

if requested_version:
    new_version = requested_version
else:
    numbers = numeric_versions[-1][0][:]
    numbers[-1] += 1
    new_version = '.'.join(str(n) for n in numbers)

if current_version == new_version:
    print("新旧版本相同，无需修改")
    sys.exit(0)

state = {"changed": False}

def replacer(match: re.Match):
    if match.group(2) == current_version:
        state["changed"] = True
        return f"{match.group(1)}{new_version}{match.group(3)}"
    return match.group(0)

updated_content = pattern.sub(replacer, content)

if not state["changed"]:
    sys.stderr.write("未找到需要更新的版本号，可能已经是目标版本\n")
    sys.exit(1)

project_path.write_text(updated_content, encoding="utf-8")
print(f"Build 版本已从 {current_version} 更新为 {new_version}")
PY
