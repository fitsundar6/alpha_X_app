import os
import re

lib_dir = r"c:\Users\johng\.gemini\antigravity-ide\scratch\alpha_x_gym\apps\mobile\lib"

# 1. Identify all Screens / Dialogs / Sheets
client_screens = []
admin_screens = []
shared_screens = []

for root, dirs, files in os.walk(lib_dir):
    for f in files:
        if f.endswith('.dart'):
            full_path = os.path.join(root, f)
            rel_path = os.path.relpath(full_path, lib_dir).replace('\\', '/')
            is_screen = (
                f.endswith('_screen.dart') or 
                f.endswith('_dialog.dart') or 
                f.endswith('_sheet.dart') or 
                f.endswith('_modal.dart') or 
                f.endswith('_tab.dart') or
                'screen' in f.lower()
            )
            if is_screen:
                if 'admin' in rel_path.lower():
                    admin_screens.append(rel_path)
                elif 'client' in rel_path.lower():
                    client_screens.append(rel_path)
                elif any(k in rel_path.lower() for k in ['auth', 'onboarding', 'macro_planner', 'activity', 'food_photo', 'telemetry', 'workout']):
                    # Check if client or shared
                    client_screens.append(rel_path)
                else:
                    shared_screens.append(rel_path)

print(f"Client Screens/Dialogs/Sheets ({len(client_screens)}):")
for s in sorted(client_screens):
    print(f"  - {s}")

print(f"\nAdmin Screens/Dialogs/Sheets ({len(admin_screens)}):")
for s in sorted(admin_screens):
    print(f"  - {s}")

print(f"\nShared / Core Screens/Dialogs/Sheets ({len(shared_screens)}):")
for s in sorted(shared_screens):
    print(f"  - {s}")

# 2. Reusable widgets in core/widgets
widgets_dir = os.path.join(lib_dir, 'core', 'widgets')
widgets = [f for f in os.listdir(widgets_dir) if f.endswith('.dart')]
print(f"\nCore Reusable Widgets ({len(widgets)}):")
for w in sorted(widgets):
    print(f"  - {w}")

# 3. Theme files
theme_dir = os.path.join(lib_dir, 'core', 'theme')
theme_files = [f for f in os.listdir(theme_dir) if f.endswith('.dart')]
print(f"\nTheme Files ({len(theme_files)}):")
for t in sorted(theme_files):
    print(f"  - {t}")

# 4. Assets
assets_dir = r"c:\Users\johng\.gemini\antigravity-ide\scratch\alpha_x_gym\apps\mobile\assets"
print("\nAssets:")
for root, dirs, files in os.walk(assets_dir):
    for f in files:
        rel = os.path.relpath(os.path.join(root, f), assets_dir).replace('\\', '/')
        print(f"  - {rel}")
