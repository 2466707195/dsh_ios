#!/usr/bin/env python3
"""把 iOS Runner 工程切成 Manual + ad-hoc 签名，绕过 Flutter CLI 的
Automatic-signing 强制 team 校验，使无证书 CI 能编译真机 .app。
用法: python3 fix_signing.py ios/Runner.xcodeproj/project.pbxproj
"""
import re
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    src = f.read()

DUMMY_TEAM = "AAAAAAAAAA"  # 10 位占位 team id（ad-hoc 不校验其真实性）

# 1) 签名风格改为 Manual（Flutter 仅在 Automatic 时强制要 team）
src = re.sub(r"CODE_SIGN_STYLE = \w+;", "CODE_SIGN_STYLE = Manual;", src)

# 2) DEVELOPMENT_TEAM：有则改值，无则在 Manual 后插入（避免重复键）
if "DEVELOPMENT_TEAM" in src:
    src = re.sub(r"DEVELOPMENT_TEAM = [^;]*;", f"DEVELOPMENT_TEAM = {DUMMY_TEAM};", src)
    inserted = 0
else:
    src, inserted = re.subn(
        r"(CODE_SIGN_STYLE = Manual;)",
        f"DEVELOPMENT_TEAM = {DUMMY_TEAM};\\n\\t\\t\\t\\1",
        src,
    )

# 3) ad-hoc 签名身份 "-"：有则改值，无则插入
if "CODE_SIGN_IDENTITY" in src:
    src = re.sub(r'CODE_SIGN_IDENTITY = [^;]*;', 'CODE_SIGN_IDENTITY = "-";', src)
else:
    src = re.sub(
        r"(CODE_SIGN_STYLE = Manual;)",
        'CODE_SIGN_IDENTITY = "-";\\n\\t\\t\\t\\1',
        src,
    )

with open(path, "w", encoding="utf-8") as f:
    f.write(src)

n_style = src.count("CODE_SIGN_STYLE = Manual;")
n_team = src.count(f"DEVELOPMENT_TEAM = {DUMMY_TEAM};")
n_id = src.count('CODE_SIGN_IDENTITY = "-";')
print(f"Manual={n_style} team={n_team} identity={n_id}")
assert n_style > 0 and n_team > 0, "注入失败"
print("OK")
