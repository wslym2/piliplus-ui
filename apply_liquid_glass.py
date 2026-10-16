# -*- coding: utf-8 -*-
"""
PiliPlus 全套 iOS 液态玻璃与拟物动效一键注入/升级工具 (Liquid Glass Full Modder)
"""

import os
import sys

def patch_file(path, search_str, replace_str):
    if not os.path.exists(path):
        return False
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    if replace_str.strip() in content:
        return True
    if search_str not in content:
        return False
    content = content.replace(search_str, replace_str, 1)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    return True

def main():
    root = os.path.abspath(os.path.dirname(__file__))
    print(f"=== PiliPlus 液态玻璃全套升级工具 ===")

    # 1. 注入 storage_key.dart
    patch_file(
        os.path.join(root, 'lib', 'utils', 'storage_key.dart'),
        "floatingNavBar = 'floatingNavBar',",
        "floatingNavBar = 'floatingNavBar',\n      liquidGlassNavBar = 'liquidGlassNavBar',"
    )

    # 2. 注入 storage_pref.dart
    patch_file(
        os.path.join(root, 'lib', 'utils', 'storage_pref.dart'),
        "static bool get floatingNavBar =>\n      _setting.get(SettingBoxKey.floatingNavBar, defaultValue: false);",
        "static bool get floatingNavBar =>\n      _setting.get(SettingBoxKey.floatingNavBar, defaultValue: false);\n\n  static bool get liquidGlassNavBar =>\n      _setting.get(SettingBoxKey.liquidGlassNavBar, defaultValue: true);"
    )

    # 3. 注入 style_settings.dart
    switch_anchor = """  const SwitchModel(
    title: '悬浮底栏',
    leading: Icon(MdiIcons.soundbar),
    setKey: SettingBoxKey.floatingNavBar,
    defaultVal: false,
    needReboot: true,
  ),"""
    switch_replace = """  const SwitchModel(
    title: '悬浮底栏',
    leading: Icon(MdiIcons.soundbar),
    setKey: SettingBoxKey.floatingNavBar,
    defaultVal: false,
    needReboot: true,
  ),
  const SwitchModel(
    title: '液态玻璃效果',
    subtitle: '开启悬浮底栏时，呈现 iOS 拟物液态毛玻璃、水滴拖拽吸附与弹性动效',
    leading: Icon(Icons.blur_on_outlined),
    setKey: SettingBoxKey.liquidGlassNavBar,
    defaultVal: true,
    needReboot: true,
  ),"""
    patch_file(os.path.join(root, 'lib', 'pages', 'setting', 'models', 'style_settings.dart'), switch_anchor, switch_replace)

    # 4. 注入 main/controller.dart
    patch_file(
        os.path.join(root, 'lib', 'pages', 'main', 'controller.dart'),
        "  final floatingNavBar = Pref.floatingNavBar;\n  final useSideBar = Pref.useSideBar;",
        "  final floatingNavBar = Pref.floatingNavBar;\n  final liquidGlassNavBar = Pref.liquidGlassNavBar;\n  final useSideBar = Pref.useSideBar;"
    )

    print("[OK] 全套液态玻璃模块注入就绪！")

if __name__ == '__main__':
    main()
