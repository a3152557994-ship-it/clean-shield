#!/usr/bin/env python3
"""App Store Connect 10-Locale Metadata, IAP & Binary Upload Automation for CleanShield (com.yanghe.cleanshield).

Uses ~/.appstoreconnect/private_keys/AuthKey_BD4GFRDCQ9.p8.
Usage:
  python3 /Users/wang/OPC/projects/clean-shield/Scripts/asc_sync.py
"""

from __future__ import annotations

import base64
import hashlib
import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

KEY_ID = "BD4GFRDCQ9"
ISSUER_ID = "ccf96e7a-0987-4f4b-aa61-863fccd82c33"
KEY_PATH = "/Users/wang/.appstoreconnect/private_keys/AuthKey_BD4GFRDCQ9.p8"
BUNDLE_ID = "com.yanghe.cleanshield"

PROJECT_ROOT = Path("/Users/wang/OPC/projects/clean-shield")
METADATA_JSON = PROJECT_ROOT / "release" / "ASC_METADATA_READY.json"
IPA_PATH = PROJECT_ROOT / "dist" / "ipa" / "CleanShield.ipa"
SCREENSHOT_ROOT = Path("/Users/wang/OPC/media/20261119-clean-shield/appstore")


def b64u(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def make_jwt() -> str:
    header = b64u(json.dumps({"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}, separators=(",", ":")).encode())
    now = int(time.time())
    payload = b64u(
        json.dumps(
            {"iss": ISSUER_ID, "iat": now - 10, "exp": now + 900, "aud": "appstoreconnect-v1"},
            separators=(",", ":"),
        ).encode()
    )
    msg = f"{header}.{payload}".encode()
    der = subprocess.check_output(["openssl", "dgst", "-sha256", "-sign", KEY_PATH], input=msg)
    idx = 2 + ((der[1] & 0x7F) if (der[1] & 0x80) else 0)
    rlen = der[idx + 1]
    r = der[idx + 2 : idx + 2 + rlen].lstrip(b"\x00").rjust(32, b"\x00")
    idx = idx + 2 + rlen
    slen = der[idx + 1]
    s = der[idx + 2 : idx + 2 + slen].lstrip(b"\x00").rjust(32, b"\x00")
    return f"{header}.{payload}.{b64u(r + s)}"


def asc(method: str, path: str, body: dict | None = None) -> tuple[int, dict | str]:
    token = make_jwt()
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    req = urllib.request.Request(f"https://api.appstoreconnect.apple.com{path}", data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read().decode()
            return resp.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()


def upload_screenshot(set_id: str, png_path: Path) -> None:
    raw_bytes = png_path.read_bytes()
    checksum = hashlib.md5(raw_bytes).hexdigest()
    st, res = asc("POST", "/v1/appScreenshots", {
        "data": {
            "type": "appScreenshots",
            "attributes": {"fileSize": len(raw_bytes), "fileName": png_path.name},
            "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}},
        }
    })
    if st not in (200, 201) or not isinstance(res, dict):
        print(f"    ! Screenshot reserve failed for {png_path.name}: {st}")
        return
    shot_id = res["data"]["id"]
    for op in res["data"]["attributes"].get("uploadOperations", []):
        chunk = raw_bytes[op["offset"] : op["offset"] + op["length"]]
        hdrs = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        req = urllib.request.Request(op["url"], data=chunk, headers=hdrs, method=op["method"])
        urllib.request.urlopen(req, timeout=60).read()
    asc("PATCH", f"/v1/appScreenshots/{shot_id}", {
        "data": {
            "type": "appScreenshots",
            "id": shot_id,
            "attributes": {"uploaded": True, "sourceFileChecksum": checksum},
        }
    })
    print(f"    ✓ Uploaded screenshot {png_path.name}")


def main() -> None:
    meta = json.loads(METADATA_JSON.read_text(encoding="utf-8"))
    st, apps = asc("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}")
    if st != 200 or not isinstance(apps, dict) or not apps.get("data"):
        print(f"ℹ️ Bundle IDs '{BUNDLE_ID}' (+ .blocker, .widgets) are registered on Apple Developer Portal.")
        print("👉 Once the App Record is created in App Store Connect (+ -> New App -> com.yanghe.cleanshield), re-run this script to push all 10 locales, IAPs, screenshots, and binary.")
        return

    app_id = apps["data"][0]["id"]
    print(f"✅ Found App Record id={app_id} for {BUNDLE_ID}")

    # 1. Upload IPA if present
    if IPA_PATH.exists() and "--upload-ipa" in sys.argv:
        print(f"🚀 Uploading {IPA_PATH} via xcrun altool...")
        subprocess.run([
            "xcrun", "altool", "--upload-app",
            "--type", "ios",
            "-f", str(IPA_PATH),
            "--apiKey", KEY_ID,
            "--apiIssuer", ISSUER_ID,
        ], check=False)

    # 2. Sync AppInfo & Version Localizations across 10 global locales
    _, infos = asc("GET", f"/v1/apps/{app_id}/appInfos")
    app_info_id = infos["data"][0]["id"]
    _, existing_ilocs = asc("GET", f"/v1/appInfos/{app_info_id}/appInfoLocalizations?limit=50")
    iloc_map = {x["attributes"]["locale"]: x["id"] for x in existing_ilocs.get("data", [])}

    _, vers = asc("GET", f"/v1/apps/{app_id}/appStoreVersions?filter[platform]=IOS")
    ver_id = vers["data"][0]["id"]
    _, existing_vlocs = asc("GET", f"/v1/appStoreVersions/{ver_id}/appStoreVersionLocalizations?limit=50")
    vloc_map = {x["attributes"]["locale"]: x["id"] for x in existing_vlocs.get("data", [])}

    fallback_desc_en = meta["localizations"]["en-US"]["description"]

    for locale, ldata in meta["localizations"].items():
        if locale in iloc_map:
            asc("PATCH", f"/v1/appInfoLocalizations/{iloc_map[locale]}", {
                "data": {
                    "type": "appInfoLocalizations",
                    "id": iloc_map[locale],
                    "attributes": {
                        "name": ldata["name"],
                        "subtitle": ldata["subtitle"],
                        "privacyPolicyUrl": ldata["privacyPolicyUrl"],
                    },
                }
            })
        else:
            asc("POST", "/v1/appInfoLocalizations", {
                "data": {
                    "type": "appInfoLocalizations",
                    "attributes": {
                        "locale": locale,
                        "name": ldata["name"],
                        "subtitle": ldata["subtitle"],
                        "privacyPolicyUrl": ldata["privacyPolicyUrl"],
                    },
                    "relationships": {"appInfo": {"data": {"type": "appInfos", "id": app_info_id}}},
                }
            })

        desc = ldata.get("description", fallback_desc_en)
        v_attrs = {
            "keywords": ldata["keywords"],
            "supportUrl": ldata["supportUrl"],
            "description": desc,
        }
        if "promotionalText" in ldata:
            v_attrs["promotionalText"] = ldata["promotionalText"]

        if locale in vloc_map:
            vloc_id = vloc_map[locale]
            asc("PATCH", f"/v1/appStoreVersionLocalizations/{vloc_id}", {
                "data": {"type": "appStoreVersionLocalizations", "id": vloc_id, "attributes": v_attrs}
            })
        else:
            _, created_vl = asc("POST", "/v1/appStoreVersionLocalizations", {
                "data": {
                    "type": "appStoreVersionLocalizations",
                    "attributes": {"locale": locale, **v_attrs},
                    "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver_id}}},
                }
            })
            vloc_id = created_vl["data"]["id"] if isinstance(created_vl, dict) and "data" in created_vl else None

        print(f"  ✓ Synced locale: {locale} ({ldata['name']})")

        # Upload 6.5" screenshots for zh-Hans and en-US if requested
        if "--screenshots" in sys.argv and vloc_id and locale in ("zh-Hans", "en-US"):
            sdir = SCREENSHOT_ROOT / locale
            if sdir.exists():
                _, sets = asc("GET", f"/v1/appStoreVersionLocalizations/{vloc_id}/appScreenshotSets")
                set_id = None
                for s in sets.get("data", []):
                    if s["attributes"]["screenshotDisplayType"] == "APP_IPHONE_65":
                        set_id = s["id"]
                        break
                if not set_id:
                    _, cset = asc("POST", "/v1/appScreenshotSets", {
                        "data": {
                            "type": "appScreenshotSets",
                            "attributes": {"screenshotDisplayType": "APP_IPHONE_65"},
                            "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": vloc_id}}},
                        }
                    })
                    if isinstance(cset, dict) and "data" in cset:
                        set_id = cset["data"]["id"]
                if set_id:
                    for png in sorted(sdir.glob("*.png")):
                        upload_screenshot(set_id, png)

    # 3. Create Non-Consumable Lifetime IAP + Auto-Renewable Subscription Group if missing
    asc("POST", "/v2/inAppPurchases", {
        "data": {
            "type": "inAppPurchases",
            "attributes": {
                "name": "CleanShield Lifetime Unlock",
                "productId": "com.yanghe.cleanshield.lifetime",
                "inAppPurchaseType": "NON_CONSUMABLE",
                "familySharable": True,
            },
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
        }
    })
    _, sg = asc("POST", "/v1/subscriptionGroups", {
        "data": {
            "type": "subscriptionGroups",
            "attributes": {"referenceName": "CleanShield Pro"},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
        }
    })
    if isinstance(sg, dict) and "data" in sg:
        sg_id = sg["data"]["id"]
        for pid, rname, period in [
            ("com.yanghe.cleanshield.monthly", "CleanShield Monthly", "ONE_MONTH"),
            ("com.yanghe.cleanshield.yearly", "CleanShield Yearly", "ONE_YEAR"),
        ]:
            asc("POST", "/v1/subscriptions", {
                "data": {
                    "type": "subscriptions",
                    "attributes": {
                        "name": rname,
                        "productId": pid,
                        "subscriptionPeriod": period,
                        "familySharable": True,
                    },
                    "relationships": {"group": {"data": {"type": "subscriptionGroups", "id": sg_id}}},
                }
            })
        print("  ✓ Created Subscription Group & Monthly/Yearly/Lifetime IAP records")


if __name__ == "__main__":
    main()
