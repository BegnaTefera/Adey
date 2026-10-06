# Graph Report - daycare_app  (2026-09-27)

## Corpus Check
- 57 files · ~28,478 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 52 file(s) not represented in the graph (top: .xcconfig 8, (none) 7, .xml 7)

## Summary
- 704 nodes · 890 edges · 44 communities (31 shown, 13 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 17 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- register_screen.dart
- win32_window.cpp
- child.dart
- registration_pdf.dart
- child_profile_screen.dart
- GeneratedPluginRegistrant.swift
- app_theme.dart
- children_store.dart
- app_shell.dart
- my_application.cc
- utils.cpp
- children_repository.dart
- billing_screen.dart
- children_screen.dart
- dashboard_screen.dart
- main.dart
- attendance_screen.dart
- expenses_screen.dart
- State
- manifest.json
- search_utils.dart
- expense.dart
- OnCreate
- authorized_pickup.dart
- MainActivity.kt
- c_users_mypanda_desktop_desktop_files_all_school_stuff_pojects_adeyabeba_daycare_app_flutter_daycare_app_ios_runner_generatedpluginregistrant_h
- _SignaturePainter
- Gender
- String?
- MessageHandler
- MessageHandler
- Win32Window
- FlutterWindow
- MaterialPageRoute
- Point
- Size
- rules/graphify.md
- workflows/graphify.md
- LaunchImage.imageset/README.md
- _EthiopianDatePickerDialog
- README.md

## God Nodes (most connected - your core abstractions)
1. `Win32Window` - 24 edges
2. `MessageHandler` - 12 edges
3. `FlutterWindow` - 10 edges
4. `Create` - 10 edges
5. `WndProc` - 10 edges
6. `MessageHandler` - 9 edges
7. `_MyApplication` - 7 edges
8. `OnCreate` - 7 edges
9. `WindowClassRegistrar` - 7 edges
10. `Destroy` - 7 edges

## Surprising Connections (you probably didn't know these)
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  windows/runner/main.cpp → windows/runner/utils.cpp
- `Win32Window::Win32Window()` --calls--> `Destroy`  [INFERRED]
  windows/runner/win32_window.cpp → windows/runner/win32_window.h
- `my_application_activate()` --calls--> `fl_register_plugins()`  [INFERRED]
  linux/runner/my_application.cc → linux/flutter/generated_plugin_registrant.cc
- `main()` --calls--> `my_application_new()`  [INFERRED]
  linux/runner/main.cc → linux/runner/my_application.cc
- `OnCreate` --calls--> `RegisterPlugins()`  [INFERRED]
  windows/runner/flutter_window.h → windows/flutter/generated_plugin_registrant.cc

## Import Cycles
- None detected.

## Communities (44 total, 13 thin omitted)

### Community 0 - "register_screen.dart"
Cohesion: 0.02
Nodes (96): class, ../data/document_storage.dart, ../data/registration_pdf.dart, ETDateTime, ETDateTime get, int get, _addPage, _addPickupPerson (+88 more)

### Community 1 - "win32_window.cpp"
Cohesion: 0.19
Nodes (13): dwmapi, wchar_t, Scale(), Create, Destroy, UpdateTheme, Win32Window::Win32Window(), WindowClassRegistrar (+5 more)

### Community 2 - "child.dart"
Cohesion: 0.04
Nodes (52): authorized_pickup.dart, dart:convert, additionalPickupPeople, allergies, amharicLabel, amount, attendance, AttendanceRecord (+44 more)

### Community 3 - "registration_pdf.dart"
Cohesion: 0.04
Nodes (47): dart:io, dart:typed_data, dart:ui, DateTime?, _documentsDir, DocumentStorage, verify, addressParts (+39 more)

### Community 4 - "child_profile_screen.dart"
Cohesion: 0.05
Nodes (44): _Dropdown, _SheetField, _activeTab, _addPickupPerson, _AttendanceTab, build, child, ChildProfileScreen (+36 more)

### Community 5 - "GeneratedPluginRegistrant.swift"
Cohesion: 0.06
Nodes (28): Any, Cocoa, file_selector_macos, Flutter, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, FlutterMacOS (+20 more)

### Community 6 - "app_theme.dart"
Cohesion: 0.05
Nodes (37): accent, accentForeground, AppColors, AppText, background, bigNumber, bodyMedium, bodyRegular (+29 more)

### Community 7 - "children_store.dart"
Cohesion: 0.06
Nodes (34): app_database.dart, bool get, ChangeNotifier, children_repository.dart, addChild, byId, _children, ChildrenStore (+26 more)

### Community 8 - "app_shell.dart"
Cohesion: 0.14
Nodes (14): children_screen.dart, dashboard_screen.dart, active, AppShell, _AppShellState, build, createState, icon (+6 more)

### Community 9 - "my_application.cc"
Cohesion: 0.08
Nodes (27): file_selector_plugin, FlPluginRegistry, flutter_linux, FlView, GApplication, gboolean, gchar, gdkx (+19 more)

### Community 10 - "utils.cpp"
Cohesion: 0.12
Nodes (19): dart_project, flutter_view_controller, flutter_windows, functional, _In_, _In_opt_, io, iostream (+11 more)

### Community 11 - "children_repository.dart"
Cohesion: 0.08
Nodes (22): Database?, AppDatabase, _createFeeTables, _db, _insertDefaultFeeTypes, instance, _open, ChildrenRepository (+14 more)

### Community 12 - "billing_screen.dart"
Cohesion: 0.06
Nodes (32): int?, Child, AgeBracket, FeeType, fromMap, label, maxMonths, minMonths (+24 more)

### Community 13 - "children_screen.dart"
Cohesion: 0.12
Nodes (17): child_profile_screen.dart, ../data/search_utils.dart, ChildrenScreen, _ChildrenScreenState, createState, dispose, _filter, initState (+9 more)

### Community 14 - "dashboard_screen.dart"
Cohesion: 0.14
Nodes (13): attendance_screen.dart, billing_screen.dart, expenses_screen.dart, IconData, createState, dispose, icon, initState (+5 more)

### Community 15 - "main.dart"
Cohesion: 0.17
Nodes (11): ../data/children_store.dart, ../data/fee_types_store.dart, Future, build, createState, DaycareApp, _initFuture, initState (+3 more)

### Community 16 - "attendance_screen.dart"
Cohesion: 0.15
Nodes (13): AttendanceStatus, AttendanceScreen, _AttendanceScreenState, build, createState, dispose, initState, _markChild (+5 more)

### Community 17 - "expenses_screen.dart"
Cohesion: 0.20
Nodes (10): ../data/expenses_store.dart, _addExpense, build, createState, dispose, ExpensesScreen, _ExpensesScreenState, initState (+2 more)

### Community 18 - "State"
Cohesion: 0.27
Nodes (10): _AppStartup, _AppStartupState, DashboardScreen, _DashboardScreenState, _ImmunizationGalleryDialog, _ImmunizationGalleryDialogState, RegisterScreen, _RegisterScreenState (+2 more)

### Community 19 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 20 - "search_utils.dart"
Cohesion: 0.20
Nodes (9): current, levenshteinDistance, matchesAllTokens, normalizeForSearch, previous, queryTokens, true, value (+1 more)

### Community 21 - "expense.dart"
Cohesion: 0.22
Nodes (8): amount, category, date, ExpenseItem, fromMap, id, note, toMap

### Community 22 - "OnCreate"
Cohesion: 0.20
Nodes (9): file_selector_windows, plugin_registry, PluginRegistry, RECT, RegisterPlugins(), OnCreate, GetClientArea, OnCreate (+1 more)

### Community 23 - "authorized_pickup.dart"
Cohesion: 0.33
Nodes (5): AuthorizedPickup, fromMap, name, phone, toMap

### Community 32 - "MessageHandler"
Cohesion: 0.18
Nodes (10): generated_plugin_registrant, optional, DartProject, HWND, LPARAM, LRESULT, UINT, WPARAM (+2 more)

### Community 33 - "MessageHandler"
Cohesion: 0.36
Nodes (10): HWND, LPARAM, LRESULT, UINT, WPARAM, EnableFullDpiSupportIfAvailable(), GetHandle, GetThisFromHandle (+2 more)

### Community 34 - "Win32Window"
Cohesion: 0.25
Nodes (9): OnDestroy, HWND, Win32Window, child_content_, OnDestroy, quit_on_close_, SetQuitOnClose, Show (+1 more)

### Community 35 - "FlutterWindow"
Cohesion: 0.33
Nodes (6): FlutterViewController, unique_ptr, FlutterWindow, flutter_controller_, project_, DartProject

### Community 36 - "MaterialPageRoute"
Cohesion: 0.50
Nodes (4): _openRegister, build, build, MaterialPageRoute

### Community 37 - "Point"
Cohesion: 0.50
Nodes (3): Point, x, y

### Community 38 - "Size"
Cohesion: 0.50
Nodes (3): Size, height, width

## Knowledge Gaps
- **391 isolated node(s):** `AppDatabase`, `instance`, `_db`, `_open`, `_createFeeTables` (+386 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 491 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **13 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Win32Window` connect `Win32Window` to `MessageHandler`, `win32_window.cpp`, `MessageHandler`, `FlutterWindow`, `Point`, `Size`, `utils.cpp`, `OnCreate`?**
  _High betweenness centrality (0.086) - this node is a cross-community bridge._
- **Why does `Gender` connect `Gender` to `register_screen.dart`, `child.dart`, `registration_pdf.dart`?**
  _High betweenness centrality (0.022) - this node is a cross-community bridge._
- **Why does `Child` connect `billing_screen.dart` to `child.dart`, `child_profile_screen.dart`?**
  _High betweenness centrality (0.018) - this node is a cross-community bridge._
- **Are the 4 inferred relationships involving `MessageHandler` (e.g. with `Destroy` and `GetClientArea`) actually correct?**
  _`MessageHandler` has 4 INFERRED edges - model-reasoned connections that need verification._
- **What connects `AppDatabase`, `instance`, `_db` to the rest of the system?**
  _391 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `register_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.020618556701030927 - nodes in this community are weakly interconnected._
- **Should `child.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.03773584905660377 - nodes in this community are weakly interconnected._