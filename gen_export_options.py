#!/usr/bin/env python3
"""生成 ExportOptions.plist

用法:
  python3 gen_export_options.py <bundle_id> <team_id> [method] [profile_name] [cert_name]

示例:
  python3 gen_export_options.py com.yg.calite K4M82K8J22 ad-hoc "CA Lite AdHoc" "Apple Distribution"

method 可选: ad-hoc / app-store / development / enterprise
profile_name 为空时不写 provisioningProfiles（由 xcode-project use-profiles 自动处理）
cert_name 默认 "Apple Distribution"
"""
import plistlib
import sys

bundle = sys.argv[1] if len(sys.argv) > 1 else "com.yg.calite"
team = sys.argv[2] if len(sys.argv) > 2 else ""
method = sys.argv[3] if len(sys.argv) > 3 else "ad-hoc"
prof = sys.argv[4] if len(sys.argv) > 4 else ""
cert = sys.argv[5] if len(sys.argv) > 5 else "Apple Distribution"

d = {
    "method": method,
    "teamID": team,
    "signingStyle": "manual",
    "signingCertificate": cert,
    "stripSwiftSymbols": True,
    "compileBitcode": False,
    "destination": "export",
}
if prof:
    d["provisioningProfiles"] = {bundle: prof}

with open("ExportOptions.plist", "wb") as f:
    plistlib.dump(d, f)

print("已生成 ExportOptions.plist:")
print("  method      =", method)
print("  teamID      =", team)
print("  certificate =", cert)
print("  bundle      =", bundle)
print("  profile     =", prof or "(自动匹配)")
