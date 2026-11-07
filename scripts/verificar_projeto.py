#!/usr/bin/env python3
"""Verificação estática executável sem Mac; NÃO substitui compilar no Xcode."""
from __future__ import annotations
import pathlib
import plistlib
import re
import shutil
import subprocess
import sys
import json

ROOT = pathlib.Path(__file__).resolve().parents[1]
PROJECT = ROOT / "ios/Morvan.xcodeproj/project.pbxproj"
IOS = ROOT / "ios/Morvan"
REQUIRED = [
    PROJECT,
        ROOT / "ios/Morvan.xcodeproj/xcshareddata/xcschemes/Morvan.xcscheme",
    ROOT / "ios/Morvan/Assets.xcassets/AppIcon.appiconset/Contents.json",
    ROOT / "ios/Morvan/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png",
    ROOT / ".github/workflows/verificar.yml",
    ROOT / ".github/workflows/gerar-ipa-gratis.yml",
]
for path in REQUIRED:
    assert path.is_file(), f"Arquivo não encontrado: {path}"
pbx = PROJECT.read_text(encoding="utf-8")
assert "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;" in pbx
assert "IPHONEOS_DEPLOYMENT_TARGET = 17.0;" in pbx
assert "TARGETED_DEVICE_FAMILY = 1;" in pbx
assert "MorvanTests" in pbx
assert "LocalProcessing.swift in Sources" in pbx
assert "NSSpeechRecognitionUsageDescription" in pbx
all_swift = "\n".join(path.read_text(encoding="utf-8") for path in (ROOT / "ios/Morvan").glob("*.swift"))
assert "requiresOnDeviceRecognition = true" in all_swift
assert "supportsOnDeviceRecognition" in all_swift
assert "MorvanAPI(" not in all_swift
assert "URLSession(" not in all_swift
assert "https://" not in all_swift
assert "Assets.xcassets in Resources" in pbx

assets = json.loads((IOS / "Assets.xcassets/AppIcon.appiconset/Contents.json").read_text(encoding="utf-8"))
assert any(x.get("filename") == "AppIcon-1024.png" for x in assets["images"])
with (IOS / "Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png").open("rb") as f:
    raw = f.read(24)
assert raw[:8] == bytes.fromhex("89504E470D0A1A0A")
assert int.from_bytes(raw[16:20], "big") == 1024
assert int.from_bytes(raw[20:24], "big") == 1024
with (IOS / "PrivacyInfo.xcprivacy").open("rb") as f:
    plistlib.load(f)

swift_files = sorted((ROOT / "ios").rglob("*.swift"))
assert len(swift_files) >= 11, "Arquivos Swift ausentes"
if shutil.which("swiftc"):
    result = subprocess.run(
        ["swiftc", "-frontend", "-parse", *(str(f) for f in swift_files)],
        text=True, capture_output=True, check=False,
    )
    if result.returncode:
        print(result.stderr, file=sys.stderr)
        raise SystemExit("Falha na análise de sintaxe Swift")
    print(f"Sintaxe Swift: OK ({len(swift_files)} arquivos).")
else:
    print("Swift indisponível: a sintaxe será verificada no workflow macOS.")

print("Estrutura, ícone e bloqueio de API paga: OK.")
print("ATENÇÃO: sem SDK iOS/macOS, isto não valida compilação nem assinatura.")
