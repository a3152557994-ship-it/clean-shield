#!/usr/bin/env python3
"""Generate deterministic CleanShield.xcodeproj with 4 targets:
- CleanShield (iOS 18.0+ App)
- CleanShieldBlocker (Safari Content Blocker Extension)
- CleanShieldWidgets (Home Screen WidgetKit Extension)
- CleanShieldTests (XCTest Unit Test Bundle)
"""

from __future__ import annotations

import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROJ_DIR = ROOT / "CleanShield.xcodeproj"
PROJ_DIR.mkdir(parents=True, exist_ok=True)


def uid(tag: str) -> str:
    return hashlib.md5(f"cleanshield::{tag}".encode("utf-8")).hexdigest()[:24].upper()


def rel_sources(subdir: str, ext: str = ".swift") -> list[str]:
    base = ROOT / subdir
    if not base.exists():
        return []
    return sorted([p.relative_to(ROOT).as_posix() for p in base.rglob(f"*{ext}")])


def main() -> None:
    shared_sources = rel_sources("Sources/Shared", ".swift")
    app_only_sources = [s for s in rel_sources("Sources", ".swift") if s not in shared_sources]
    app_sources = sorted(shared_sources + app_only_sources)
    blocker_sources = sorted(
        ["Sources/Shared/SharedModels.swift", "Sources/Shared/BlockerRuleCompiler.swift"]
        + rel_sources("BlockerExtension", ".swift")
    )
    widget_sources = sorted(
        ["Sources/Shared/SharedModels.swift", "Sources/Shared/AuditCatalog.swift"]
        + rel_sources("Widgets", ".swift")
    )
    test_sources = rel_sources("Tests", ".swift")

    asset_catalog = "Resources/Assets.xcassets"
    privacy_manifest = "Resources/PrivacyInfo.xcprivacy"
    blocker_json = "BlockerExtension/blockerList.json"

    app_info_plist = "Config/Info.plist"
    blocker_info_plist = "Config/Blocker-Info.plist"
    widget_info_plist = "Config/Widget-Info.plist"

    app_entitlements = "Config/CleanShield.entitlements"
    blocker_entitlements = "Config/CleanShieldBlocker.entitlements"
    widget_entitlements = "Config/CleanShieldWidgets.entitlements"
    storekit_config = "Config/CleanShield.storekit"

    file_refs: dict[str, tuple[str, str, str, str]] = {}
    build_files: dict[str, tuple[str, str, str | None]] = {}

    def add_file(rel_path: str, file_type: str, name: str | None = None, path_attr: str | None = None) -> str:
        if rel_path in file_refs:
            return file_refs[rel_path][0]
        fid = uid(f"fileref::{rel_path}")
        file_refs[rel_path] = (fid, file_type, name or Path(rel_path).name, path_attr or rel_path)
        return fid

    for s in app_sources:
        fid = add_file(s, "sourcecode.swift")
        build_files[f"app_src::{s}"] = (uid(f"bf_app::{s}"), fid, None)

    for s in blocker_sources:
        fid = add_file(s, "sourcecode.swift")
        build_files[f"blocker_src::{s}"] = (uid(f"bf_blocker::{s}"), fid, None)

    for s in widget_sources:
        fid = add_file(s, "sourcecode.swift")
        build_files[f"widget_src::{s}"] = (uid(f"bf_widget::{s}"), fid, None)

    for s in test_sources:
        fid = add_file(s, "sourcecode.swift")
        build_files[f"test_src::{s}"] = (uid(f"bf_test::{s}"), fid, None)

    zh_strings_fid = add_file(
        "Resources/zh-Hans.lproj/InfoPlist.strings",
        "text.plist.strings",
        name="zh-Hans",
        path_attr="Resources/zh-Hans.lproj/InfoPlist.strings",
    )
    en_strings_fid = add_file(
        "Resources/en.lproj/InfoPlist.strings",
        "text.plist.strings",
        name="en",
        path_attr="Resources/en.lproj/InfoPlist.strings",
    )
    strings_vg_id = uid("variantgroup::InfoPlist.strings")
    build_files["app_res::InfoPlist.strings"] = (uid("bf_app_res::InfoPlist.strings"), strings_vg_id, None)

    assets_fid = add_file(asset_catalog, "folder.assetcatalog")
    build_files["app_res::Assets.xcassets"] = (uid("bf_app_res::Assets.xcassets"), assets_fid, None)

    privacy_fid = add_file(privacy_manifest, "text.xml")
    build_files["app_res::PrivacyInfo.xcprivacy"] = (uid("bf_app_res::PrivacyInfo.xcprivacy"), privacy_fid, None)
    build_files["blocker_res::PrivacyInfo.xcprivacy"] = (uid("bf_blocker_res::PrivacyInfo.xcprivacy"), privacy_fid, None)
    build_files["widget_res::PrivacyInfo.xcprivacy"] = (uid("bf_widget_res::PrivacyInfo.xcprivacy"), privacy_fid, None)

    blocker_json_fid = add_file(blocker_json, "text.json")
    build_files["blocker_res::blockerList.json"] = (uid("bf_blocker_res::blockerList.json"), blocker_json_fid, None)

    storekit_fid = add_file(storekit_config, "text.json")
    build_files["test_res::CleanShield.storekit"] = (uid("bf_test_res::CleanShield.storekit"), storekit_fid, None)

    for cfg_file, ftype in [
        (app_info_plist, "text.plist.xml"),
        (blocker_info_plist, "text.plist.xml"),
        (widget_info_plist, "text.plist.xml"),
        (app_entitlements, "text.plist.entitlements"),
        (blocker_entitlements, "text.plist.entitlements"),
        (widget_entitlements, "text.plist.entitlements"),
    ]:
        add_file(cfg_file, ftype)

    app_product_id = uid("product::CleanShield.app")
    blocker_product_id = uid("product::CleanShieldBlocker.appex")
    widget_product_id = uid("product::CleanShieldWidgets.appex")
    test_product_id = uid("product::CleanShieldTests.xctest")

    build_files["embed::CleanShieldBlocker.appex"] = (
        uid("bf_embed::CleanShieldBlocker.appex"),
        blocker_product_id,
        "ATTRIBUTES = (RemoveHeadersOnCopy, );",
    )
    build_files["embed::CleanShieldWidgets.appex"] = (
        uid("bf_embed::CleanShieldWidgets.appex"),
        widget_product_id,
        "ATTRIBUTES = (RemoveHeadersOnCopy, );",
    )

    root_group_id = uid("group::root")
    sources_group_id = uid("group::Sources")
    blocker_group_id = uid("group::BlockerExtension")
    widgets_group_id = uid("group::Widgets")
    tests_group_id = uid("group::Tests")
    resources_group_id = uid("group::Resources")
    config_group_id = uid("group::Config")
    products_group_id = uid("group::Products")

    app_sources_phase = uid("phase::app_sources")
    app_frameworks_phase = uid("phase::app_frameworks")
    app_resources_phase = uid("phase::app_resources")
    app_embed_phase = uid("phase::app_embed_extensions")

    blocker_sources_phase = uid("phase::blocker_sources")
    blocker_frameworks_phase = uid("phase::blocker_frameworks")
    blocker_resources_phase = uid("phase::blocker_resources")

    widget_sources_phase = uid("phase::widget_sources")
    widget_frameworks_phase = uid("phase::widget_frameworks")
    widget_resources_phase = uid("phase::widget_resources")

    test_sources_phase = uid("phase::test_sources")
    test_frameworks_phase = uid("phase::test_frameworks")
    test_resources_phase = uid("phase::test_resources")

    project_id = uid("project::CleanShield")
    app_target_id = uid("target::CleanShield")
    blocker_target_id = uid("target::CleanShieldBlocker")
    widget_target_id = uid("target::CleanShieldWidgets")
    test_target_id = uid("target::CleanShieldTests")

    app_blocker_dep_id = uid("target_dep::CleanShieldBlocker")
    app_blocker_proxy_id = uid("proxy::CleanShieldBlocker")
    app_widget_dep_id = uid("target_dep::CleanShieldWidgets")
    app_widget_proxy_id = uid("proxy::CleanShieldWidgets")
    test_dep_id = uid("target_dep::CleanShield")
    test_proxy_id = uid("proxy::CleanShield")

    proj_cfg_list = uid("cfglist::project")
    app_cfg_list = uid("cfglist::app")
    blocker_cfg_list = uid("cfglist::blocker")
    widget_cfg_list = uid("cfglist::widget")
    test_cfg_list = uid("cfglist::test")

    proj_debug_cfg = uid("cfg::proj::Debug")
    proj_release_cfg = uid("cfg::proj::Release")
    app_debug_cfg = uid("cfg::app::Debug")
    app_release_cfg = uid("cfg::app::Release")
    blocker_debug_cfg = uid("cfg::blocker::Debug")
    blocker_release_cfg = uid("cfg::blocker::Release")
    widget_debug_cfg = uid("cfg::widget::Debug")
    widget_release_cfg = uid("cfg::widget::Release")
    test_debug_cfg = uid("cfg::test::Debug")
    test_release_cfg = uid("cfg::test::Release")

    lines: list[str] = []
    w = lines.append

    w("// !$*UTF8*$!")
    w("{")
    w("\tarchiveVersion = 1;")
    w("\tclasses = {")
    w("\t};")
    w("\tobjectVersion = 56;")
    w("\tobjects = {")
    w("")

    # PBXBuildFile
    w("/* Begin PBXBuildFile section */")
    for key, (bf_id, f_id, settings) in sorted(build_files.items()):
        if settings:
            w(f"\t\t{bf_id} /* {key} */ = {{isa = PBXBuildFile; fileRef = {f_id}; settings = {{{settings} }}; }};")
        else:
            w(f"\t\t{bf_id} /* {key} */ = {{isa = PBXBuildFile; fileRef = {f_id}; }};")
    w("/* End PBXBuildFile section */")
    w("")

    # PBXContainerItemProxy
    w("/* Begin PBXContainerItemProxy section */")
    for proxy_id, remote_id, rname in [
        (app_blocker_proxy_id, blocker_target_id, "CleanShieldBlocker"),
        (app_widget_proxy_id, widget_target_id, "CleanShieldWidgets"),
        (test_proxy_id, app_target_id, "CleanShield"),
    ]:
        w(f"\t\t{proxy_id} /* PBXContainerItemProxy */ = {{")
        w("\t\t\tisa = PBXContainerItemProxy;")
        w(f"\t\t\tcontainerPortal = {project_id};")
        w("\t\t\tproxyType = 1;")
        w(f"\t\t\tremoteGlobalIDString = {remote_id};")
        w(f"\t\t\tremoteInfo = {rname};")
        w("\t\t};")
    w("/* End PBXContainerItemProxy section */")
    w("")

    # PBXCopyFilesBuildPhase
    w("/* Begin PBXCopyFilesBuildPhase section */")
    w(f"\t\t{app_embed_phase} /* Embed Foundation Extensions */ = {{")
    w("\t\t\tisa = PBXCopyFilesBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w('\t\t\tdstPath = "";')
    w("\t\t\tdstSubfolderSpec = 13;")
    w("\t\t\tfiles = (")
    w(f"\t\t\t\t{build_files['embed::CleanShieldBlocker.appex'][0]} /* CleanShieldBlocker.appex */,")
    w(f"\t\t\t\t{build_files['embed::CleanShieldWidgets.appex'][0]} /* CleanShieldWidgets.appex */,")
    w("\t\t\t);")
    w('\t\t\tname = "Embed Foundation Extensions";')
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")
    w("/* End PBXCopyFilesBuildPhase section */")
    w("")

    # PBXFileReference
    w("/* Begin PBXFileReference section */")
    w(f"\t\t{app_product_id} /* CleanShield.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = CleanShield.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    w(f'\t\t{blocker_product_id} /* CleanShieldBlocker.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = CleanShieldBlocker.appex; sourceTree = BUILT_PRODUCTS_DIR; }};')
    w(f'\t\t{widget_product_id} /* CleanShieldWidgets.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = CleanShieldWidgets.appex; sourceTree = BUILT_PRODUCTS_DIR; }};')
    w(f"\t\t{test_product_id} /* CleanShieldTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = CleanShieldTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
    for rel_path, (fid, ftype, fname, path_attr) in sorted(file_refs.items()):
        w(f'\t\t{fid} /* {rel_path} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; name = "{fname}"; path = "{path_attr}"; sourceTree = SOURCE_ROOT; }};')
    w("/* End PBXFileReference section */")
    w("")

    # PBXFrameworksBuildPhase
    w("/* Begin PBXFrameworksBuildPhase section */")
    for fp in [app_frameworks_phase, blocker_frameworks_phase, widget_frameworks_phase, test_frameworks_phase]:
        w(f"\t\t{fp} /* Frameworks */ = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};")
    w("/* End PBXFrameworksBuildPhase section */")
    w("")

    # PBXGroup
    w("/* Begin PBXGroup section */")
    w(f"\t\t{root_group_id} = {{")
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    for gid, gname in [
        (sources_group_id, "Sources"),
        (blocker_group_id, "BlockerExtension"),
        (widgets_group_id, "Widgets"),
        (tests_group_id, "Tests"),
        (resources_group_id, "Resources"),
        (config_group_id, "Config"),
        (products_group_id, "Products"),
    ]:
        w(f"\t\t\t\t{gid} /* {gname} */,")
    w("\t\t\t);")
    w('\t\t\tsourceTree = "<group>";')
    w("\t\t};")

    def emit_group(gid: str, name: str, child_ids: list[tuple[str, str]]) -> None:
        w(f"\t\t{gid} /* {name} */ = {{")
        w("\t\t\tisa = PBXGroup;")
        w("\t\t\tchildren = (")
        for cid, cname in child_ids:
            w(f"\t\t\t\t{cid} /* {cname} */,")
        w("\t\t\t);")
        w(f"\t\t\tname = {name};")
        w('\t\t\tsourceTree = "<group>";')
        w("\t\t};")

    emit_group(sources_group_id, "Sources", [(file_refs[s][0], s) for s in app_sources])
    emit_group(
        blocker_group_id,
        "BlockerExtension",
        [(file_refs[s][0], s) for s in rel_sources("BlockerExtension", ".swift")] + [(blocker_json_fid, "blockerList.json")],
    )
    emit_group(widgets_group_id, "Widgets", [(file_refs[s][0], s) for s in rel_sources("Widgets", ".swift")])
    emit_group(tests_group_id, "Tests", [(file_refs[s][0], s) for s in test_sources])
    emit_group(
        resources_group_id,
        "Resources",
        [(assets_fid, "Assets.xcassets"), (privacy_fid, "PrivacyInfo.xcprivacy"), (strings_vg_id, "InfoPlist.strings")],
    )
    emit_group(
        config_group_id,
        "Config",
        [
            (file_refs[app_info_plist][0], "Info.plist"),
            (file_refs[blocker_info_plist][0], "Blocker-Info.plist"),
            (file_refs[widget_info_plist][0], "Widget-Info.plist"),
            (file_refs[app_entitlements][0], "CleanShield.entitlements"),
            (file_refs[blocker_entitlements][0], "CleanShieldBlocker.entitlements"),
            (file_refs[widget_entitlements][0], "CleanShieldWidgets.entitlements"),
            (storekit_fid, "CleanShield.storekit"),
        ],
    )
    emit_group(
        products_group_id,
        "Products",
        [
            (app_product_id, "CleanShield.app"),
            (blocker_product_id, "CleanShieldBlocker.appex"),
            (widget_product_id, "CleanShieldWidgets.appex"),
            (test_product_id, "CleanShieldTests.xctest"),
        ],
    )
    w("/* End PBXGroup section */")
    w("")

    # PBXNativeTarget
    w("/* Begin PBXNativeTarget section */")
    w(f"\t\t{app_target_id} /* CleanShield */ = {{")
    w("\t\t\tisa = PBXNativeTarget;")
    w(f"\t\t\tbuildConfigurationList = {app_cfg_list};")
    w("\t\t\tbuildPhases = (")
    w(f"\t\t\t\t{app_sources_phase} /* Sources */,")
    w(f"\t\t\t\t{app_frameworks_phase} /* Frameworks */,")
    w(f"\t\t\t\t{app_resources_phase} /* Resources */,")
    w(f"\t\t\t\t{app_embed_phase} /* Embed Foundation Extensions */,")
    w("\t\t\t);")
    w("\t\t\tbuildRules = ();")
    w(f"\t\t\tdependencies = ({app_blocker_dep_id}, {app_widget_dep_id});")
    w("\t\t\tname = CleanShield;")
    w("\t\t\tproductName = CleanShield;")
    w(f"\t\t\tproductReference = {app_product_id} /* CleanShield.app */;")
    w('\t\t\tproductType = "com.apple.product-type.application";')
    w("\t\t};")

    for tid, tname, cfg_l, sp, fp, rp, prod_id, ptype, deps in [
        (
            blocker_target_id,
            "CleanShieldBlocker",
            blocker_cfg_list,
            blocker_sources_phase,
            blocker_frameworks_phase,
            blocker_resources_phase,
            blocker_product_id,
            "com.apple.product-type.app-extension",
            "",
        ),
        (
            widget_target_id,
            "CleanShieldWidgets",
            widget_cfg_list,
            widget_sources_phase,
            widget_frameworks_phase,
            widget_resources_phase,
            widget_product_id,
            "com.apple.product-type.app-extension",
            "",
        ),
        (
            test_target_id,
            "CleanShieldTests",
            test_cfg_list,
            test_sources_phase,
            test_frameworks_phase,
            test_resources_phase,
            test_product_id,
            "com.apple.product-type.bundle.unit-test",
            test_dep_id,
        ),
    ]:
        w(f"\t\t{tid} /* {tname} */ = {{")
        w("\t\t\tisa = PBXNativeTarget;")
        w(f"\t\t\tbuildConfigurationList = {cfg_l};")
        w("\t\t\tbuildPhases = (")
        w(f"\t\t\t\t{sp} /* Sources */,")
        w(f"\t\t\t\t{fp} /* Frameworks */,")
        w(f"\t\t\t\t{rp} /* Resources */,")
        w("\t\t\t);")
        w("\t\t\tbuildRules = ();")
        w(f"\t\t\tdependencies = ({deps});")
        w(f"\t\t\tname = {tname};")
        w(f"\t\t\tproductName = {tname};")
        w(f"\t\t\tproductReference = {prod_id};")
        w(f'\t\t\tproductType = "{ptype}";')
        w("\t\t};")
    w("/* End PBXNativeTarget section */")
    w("")

    # PBXProject
    w("/* Begin PBXProject section */")
    w(f"\t\t{project_id} /* Project object */ = {{")
    w("\t\t\tisa = PBXProject;")
    w("\t\t\tattributes = {")
    w("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    w("\t\t\t\tLastUpgradeCheck = 2720;")
    w("\t\t\t\tTargetAttributes = {")
    w(f"\t\t\t\t\t{app_target_id} = {{ CreatedOnToolsVersion = 27.2; }};")
    w(f"\t\t\t\t\t{blocker_target_id} = {{ CreatedOnToolsVersion = 27.2; }};")
    w(f"\t\t\t\t\t{widget_target_id} = {{ CreatedOnToolsVersion = 27.2; }};")
    w(f"\t\t\t\t\t{test_target_id} = {{ CreatedOnToolsVersion = 27.2; TestTargetID = {app_target_id}; }};")
    w("\t\t\t\t};")
    w("\t\t\t};")
    w(f"\t\t\tbuildConfigurationList = {proj_cfg_list};")
    w('\t\t\tcompatibilityVersion = "Xcode 14.0";')
    w('\t\t\tdevelopmentRegion = "zh-Hans";')
    w("\t\t\thasScannedForEncodings = 0;")
    w('\t\t\tknownRegions = ("zh-Hans", en, Base);')
    w(f"\t\t\tmainGroup = {root_group_id};")
    w(f"\t\t\tproductRefGroup = {products_group_id} /* Products */;")
    w('\t\t\tprojectDirPath = "";')
    w('\t\t\tprojectRoot = "";')
    w("\t\t\ttargets = (")
    w(f"\t\t\t\t{app_target_id} /* CleanShield */,")
    w(f"\t\t\t\t{blocker_target_id} /* CleanShieldBlocker */,")
    w(f"\t\t\t\t{widget_target_id} /* CleanShieldWidgets */,")
    w(f"\t\t\t\t{test_target_id} /* CleanShieldTests */,")
    w("\t\t\t);")
    w("\t\t};")
    w("/* End PBXProject section */")
    w("")

    # PBXResourcesBuildPhase
    w("/* Begin PBXResourcesBuildPhase section */")
    for rp_id, keys in [
        (app_resources_phase, ["app_res::Assets.xcassets", "app_res::PrivacyInfo.xcprivacy", "app_res::InfoPlist.strings"]),
        (blocker_resources_phase, ["blocker_res::blockerList.json", "blocker_res::PrivacyInfo.xcprivacy"]),
        (widget_resources_phase, ["widget_res::PrivacyInfo.xcprivacy"]),
        (test_resources_phase, ["test_res::CleanShield.storekit"]),
    ]:
        w(f"\t\t{rp_id} /* Resources */ = {{")
        w("\t\t\tisa = PBXResourcesBuildPhase;")
        w("\t\t\tbuildActionMask = 2147483647;")
        w("\t\t\tfiles = (")
        for k in keys:
            w(f"\t\t\t\t{build_files[k][0]} /* {k} */,")
        w("\t\t\t);")
        w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
        w("\t\t};")
    w("/* End PBXResourcesBuildPhase section */")
    w("")

    # PBXSourcesBuildPhase
    w("/* Begin PBXSourcesBuildPhase section */")
    for phase_id, prefix, items in [
        (app_sources_phase, "app_src", app_sources),
        (blocker_sources_phase, "blocker_src", blocker_sources),
        (widget_sources_phase, "widget_src", widget_sources),
        (test_sources_phase, "test_src", test_sources),
    ]:
        w(f"\t\t{phase_id} /* Sources */ = {{")
        w("\t\t\tisa = PBXSourcesBuildPhase;")
        w("\t\t\tbuildActionMask = 2147483647;")
        w("\t\t\tfiles = (")
        for s in items:
            w(f"\t\t\t\t{build_files[f'{prefix}::{s}'][0]} /* {s} */,")
        w("\t\t\t);")
        w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
        w("\t\t};")
    w("/* End PBXSourcesBuildPhase section */")
    w("")

    # PBXTargetDependency
    w("/* Begin PBXTargetDependency section */")
    for dep_id, tid, pid in [
        (app_blocker_dep_id, blocker_target_id, app_blocker_proxy_id),
        (app_widget_dep_id, widget_target_id, app_widget_proxy_id),
        (test_dep_id, app_target_id, test_proxy_id),
    ]:
        w(f"\t\t{dep_id} /* PBXTargetDependency */ = {{")
        w("\t\t\tisa = PBXTargetDependency;")
        w(f"\t\t\ttarget = {tid};")
        w(f"\t\t\ttargetProxy = {pid};")
        w("\t\t};")
    w("/* End PBXTargetDependency section */")
    w("")

    # PBXVariantGroup
    w("/* Begin PBXVariantGroup section */")
    w(f"\t\t{strings_vg_id} /* InfoPlist.strings */ = {{")
    w("\t\t\tisa = PBXVariantGroup;")
    w("\t\t\tchildren = (")
    w(f"\t\t\t\t{zh_strings_fid} /* zh-Hans */,")
    w(f"\t\t\t\t{en_strings_fid} /* en */,")
    w("\t\t\t);")
    w("\t\t\tname = InfoPlist.strings;")
    w('\t\t\tsourceTree = "<group>";')
    w("\t\t};")
    w("/* End PBXVariantGroup section */")
    w("")

    # XCBuildConfiguration
    w("/* Begin XCBuildConfiguration section */")
    common_proj = [
        "ALWAYS_SEARCH_USER_PATHS = NO",
        "CLANG_ENABLE_MODULES = YES",
        "CLANG_ENABLE_OBJC_ARC = YES",
        "CODE_SIGN_STYLE = Automatic",
        "DEVELOPMENT_TEAM = KU364788TC",
        "ENABLE_STRICT_OBJC_MSGSEND = YES",
        "IPHONEOS_DEPLOYMENT_TARGET = 18.0",
        "MARKETING_VERSION = 1.0.0",
        "CURRENT_PROJECT_VERSION = 1",
        "SDKROOT = iphoneos",
        'SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"',
        "SWIFT_VERSION = 5.0",
        'TARGETED_DEVICE_FAMILY = "1,2"',
    ]

    def emit_cfg(cid: str, name: str, settings: list[str]) -> None:
        w(f"\t\t{cid} /* {name} */ = {{")
        w("\t\t\tisa = XCBuildConfiguration;")
        w("\t\t\tbuildSettings = {")
        for line in settings:
            w(f"\t\t\t\t{line};")
        w("\t\t\t};")
        w(f"\t\t\tname = {name};")
        w("\t\t};")

    emit_cfg(
        proj_debug_cfg,
        "Debug",
        common_proj
        + [
            "DEBUG_INFORMATION_FORMAT = dwarf",
            "ENABLE_TESTABILITY = YES",
            "GCC_OPTIMIZATION_LEVEL = 0",
            "ONLY_ACTIVE_ARCH = YES",
            'SWIFT_OPTIMIZATION_LEVEL = "-Onone"',
            'SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG"',
        ],
    )
    emit_cfg(
        proj_release_cfg,
        "Release",
        common_proj
        + [
            'DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"',
            "ENABLE_NS_ASSERTIONS = NO",
            'SWIFT_OPTIMIZATION_LEVEL = "-O"',
            "VALIDATE_PRODUCT = YES",
        ],
    )

    app_common = [
        "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor",
        'CODE_SIGN_ENTITLEMENTS = "Config/CleanShield.entitlements"',
        "GENERATE_INFOPLIST_FILE = NO",
        'INFOPLIST_FILE = "Config/Info.plist"',
        'LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks"',
        "PRODUCT_BUNDLE_IDENTIFIER = com.yanghe.cleanshield",
        "PRODUCT_NAME = CleanShield",
        "SWIFT_EMIT_LOC_STRINGS = YES",
    ]
    emit_cfg(app_debug_cfg, "Debug", app_common + ['CODE_SIGN_IDENTITY = "Apple Development"'])
    emit_cfg(
        app_release_cfg,
        "Release",
        app_common
        + [
            "CODE_SIGN_STYLE = Manual",
            'CODE_SIGN_IDENTITY = "Apple Distribution"',
            'PROVISIONING_PROFILE_SPECIFIER = "CleanShield AppStore Dist"',
        ],
    )

    blocker_common = [
        "APPLICATION_EXTENSION_API_ONLY = YES",
        'CODE_SIGN_ENTITLEMENTS = "Config/CleanShieldBlocker.entitlements"',
        "GENERATE_INFOPLIST_FILE = NO",
        'INFOPLIST_FILE = "Config/Blocker-Info.plist"',
        'LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks"',
        "PRODUCT_BUNDLE_IDENTIFIER = com.yanghe.cleanshield.blocker",
        'PRODUCT_NAME = "$(TARGET_NAME)"',
        "SKIP_INSTALL = YES",
        "SWIFT_EMIT_LOC_STRINGS = YES",
    ]
    emit_cfg(blocker_debug_cfg, "Debug", blocker_common + ['CODE_SIGN_IDENTITY = "Apple Development"'])
    emit_cfg(
        blocker_release_cfg,
        "Release",
        blocker_common
        + [
            "CODE_SIGN_STYLE = Manual",
            'CODE_SIGN_IDENTITY = "Apple Distribution"',
            'PROVISIONING_PROFILE_SPECIFIER = "CleanShield Blocker AppStore Dist"',
        ],
    )

    widget_common = [
        "APPLICATION_EXTENSION_API_ONLY = YES",
        'CODE_SIGN_ENTITLEMENTS = "Config/CleanShieldWidgets.entitlements"',
        "GENERATE_INFOPLIST_FILE = NO",
        'INFOPLIST_FILE = "Config/Widget-Info.plist"',
        'LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks"',
        "PRODUCT_BUNDLE_IDENTIFIER = com.yanghe.cleanshield.widgets",
        'PRODUCT_NAME = "$(TARGET_NAME)"',
        "SKIP_INSTALL = YES",
        "SWIFT_EMIT_LOC_STRINGS = YES",
    ]
    emit_cfg(widget_debug_cfg, "Debug", widget_common + ['CODE_SIGN_IDENTITY = "Apple Development"'])
    emit_cfg(
        widget_release_cfg,
        "Release",
        widget_common
        + [
            "CODE_SIGN_STYLE = Manual",
            'CODE_SIGN_IDENTITY = "Apple Distribution"',
            'PROVISIONING_PROFILE_SPECIFIER = "CleanShield Widgets AppStore Dist"',
        ],
    )

    test_common = [
        'BUNDLE_LOADER = "$(TEST_HOST)"',
        "GENERATE_INFOPLIST_FILE = YES",
        'LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks @loader_path/Frameworks"',
        "PRODUCT_BUNDLE_IDENTIFIER = com.yanghe.cleanshield.tests",
        'PRODUCT_NAME = "$(TARGET_NAME)"',
        'TEST_HOST = "$(BUILT_PRODUCTS_DIR)/CleanShield.app/CleanShield"',
    ]
    emit_cfg(test_debug_cfg, "Debug", test_common)
    emit_cfg(test_release_cfg, "Release", test_common)
    w("/* End XCBuildConfiguration section */")
    w("")

    # XCConfigurationList
    w("/* Begin XCConfigurationList section */")
    for list_id, label, d_id, r_id in [
        (proj_cfg_list, "PBXProject CleanShield", proj_debug_cfg, proj_release_cfg),
        (app_cfg_list, "PBXNativeTarget CleanShield", app_debug_cfg, app_release_cfg),
        (blocker_cfg_list, "PBXNativeTarget CleanShieldBlocker", blocker_debug_cfg, blocker_release_cfg),
        (widget_cfg_list, "PBXNativeTarget CleanShieldWidgets", widget_debug_cfg, widget_release_cfg),
        (test_cfg_list, "PBXNativeTarget CleanShieldTests", test_debug_cfg, test_release_cfg),
    ]:
        w(f"\t\t{list_id} /* Build configuration list for {label} */ = {{")
        w("\t\t\tisa = XCConfigurationList;")
        w("\t\t\tbuildConfigurations = (")
        w(f"\t\t\t\t{d_id} /* Debug */,")
        w(f"\t\t\t\t{r_id} /* Release */,")
        w("\t\t\t);")
        w("\t\t\tdefaultConfigurationIsVisible = 0;")
        w("\t\t\tdefaultConfigurationName = Release;")
        w("\t\t};")
    w("/* End XCConfigurationList section */")
    w("\t};")
    w(f"\trootObject = {project_id} /* Project object */;")
    w("}")

    (PROJ_DIR / "project.pbxproj").write_text("\n".join(lines) + "\n", encoding="utf-8")

    schemes_dir = PROJ_DIR / "xcshareddata" / "xcschemes"
    schemes_dir.mkdir(parents=True, exist_ok=True)
    scheme_xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2720"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{app_target_id}"
               BuildableName = "CleanShield.app"
               BlueprintName = "CleanShield"
               ReferencedContainer = "container:CleanShield.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{blocker_target_id}"
               BuildableName = "CleanShieldBlocker.appex"
               BlueprintName = "CleanShieldBlocker"
               ReferencedContainer = "container:CleanShield.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{widget_target_id}"
               BuildableName = "CleanShieldWidgets.appex"
               BlueprintName = "CleanShieldWidgets"
               ReferencedContainer = "container:CleanShield.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{test_target_id}"
               BuildableName = "CleanShieldTests.xctest"
               BlueprintName = "CleanShieldTests"
               ReferencedContainer = "container:CleanShield.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{app_target_id}"
            BuildableName = "CleanShield.app"
            BlueprintName = "CleanShield"
            ReferencedContainer = "container:CleanShield.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
      <StoreKitConfigurationFileReference
         identifier = "../../Config/CleanShield.storekit">
      </StoreKitConfigurationFileReference>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{app_target_id}"
            BuildableName = "CleanShield.app"
            BlueprintName = "CleanShield"
            ReferencedContainer = "container:CleanShield.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""
    (schemes_dir / "CleanShield.xcscheme").write_text(scheme_xml, encoding="utf-8")
    print(
        f"Generated {PROJ_DIR}: {len(app_sources)} app, {len(blocker_sources)} blocker, "
        f"{len(widget_sources)} widget, {len(test_sources)} test sources."
    )


if __name__ == "__main__":
    main()
