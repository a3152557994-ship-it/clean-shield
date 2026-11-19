#!/usr/bin/env python3
"""App Store Connect Complete Sync & Submission Prep for CleanShield (com.yanghe.cleanshield).

Uses ~/.appstoreconnect/private_keys/AuthKey_BD4GFRDCQ9.p8.
Usage:
  python3 /Users/wang/OPC/projects/clean-shield/Scripts/asc_sync.py [--upload-ipa] [--screenshots]
"""

from __future__ import annotations

import base64
import hashlib
import json
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Optional

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


def asc(method: str, path: str, body: dict | None = None) -> tuple[int, dict[str, Any] | str]:
    token = make_jwt()
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    url = path if path.startswith("http") else f"https://api.appstoreconnect.apple.com{path}"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read().decode()
            return resp.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, raw


def find_closest_price_point(endpoint: str, target_price: float) -> Optional[str]:
    next_url: Optional[str] = endpoint
    best_id: Optional[str] = None
    best_diff = 99999.0
    pages = 0
    while next_url and pages < 5:
        pages += 1
        st, res = asc("GET", next_url)
        if st != 200 or not isinstance(res, dict):
            return best_id
        for pp in res.get("data", []):
            p_str = pp.get("attributes", {}).get("customerPrice")
            if p_str is None:
                continue
            try:
                val = float(p_str)
            except ValueError:
                continue
            diff = abs(val - target_price)
            if diff < best_diff:
                best_diff = diff
                best_id = pp["id"]
                if diff <= 0.01:
                    return best_id
        next_url = res.get("links", {}).get("next")
    return best_id


def get_all_territory_ids() -> list[str]:
    st, res = asc("GET", "/v1/territories?limit=200")
    if st == 200 and isinstance(res, dict):
        return [t["id"] for t in res.get("data", [])]
    return ["USA", "CHN"]


def upload_binary_asset(reserve_endpoint: str, commit_endpoint_prefix: str, resource_type: str, rel_key: str, rel_type: str, rel_id: str, png_path: Path) -> None:
    raw_bytes = png_path.read_bytes()
    checksum = hashlib.md5(raw_bytes).hexdigest()
    st, res = asc("POST", reserve_endpoint, {
        "data": {
            "type": resource_type,
            "attributes": {"fileSize": len(raw_bytes), "fileName": png_path.name},
            "relationships": {rel_key: {"data": {"type": rel_type, "id": rel_id}}},
        }
    })
    if st not in (200, 201) or not isinstance(res, dict):
        print(f"    ! Asset reserve failed ({reserve_endpoint}) for {png_path.name}: {st} {res}")
        return
    asset_id = res["data"]["id"]
    for op in res["data"]["attributes"].get("uploadOperations", []):
        chunk = raw_bytes[op["offset"] : op["offset"] + op["length"]]
        hdrs = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        req = urllib.request.Request(op["url"], data=chunk, headers=hdrs, method=op["method"])
        urllib.request.urlopen(req, timeout=60).read()
    st_c, res_c = asc("PATCH", f"{commit_endpoint_prefix}/{asset_id}", {
        "data": {
            "type": resource_type,
            "id": asset_id,
            "attributes": {"uploaded": True, "sourceFileChecksum": checksum},
        }
    })
    print(f"    ✓ Uploaded {png_path.name} ({resource_type}) -> {st_c}")
    if st_c not in (200, 204):
        print("      commit note:", res_c)


def sync_screenshot_set(vloc_id: str, display_type: str, folder: Path) -> None:
    pngs = sorted(folder.glob("*.png"))
    if not pngs:
        return
    _, sets = asc("GET", f"/v1/appStoreVersionLocalizations/{vloc_id}/appScreenshotSets")
    set_id = None
    for s in sets.get("data", []) if isinstance(sets, dict) else []:
        if s["attributes"]["screenshotDisplayType"] == display_type:
            set_id = s["id"]
            break
    if set_id:
        _, existing = asc("GET", f"/v1/appScreenshotSets/{set_id}/appScreenshots")
        existing_items = existing.get("data", []) if isinstance(existing, dict) else []
        if len(existing_items) == len(pngs):
            print(f"    • {display_type} already has {len(existing_items)} screenshots in {folder.name}, skipping.")
            return
        for item in existing_items:
            asc("DELETE", f"/v1/appScreenshots/{item['id']}")
    else:
        st_c, cset = asc("POST", "/v1/appScreenshotSets", {
            "data": {
                "type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": display_type},
                "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": vloc_id}}},
            }
        })
        if st_c in (200, 201) and isinstance(cset, dict):
            set_id = cset["data"]["id"]
    if set_id:
        for png in pngs:
            upload_binary_asset("/v1/appScreenshots", "/v1/appScreenshots", "appScreenshots", "appScreenshotSet", "appScreenshotSets", set_id, png)


def sync_app_metadata_and_version(app_id: str, meta: dict[str, Any], territories: list[str]) -> str:
    print(f"[1/5] Updating App rights & categories for {app_id}...")
    st_app, res_app = asc("PATCH", f"/v1/apps/{app_id}", {
        "data": {
            "type": "apps",
            "id": app_id,
            "attributes": {
                "contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT",
                "primaryLocale": "zh-Hans",
            },
        }
    })
    print("  PATCH /v1/apps ->", st_app)
    if st_app not in (200, 204):
        print("   ", res_app)

    _, infos = asc("GET", f"/v1/apps/{app_id}/appInfos")
    app_info_id = infos["data"][0]["id"]
    st_cat, res_cat = asc("PATCH", f"/v1/appInfos/{app_info_id}", {
        "data": {
            "type": "appInfos",
            "id": app_info_id,
            "relationships": {
                "primaryCategory": {"data": {"type": "appCategories", "id": "UTILITIES"}},
                "secondaryCategory": {"data": {"type": "appCategories", "id": "PRODUCTIVITY"}},
            },
        }
    })
    print("  PATCH appInfos categories (UTILITIES / PRODUCTIVITY) ->", st_cat)
    if st_cat not in (200, 204):
        print("   ", res_cat)

    _, age_res = asc("GET", f"/v1/appInfos/{app_info_id}/ageRatingDeclaration")
    if isinstance(age_res, dict) and age_res.get("data"):
        age_id = age_res["data"]["id"]
        st_age, res_age = asc("PATCH", f"/v1/ageRatingDeclarations/{age_id}", {
            "data": {
                "type": "ageRatingDeclarations",
                "id": age_id,
                "attributes": {
                    "advertising": False,
                    "alcoholTobaccoOrDrugUseOrReferences": "NONE",
                    "contests": "NONE",
                    "gambling": False,
                    "gamblingSimulated": "NONE",
                    "gunsOrOtherWeapons": "NONE",
                    "healthOrWellnessTopics": False,
                    "kidsAgeBand": None,
                    "lootBox": False,
                    "medicalOrTreatmentInformation": "NONE",
                    "messagingAndChat": False,
                    "parentalControls": False,
                    "profanityOrCrudeHumor": "NONE",
                    "ageAssurance": False,
                    "sexualContentGraphicAndNudity": "NONE",
                    "sexualContentOrNudity": "NONE",
                    "socialMedia": False,
                    "socialMediaAgeRestricted": False,
                    "horrorOrFearThemes": "NONE",
                    "matureOrSuggestiveThemes": "NONE",
                    "unrestrictedWebAccess": False,
                    "userGeneratedContent": False,
                    "violenceCartoonOrFantasy": "NONE",
                    "violenceRealisticProlongedGraphicOrSadistic": "NONE",
                    "violenceRealistic": "NONE",
                },
            }
        })
        print("  PATCH ageRatingDeclarations (4+) ->", st_age)
        if st_age not in (200, 204):
            print("   ", res_age)

    print("[2/5] Ensuring App Availability & Free Base Pricing...")
    st_av, _ = asc("GET", f"/v2/appAvailabilities/{app_id}")
    if st_av == 404:
        avail_refs = [{"type": "territoryAvailabilities", "id": f"${{ta-{t}}}"} for t in territories]
        avail_inc = [
            {
                "type": "territoryAvailabilities",
                "id": f"${{ta-{t}}}",
                "attributes": {"available": True, "releaseDate": None, "preOrderEnabled": False},
                "relationships": {"territory": {"data": {"type": "territories", "id": t}}},
            }
            for t in territories
        ]
        st_post_av, res_post_av = asc("POST", "/v2/appAvailabilities", {
            "data": {
                "type": "appAvailabilities",
                "attributes": {"availableInNewTerritories": True},
                "relationships": {
                    "app": {"data": {"type": "apps", "id": app_id}},
                    "territoryAvailabilities": {"data": avail_refs},
                },
            },
            "included": avail_inc,
        })
        print(f"  POST /v2/appAvailabilities ({len(territories)} territories) -> {st_post_av}")
        if st_post_av not in (200, 201):
            print("   ", res_post_av)
    else:
        print("  • App Availability already configured.")

    usa_pp = find_closest_price_point(f"/v1/apps/{app_id}/appPricePoints?filter[territory]=USA&limit=50", 0.0)
    chn_pp = find_closest_price_point(f"/v1/apps/{app_id}/appPricePoints?filter[territory]=CHN&limit=50", 0.0)
    if usa_pp:
        manual_refs = [{"type": "appPrices", "id": "${price-usa}"}]
        included = [{
            "type": "appPrices",
            "id": "${price-usa}",
            "attributes": {"startDate": None},
            "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": usa_pp}}},
        }]
        if chn_pp:
            manual_refs.append({"type": "appPrices", "id": "${price-chn}"})
            included.append({
                "type": "appPrices",
                "id": "${price-chn}",
                "attributes": {"startDate": None},
                "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": chn_pp}}},
            })
        st_ps, res_ps = asc("POST", "/v1/appPriceSchedules", {
            "data": {
                "type": "appPriceSchedules",
                "relationships": {
                    "app": {"data": {"type": "apps", "id": app_id}},
                    "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                    "manualPrices": {"data": manual_refs},
                },
            },
            "included": included,
        })
        print("  POST appPriceSchedules (FREE) ->", st_ps)
        if st_ps not in (200, 201):
            print("   ", res_ps)

    print("[3/5] Syncing Version 1.0.0, Localizations, ReviewDetails & Build...")
    _, vers = asc("GET", f"/v1/apps/{app_id}/appStoreVersions?filter[platform]=IOS")
    ver_id = vers["data"][0]["id"]
    st_v, res_v = asc("PATCH", f"/v1/appStoreVersions/{ver_id}", {
        "data": {
            "type": "appStoreVersions",
            "id": ver_id,
            "attributes": {
                "versionString": "1.0.0",
                "copyright": "2026 Yang He",
                "releaseType": "AFTER_APPROVAL",
            },
        }
    })
    print("  PATCH appStoreVersions (1.0.0 / 2026 Yang He) ->", st_v)
    if st_v not in (200, 204):
        print("   ", res_v)

    _, existing_ilocs = asc("GET", f"/v1/appInfos/{app_info_id}/appInfoLocalizations?limit=50")
    iloc_map = {x["attributes"]["locale"]: x["id"] for x in existing_ilocs.get("data", [])}
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

        v_attrs = {
            "keywords": ldata["keywords"],
            "supportUrl": ldata["supportUrl"],
            "description": ldata.get("description", fallback_desc_en),
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

        if vloc_id and locale in ("zh-Hans", "en-US"):
            print(f"  Syncing screenshots for {locale}...")
            sync_screenshot_set(vloc_id, "APP_IPHONE_65", SCREENSHOT_ROOT / locale)
            sync_screenshot_set(vloc_id, "APP_IPAD_PRO_3GEN_129", SCREENSHOT_ROOT / "ipad" / locale)

    # Review Details
    review_notes = (
        "CleanShield (净盾) is a 100% offline iOS privacy & Safari content blocker utility with zero servers and zero data collection.\n\n"
        "How to verify all features:\n"
        "1. Privacy Audit Tab: Top 10 core guides (including Motion Sensor lock, ATT, Pasteboard & 180-Day WeChat Reset Reminder) are free; remaining 20+ items demonstrate the StoreKit 2 Pro Paywall (with Restore Purchases, Privacy Policy, EULA, and non-hostile free fallback).\n"
        "2. Web Shield Tab: Uses Apple's declarative SFContentBlocker API (no webpage-read/password permissions requested) and enforces a 26-domain safe whitelist at the end of the ruleset using ignore-previous-rules.\n"
        "3. Tools Tab: Pick any photo to inspect and scrub EXIF/GPS coordinates locally in memory, and test direct-launch shortcuts / Home Screen widgets."
    )
    review_attrs = {
        "contactFirstName": "Yang",
        "contactLastName": "He",
        "contactPhone": "+86 196 3394 8182",
        "contactEmail": "a3152557994@gmail.com",
        "demoAccountRequired": False,
        "notes": review_notes,
    }
    st_r, res_r = asc("GET", f"/v1/appStoreVersions/{ver_id}/appStoreReviewDetail")
    if st_r == 200 and isinstance(res_r, dict) and res_r.get("data"):
        rd_id = res_r["data"]["id"]
        st_rp, res_rp = asc("PATCH", f"/v1/appStoreReviewDetails/{rd_id}", {
            "data": {"type": "appStoreReviewDetails", "id": rd_id, "attributes": review_attrs}
        })
        print("  PATCH appStoreReviewDetails ->", st_rp)
    else:
        st_rp, res_rp = asc("POST", "/v1/appStoreReviewDetails", {
            "data": {
                "type": "appStoreReviewDetails",
                "attributes": review_attrs,
                "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver_id}}},
            }
        })
        print("  POST appStoreReviewDetails ->", st_rp)

    # Attach latest VALID build
    _, blds = asc("GET", f"/v1/builds?filter[app]={app_id}&sort=-uploadedDate&limit=10")
    valid_build = next((b for b in blds.get("data", []) if b["attributes"].get("processingState") == "VALID"), None)
    if valid_build:
        st_b, res_b = asc("PATCH", f"/v1/appStoreVersions/{ver_id}/relationships/build", {
            "data": {"type": "builds", "id": valid_build["id"]}
        })
        print(f"  Attached VALID build {valid_build['attributes']['version']} ({valid_build['id']}) -> {st_b}")
        if st_b not in (200, 204):
            print("   ", res_b)
    return ver_id


def sync_all_iaps(app_id: str, territories: list[str]) -> None:
    print("[4/5] Configuring Lifetime IAP & Monthly/Yearly Subscriptions to READY_TO_SUBMIT...")
    review_shot = SCREENSHOT_ROOT / "zh-Hans" / "04-pro.png"

    # --- A. Lifetime Non-Consumable ---
    _, iap_list = asc("GET", f"/v1/apps/{app_id}/inAppPurchasesV2?limit=50")
    existing_iaps = {x["attributes"]["productId"]: x["id"] for x in iap_list.get("data", [])}
    life_pid = "com.yanghe.cleanshield.lifetime"
    life_id = existing_iaps.get(life_pid)
    if not life_id:
        _, created = asc("POST", "/v2/inAppPurchases", {
            "data": {
                "type": "inAppPurchases",
                "attributes": {
                    "name": "CleanShield Lifetime Unlock",
                    "productId": life_pid,
                    "inAppPurchaseType": "NON_CONSUMABLE",
                    "familySharable": True,
                    "reviewNote": "Paywall triggered when tapping Pro audit guides, custom Safari rules, or extra widget slots.",
                },
                "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
            }
        })
        life_id = created["data"]["id"]
    else:
        asc("PATCH", f"/v2/inAppPurchases/{life_id}", {
            "data": {
                "type": "inAppPurchases",
                "id": life_id,
                "attributes": {
                    "familySharable": True,
                    "reviewNote": "Paywall triggered when tapping Pro audit guides, custom Safari rules, or extra widget slots.",
                },
            }
        })

    life_locs = {
        "zh-Hans": {"name": "净盾 Pro 永久买断", "description": "一次性解锁全部30项关广告图谱与自定义拦截规则"},
        "en-US": {"name": "CleanShield Pro Lifetime", "description": "One-time unlock for all 30+ guides & Pro rules"},
    }
    _, cur_locs = asc("GET", f"/v2/inAppPurchases/{life_id}/inAppPurchaseLocalizations")
    exist_ll = {x["attributes"]["locale"]: x["id"] for x in cur_locs.get("data", [])}
    for loc, attrs in life_locs.items():
        if loc in exist_ll:
            asc("PATCH", f"/v1/inAppPurchaseLocalizations/{exist_ll[loc]}", {
                "data": {"type": "inAppPurchaseLocalizations", "id": exist_ll[loc], "attributes": attrs}
            })
        else:
            st_l, res_l = asc("POST", "/v1/inAppPurchaseLocalizations", {
                "data": {
                    "type": "inAppPurchaseLocalizations",
                    "attributes": {"locale": loc, **attrs},
                    "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": life_id}}},
                }
            })
            print(f"  POST lifetime loc {loc} -> {st_l}")

    st_ia, _ = asc("GET", f"/v2/inAppPurchases/{life_id}/inAppPurchaseAvailability")
    if st_ia == 404:
        st_p, res_p = asc("POST", "/v1/inAppPurchaseAvailabilities", {
            "data": {
                "type": "inAppPurchaseAvailabilities",
                "attributes": {"availableInNewTerritories": True},
                "relationships": {
                    "inAppPurchase": {"data": {"type": "inAppPurchases", "id": life_id}},
                    "availableTerritories": {"data": [{"type": "territories", "id": t} for t in territories]},
                },
            }
        })
        print(f"  POST inAppPurchaseAvailabilities ({len(territories)}) -> {st_p}")
        if st_p not in (200, 201):
            print("   ", res_p)

    usa_pp = find_closest_price_point(f"/v2/inAppPurchases/{life_id}/pricePoints?filter[territory]=USA&limit=200", 6.99)
    chn_pp = find_closest_price_point(f"/v2/inAppPurchases/{life_id}/pricePoints?filter[territory]=CHN&limit=200", 25.0)
    if usa_pp:
        mrefs = [{"type": "inAppPurchasePrices", "id": "${iap-usa}"}]
        incs = [{
            "type": "inAppPurchasePrices",
            "id": "${iap-usa}",
            "attributes": {"startDate": None},
            "relationships": {
                "inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": life_id}},
                "inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": usa_pp}},
            },
        }]
        if chn_pp:
            mrefs.append({"type": "inAppPurchasePrices", "id": "${iap-chn}"})
            incs.append({
                "type": "inAppPurchasePrices",
                "id": "${iap-chn}",
                "attributes": {"startDate": None},
                "relationships": {
                    "inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": life_id}},
                    "inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": chn_pp}},
                },
            })
        st_ip, res_ip = asc("POST", "/v1/inAppPurchasePriceSchedules", {
            "data": {
                "type": "inAppPurchasePriceSchedules",
                "relationships": {
                    "inAppPurchase": {"data": {"type": "inAppPurchases", "id": life_id}},
                    "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                    "manualPrices": {"data": mrefs},
                },
            },
            "included": incs,
        })
        print("  POST lifetime price schedule ($6.99 / ¥25) ->", st_ip)
        if st_ip not in (200, 201):
            print("   ", res_ip)

    st_is, res_is = asc("GET", f"/v2/inAppPurchases/{life_id}/appStoreReviewScreenshot")
    if (st_is == 404 or not (isinstance(res_is, dict) and res_is.get("data"))) and review_shot.exists():
        upload_binary_asset(
            "/v1/inAppPurchaseAppStoreReviewScreenshots",
            "/v1/inAppPurchaseAppStoreReviewScreenshots",
            "inAppPurchaseAppStoreReviewScreenshots",
            "inAppPurchaseV2",
            "inAppPurchases",
            life_id,
            review_shot,
        )

    # --- B. Subscription Group & Plans ---
    _, sgs = asc("GET", f"/v1/apps/{app_id}/subscriptionGroups")
    sg_id = sgs["data"][0]["id"]
    _, cur_sgl = asc("GET", f"/v1/subscriptionGroups/{sg_id}/subscriptionGroupLocalizations")
    exist_sgl = {x["attributes"]["locale"]: x["id"] for x in cur_sgl.get("data", [])}
    sg_locs = {
        "zh-Hans": {"name": "净盾 Pro 会员", "customAppName": "净盾 CleanShield"},
        "en-US": {"name": "CleanShield Pro", "customAppName": "CleanShield"},
    }
    for loc, attrs in sg_locs.items():
        if loc not in exist_sgl:
            st_g, _ = asc("POST", "/v1/subscriptionGroupLocalizations", {
                "data": {
                    "type": "subscriptionGroupLocalizations",
                    "attributes": {"locale": loc, **attrs},
                    "relationships": {"subscriptionGroup": {"data": {"type": "subscriptionGroups", "id": sg_id}}},
                }
            })
            print(f"  POST subGroupLoc {loc} -> {st_g}")

    _, subs_res = asc("GET", f"/v1/subscriptionGroups/{sg_id}/subscriptions")
    sub_map = {x["attributes"]["productId"]: x["id"] for x in subs_res.get("data", [])}
    sub_specs = [
        {
            "pid": "com.yanghe.cleanshield.yearly",
            "groupLevel": 1,
            "usaPrice": 3.99,
            "chnPrice": 12.0,
            "locs": {
                "zh-Hans": {"name": "净盾 Pro 年度版", "description": "全年解锁全部关广告图谱与防强跳规则，可随时取消"},
                "en-US": {"name": "CleanShield Pro Yearly", "description": "Annual access to all 30+ guides & Pro rules"},
            },
        },
        {
            "pid": "com.yanghe.cleanshield.monthly",
            "groupLevel": 2,
            "usaPrice": 0.99,
            "chnPrice": 3.0,
            "locs": {
                "zh-Hans": {"name": "净盾 Pro 月度版", "description": "按月解锁全部关广告图谱与防强跳规则，可随时取消"},
                "en-US": {"name": "CleanShield Pro Monthly", "description": "Monthly access to all 30+ guides & Pro rules"},
            },
        },
    ]

    for spec in sub_specs:
        sid = sub_map.get(spec["pid"])
        if not sid:
            continue
        asc("PATCH", f"/v1/subscriptions/{sid}", {
            "data": {
                "type": "subscriptions",
                "id": sid,
                "attributes": {
                    "groupLevel": spec["groupLevel"],
                    "familySharable": True,
                    "reviewNote": "Presented inside PaywallSheet when tapping Pro guides or custom Safari filter controls.",
                },
            }
        })

        _, cur_sl = asc("GET", f"/v1/subscriptions/{sid}/subscriptionLocalizations")
        exist_sl = {x["attributes"]["locale"]: x["id"] for x in cur_sl.get("data", [])}
        for loc, attrs in spec["locs"].items():
            if loc in exist_sl:
                asc("PATCH", f"/v1/subscriptionLocalizations/{exist_sl[loc]}", {
                    "data": {"type": "subscriptionLocalizations", "id": exist_sl[loc], "attributes": attrs}
                })
            else:
                st_sl, _ = asc("POST", "/v1/subscriptionLocalizations", {
                    "data": {
                        "type": "subscriptionLocalizations",
                        "attributes": {"locale": loc, **attrs},
                        "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}}},
                    }
                })
                print(f"  POST subLoc {spec['pid']} {loc} -> {st_sl}")

        st_sa, _ = asc("GET", f"/v1/subscriptions/{sid}/subscriptionAvailability")
        if st_sa == 404:
            st_psa, res_psa = asc("POST", "/v1/subscriptionAvailabilities", {
                "data": {
                    "type": "subscriptionAvailabilities",
                    "attributes": {"availableInNewTerritories": True},
                    "relationships": {
                        "subscription": {"data": {"type": "subscriptions", "id": sid}},
                        "availableTerritories": {"data": [{"type": "territories", "id": t} for t in territories]},
                    },
                }
            })
            print(f"  POST subscriptionAvailabilities {spec['pid']} ({len(territories)}) -> {st_psa}")
            if st_psa not in (200, 201):
                print("   ", res_psa)

        # Subscription pricing across ALL territories using USA equalizations + CHN override
        _, cur_sp = asc("GET", f"/v1/subscriptions/{sid}/prices?limit=200")
        if len(cur_sp.get("data", []) if isinstance(cur_sp, dict) else []) < 5:
            usa_sp = find_closest_price_point(f"/v1/subscriptions/{sid}/pricePoints?filter[territory]=USA&limit=200", spec["usaPrice"])
            chn_sp = find_closest_price_point(f"/v1/subscriptions/{sid}/pricePoints?filter[territory]=CHN&limit=200", spec["chnPrice"])
            if usa_sp:
                eq_url: Optional[str] = f"/v1/subscriptionPricePoints/{usa_sp}/equalizations?limit=200&include=territory"
                ter_pp: dict[str, str] = {"USA": usa_sp}
                while eq_url:
                    st_eq, eq_res = asc("GET", eq_url)
                    if st_eq != 200 or not isinstance(eq_res, dict):
                        break
                    for item in eq_res.get("data", []):
                        tid = item.get("relationships", {}).get("territory", {}).get("data", {}).get("id")
                        if tid:
                            ter_pp[tid] = item["id"]
                    eq_url = eq_res.get("links", {}).get("next")
                if chn_sp:
                    ter_pp["CHN"] = chn_sp
                print(f"  Setting {len(ter_pp)} territory prices for {spec['pid']}...")
                ok_cnt = 0
                for tid, pp_id in ter_pp.items():
                    st_p, _ = asc("POST", "/v1/subscriptionPrices", {
                        "data": {
                            "type": "subscriptionPrices",
                            "attributes": {"preserveCurrentPrice": False, "startDate": None},
                            "relationships": {
                                "subscription": {"data": {"type": "subscriptions", "id": sid}},
                                "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": pp_id}},
                            },
                        }
                    })
                    if st_p in (200, 201):
                        ok_cnt += 1
                print(f"    ✓ Created {ok_cnt}/{len(ter_pp)} subscriptionPrices for {spec['pid']}")

        st_ss, res_ss = asc("GET", f"/v1/subscriptions/{sid}/appStoreReviewScreenshot")
        if (st_ss == 404 or not (isinstance(res_ss, dict) and res_ss.get("data"))) and review_shot.exists():
            upload_binary_asset(
                "/v1/subscriptionAppStoreReviewScreenshots",
                "/v1/subscriptionAppStoreReviewScreenshots",
                "subscriptionAppStoreReviewScreenshots",
                "subscription",
                "subscriptions",
                sid,
                review_shot,
            )


def verify_readiness(app_id: str) -> None:
    print("[5/5] Verifying IAPs, Subscriptions & Version Readiness...")
    _, iaps = asc("GET", f"/v1/apps/{app_id}/inAppPurchasesV2")
    for x in iaps.get("data", []):
        print("  IAP:", x["attributes"]["productId"], "->", x["attributes"]["state"])
    _, sgs = asc("GET", f"/v1/apps/{app_id}/subscriptionGroups")
    for sg in sgs.get("data", []):
        _, subs = asc("GET", f"/v1/subscriptionGroups/{sg['id']}/subscriptions")
        for x in subs.get("data", []):
            print("  Sub:", x["attributes"]["productId"], "->", x["attributes"]["state"])
    _, vers = asc("GET", f"/v1/apps/{app_id}/appStoreVersions?filter[platform]=IOS&include=build")
    v = vers["data"][0]
    b = v.get("relationships", {}).get("build", {}).get("data")
    print("  Version:", v["attributes"]["versionString"], v["attributes"]["appStoreState"], "build:", b)


def main() -> None:
    meta = json.loads(METADATA_JSON.read_text(encoding="utf-8"))
    st, apps = asc("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}")
    if st != 200 or not isinstance(apps, dict) or not apps.get("data"):
        print(f"ERROR: App record for {BUNDLE_ID} not found in ASC.")
        sys.exit(1)

    app_id = apps["data"][0]["id"]
    print(f"✅ Found App Record id={app_id} for {BUNDLE_ID}")

    if IPA_PATH.exists() and "--upload-ipa" in sys.argv:
        print(f"🚀 Uploading {IPA_PATH} via xcrun altool...")
        subprocess.run([
            "xcrun", "altool", "--upload-app",
            "--type", "ios",
            "-f", str(IPA_PATH),
            "--apiKey", KEY_ID,
            "--apiIssuer", ISSUER_ID,
        ], check=False)

    territories = get_all_territory_ids()
    sync_app_metadata_and_version(app_id, meta, territories)
    sync_all_iaps(app_id, territories)
    verify_readiness(app_id)


if __name__ == "__main__":
    main()
