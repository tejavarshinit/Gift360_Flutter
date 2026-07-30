# React-to-Flutter Conversion Methodology

A generic, reusable guide for converting React web applications to Flutter mobile/web apps. Based on real-world production experience converting the Gift360 gift voucher marketplace.

---

## Table of Contents

1. [Phase 0: Role Setup & Context Priming](#phase-0-role-setup--context-priming)
2. [Phase 1: Full Codebase Analysis](#phase-1-full-codebase-analysis)
3. [Phase 2: Gap Analysis & Documentation](#phase-2-gap-analysis--documentation)
4. [Phase 3: Component-by-Component Conversion](#phase-3-component-by-component-conversion)
5. [Phase 4: API Layer Alignment](#phase-4-api-layer-alignment)
6. [Phase 5: Bug Fixes & Data Model Corrections](#phase-5-bug-fixes--data-model-corrections)
7. [Phase 6: Build, Verify & Stage](#phase-6-build-verify--stage)
8. [Prompt Templates](#prompt-templates)
9. [Common Pitfalls & Solutions](#common-pitfalls--solutions)

---

## Phase 0: Role Setup & Context Priming

### What to do
Start every conversion session by setting the AI's role and providing the project context.

### Prompt template
```
You are a 10+ years experienced Flutter developer.
Your task is to analyse the React: [PATH_TO_REACT_PROJECT].
Give and tell me the gaps in this project in terms of flow, functionality,
UI, APIs integration everything end to end and lets do one by one.
```

### Why this works
- Sets expertise level expectations (senior-level code, not tutorial-level)
- "End to end" forces comprehensive analysis, not surface-level
- "One by one" ensures structured, step-by-step execution
- Establishes the React project as the source of truth

### What the AI does in this phase
- Explores the full project directory structure
- Reads every page, component, API file, context, hook, type, and data file
- Produces a comprehensive gap analysis report

---

## Phase 1: Full Codebase Analysis

### What to do
Ask the AI to deeply analyse every layer of the React project.

### What gets analysed
| Layer | What to look for |
|---|---|
| **Routing** | Route definitions, auth guards, redirects, nested routes |
| **Pages/Screens** | Each page's purpose, state, API calls, navigation, auth protection |
| **Components** | Reusable components, props, composition patterns |
| **API Layer** | Base URLs, HTTP methods, auth token handling, error handling |
| **Contexts/Providers** | State management, cross-context interactions |
| **Hooks** | Custom hooks, API integration patterns, state logic |
| **Types/Models** | Data shapes, interfaces, type conventions |
| **Static Data** | Mock data, hardcoded content, feature flags |
| **Config** | Environment variables, feature toggles, build config |

### Output format
The AI should produce a structured report with:
- **Critical Bugs**: Runtime failures, security issues
- **Flow/Architecture Gaps**: Missing auth guards, orphaned pages, broken flows
- **API Integration Gaps**: Wrong endpoints, missing error handling, auth inconsistencies
- **UI/Component Gaps**: Large files needing decomposition, code duplication
- **Static Data Gaps**: Hardcoded data that needs API integration
- **Missing Functionality**: Features in React not yet in Flutter
- **Security/Quality Gaps**: Exposed secrets, console.logs, missing error boundaries

---

## Phase 2: Gap Analysis & Documentation

### What to do
Review the gap analysis and prioritise fixes.

### Priority framework
| Priority | Category | Examples |
|---|---|---|
| **P0 — Critical** | Runtime failures, security | Missing auth interceptors, broken hooks rules, env variable conflicts |
| **P1 — High** | Reliability, security | Missing auth guards, wrong HTTP methods, no error handling |
| **P2 — Medium** | Maintainability | Orphaned pages, code duplication, stubbed endpoints |
| **P3 — Low** | UX polish | Missing features, hardcoded content, inconsistent styling |

### Decision point
Ask: "Want me to start fixing these one by one? I'd recommend starting with the P0 critical bugs."

---

## Phase 3: Component-by-Component Conversion

### The conversion workflow

For each React component/page to convert:

#### Step 1: Provide the React reference
```markdown
Create a Flutter widget called `[WidgetName]` that replicates the exact
React component below. This is placed in `[location]` on the `[screen]` screen.

## EXACT React Reference (for pixel-perfect replication):
```tsx
[paste the full React component code]
```

## FLUTTER IMPLEMENTATION REQUIREMENTS:
[list every pixel, color, spacing, behavior detail]
```

#### Step 2: AI explores Flutter project context
The AI will:
- Check the Flutter project structure (`lib/features/...`)
- Read the target screen where the widget integrates
- Check existing patterns (themes, colors, navigation)
- Verify available packages (`pubspec.yaml`)

#### Step 3: AI creates the implementation plan
Before writing code, the AI should present:
- Widget structure (StatelessWidget/ConsumerWidget)
- File location
- Integration point in the parent screen
- Dependencies needed

#### Step 4: AI implements and verifies
- Creates the widget file
- Integrates into the parent screen
- Runs `dart analyze` to verify zero errors
- Runs `flutter build` to confirm compilation

### Key conversion patterns

| React Pattern | Flutter Equivalent |
|---|---|
| `useState` | `StatefulWidget` or Riverpod `StateProvider` |
| `useEffect` | `initState()` + `dispose()` or Riverpod lifecycle |
| `useContext` | `ref.watch(provider)` (Riverpod) |
| `useMemo` | `ConsumerWidget` with computed values |
| `onClick` | `onTap` in `GestureDetector` or `InkWell` |
| `className` | `BoxDecoration` + `TextStyle` |
| `style={{}}` | Inline `TextStyle` / `BoxDecoration` props |
| `flex` layout | `Row`/`Column` with `Expanded`/`Flexible` |
| CSS Grid | `GridView` or `Wrap` |
| CSS animations | `AnimatedContainer`, `flutter_animate`, or `AnimationController` |
| React Router | `go_router` with `context.push()` |
| Axios interceptors | Dio interceptors |
| React Query | `flutter_riverpod` + `FutureProvider` |
| localStorage | `shared_preferences` or `flutter_secure_storage` |
| SVG icons | `lucide_icons`, ` Icons`, or `flutter_svg` |
| CSS linear-gradient | `LinearGradient` in `BoxDecoration` |
| CSS box-shadow | `BoxShadow` in `BoxDecoration` |
| CSS border-radius | `BorderRadius.circular()` |
| CSS position: absolute | `Stack` + `Positioned` |
| overflow: hidden | `ClipRRect` or `ClipOval` |

---

## Phase 4: API Layer Alignment

### What to do
Ensure the Flutter app hits the same backend endpoints as the React app.

### Step 1: Document React API calls
For each React API file, list:
- Base URL (from env vars)
- HTTP method (GET/POST/PUT/DELETE)
- Endpoint path
- Request/response shapes

### Step 2: Map to Flutter API layer
```dart
// React: POST https://api.example.com/brands/getall
// Flutter must hit the SAME endpoint:
final response = await _dio.post('/brands/getall', data: {});
```

### Step 3: Verify endpoint parity
Create a comparison table:

| Feature | React Endpoint | Flutter Endpoint | Match? |
|---|---|---|---|
| Get brands | POST /brands/getall | POST /brands/getall | Yes |
| Get brand details | POST /brands/{id} | POST /v1/fetchbranddetails | No — FIX |
| Search brands | POST /brands/search | POST /brands/search | Yes |

### Common endpoint mismatch causes
1. React uses one endpoint, Flutter uses a different one for the same data
2. React hits `/brands/getall`, Flutter hits `/v1/fetchbrands` (different response shapes)
3. The `/v1/` prefix endpoints may not return the same fields (like `Discount`)

### Fix pattern
```dart
// BEFORE (wrong endpoint):
final response = await _dio.post('/v1/fetchbrands', data: {});

// AFTER (matches React):
final response = await _dio.post('/brands/getall', data: {});
```

---

## Phase 5: Bug Fixes & Data Model Corrections

### Pattern 1: Image JSON string not parsed
**Problem:** React parses `JSON.parse(b.image)` but Flutter treats it as a plain string.

**Fix:**
```dart
// BEFORE:
if (imageData is String && imageData.isNotEmpty) {
  parsedImages = BrandImages(raw: imageData, featured: imageData, ...);
}

// AFTER:
if (imageData is String && imageData.isNotEmpty) {
  try {
    final decoded = jsonDecode(imageData);
    if (decoded is Map<String, dynamic>) {
      parsedImages = BrandImages.fromJson(decoded);
    } else {
      parsedImages = BrandImages(raw: imageData, featured: imageData, ...);
    }
  } catch (_) {
    parsedImages = BrandImages(raw: imageData, featured: imageData, ...);
  }
}
```

### Pattern 2: Missing auth interceptors
**Problem:** One Axios instance doesn't have auth interceptors.

**Fix:** Ensure all API clients share the same interceptor configuration.

### Pattern 3: Empty sections due to data mismatch
**Problem:** A section renders `SizedBox.shrink()` because the API doesn't return expected fields.

**Debug approach:**
1. Check which endpoint the Flutter app hits vs React
2. Check if the response shape differs
3. Fix the endpoint or the parser

### Pattern 4: Currency symbol inconsistency
**Problem:** Some components use `$` (USD) while others use `₹` (INR).

**Fix:** Search for all `$` currency symbols and replace with `₹` where appropriate.

---

## Phase 6: Build, Verify & Stage

### Step 1: Static analysis
```bash
dart analyze lib/features/[feature]/[file].dart
```
Expected: "No issues found!" or only info-level warnings.

### Step 2: Full project analysis
```bash
dart analyze lib/
```
Fix any errors. Info-level warnings are acceptable.

### Step 3: Web build
```bash
flutter build web --no-tree-shake-icons
```
Expected: `√ Built build\web`

### Step 4: Android APK build
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

### Step 5: Android App Bundle (for Play Store)
```bash
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

### Step 6: iOS build (macOS only)
```bash
flutter build ios --release
```
Then open `ios/Runner.xcworkspace` in Xcode to archive and upload.

### Step 7: Verify on device/emulator
```bash
flutter run -d <device_id>
```
Test all converted features end-to-end.

---

## Prompt Templates

### For initial analysis
```
You are a 10+ years experienced Flutter developer.
Analyse the React project at [PATH].
Identify gaps in flow, functionality, UI, APIs, and everything end to end.
```

### For component conversion
```
Create a Flutter widget called [Name] that replicates the exact React component below.
Placed in [file_path] on the [screen] screen.

React Reference:
```tsx
[paste code]
```

Requirements:
1. [pixel-perfect spec]
2. [colors, sizes, spacing]
3. [behavior and navigation]
```

### For API alignment
```
The React app hits [endpoint] for [feature].
The Flutter app currently hits [wrong_endpoint].
Fix the Flutter API layer to match the React endpoints exactly.
```

### For bug fixes
```
[Describe the bug symptom].
The React implementation does [X].
The Flutter implementation does [Y].
Fix Flutter to match React behavior.
```

### For build & staging
```
Run dart analyze on [files].
Then build the APK: flutter build apk --release.
Report the output path and any errors.
```

---

## Common Pitfalls & Solutions

### 1. Wrong API endpoint
**Symptom:** Data is empty or missing fields (like discount).
**Cause:** Flutter hits `/v1/fetchbrands`, React hits `/brands/getall`.
**Fix:** Change the endpoint. Always verify by checking the React API layer.

### 2. Image field is JSON-encoded string
**Symptom:** Brand images don't load.
**Cause:** API returns `'{"featured":"url"}'` as a string, Flutter doesn't `jsonDecode` it.
**Fix:** Add `jsonDecode()` try/catch in the model parser.

### 3. Section doesn't render
**Symptom:** A section is invisible on screen.
**Cause:** Filter removes all items (e.g., no brands with discount > 0).
**Fix:** Check the filter logic. Add fallback if needed, or verify the API returns the expected data.

### 4. `IconData` final class error
**Symptom:** `The class 'IconData' can't be extended outside of its library because it's a final class.`
**Cause:** Icon package (like `lucide_icons`) extends `IconData` which became `final` in newer Flutter versions.
**Fix:** Replace with Material `Icons` or use a compatible package version.

### 5. Rules of hooks violation
**Symptom:** `RenderFlex overflowed` or runtime crash.
**Cause:** `useEffect` or state hook called after conditional return.
**Fix:** Move all hooks before any conditional returns.

### 6. Currency symbol mismatch
**Symptom:** Some screens show `$`, others show `₹`.
**Fix:** Global search for `\$` in currency context and replace with `₹`.

### 7. Static data instead of API
**Symptom:** Content never updates, same data every load.
**Cause:** Component uses hardcoded data instead of API call.
**Fix:** Replace static imports with API hooks/providers.

---

## File Structure Convention

```
lib/
├── features/
│   └── [feature]/
│       ├── data/
│       │   ├── models/        # Data classes (Brand, Order, etc.)
│       │   └── repositories/  # API calls (brands_api.dart)
│       ├── presentation/
│       │   ├── screens/       # Full pages (home_screen.dart)
│       │   ├── widgets/       # Reusable widgets (instant_gifting_banner.dart)
│       │   └── providers/     # Riverpod providers (brands_provider.dart)
│       └── domain/            # (optional) Use cases
├── core/
│   ├── constants/             # Colors, dimensions
│   ├── navigation/            # Router setup
│   ├── network/               # Dio client, interceptors
│   ├── theme/                 # ThemeData
│   └── widgets/               # Shared widgets
└── shared/
    ├── models/                # Cross-feature models
    └── widgets/               # Cross-feature widgets
```

---

## Conversion Checklist

Use this checklist for every component/page you convert:

- [ ] React component read and understood
- [ ] Flutter project structure checked
- [ ] Existing patterns (theme, colors, navigation) followed
- [ ] Widget created at correct file path
- [ ] Integrated into parent screen at correct position
- [ ] All pixel values, colors, spacing match React exactly
- [ ] Navigation behavior matches (push/pop/redirect)
- [ ] Auth protection matches (public vs protected route)
- [ ] API calls hit the same endpoints as React
- [ ] Data models parse the same response shape
- [ ] `dart analyze` passes with zero errors
- [ ] `flutter build` compiles successfully
- [ ] Tested on device/emulator
- [ ] No `console.log` / `print` debug statements left

---

## Version Control Workflow

```bash
# 1. Create feature branch
git checkout -b feature/[component-name]

# 2. Make changes
# [implement the component]

# 3. Verify
dart analyze lib/
flutter build apk --release

# 4. Commit with descriptive message
git add .
git commit -m "feat: add [component-name] matching React reference"

# 5. Push and create PR
git push origin feature/[component-name]
```

---

## Quick Reference: React → Flutter equivalents

| React | Flutter |
|---|---|
| `className="flex gap-3"` | `Row(children: [SizedBox(width: 12), ...])` |
| `className="rounded-[8px]"` | `BorderRadius.circular(8)` |
| `className="shadow-[0_4px_10px_rgba(0,0,0,0.08)]"` | `BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4))` |
| `className="bg-gradient-to-r from-[#7C3AED] to-[#3B82F6]"` | `LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)])` |
| `className="text-[12px] font-semibold text-[#111827]"` | `TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827))` |
| `className="truncate"` | `maxLines: 1, overflow: TextOverflow.ellipsis` |
| `style={{ height: 32 }}` | `SizedBox(height: 32, child: ...)` |
| `onClick={() => navigate('/path')}` | `onTap: () => context.push('/path')` |
| `<img src={url} style={{objectFit: 'contain'}} />` | `CachedNetworkImage(imageUrl: url, fit: BoxFit.contain)` |
| `overflow-x-auto` | `ListView(scrollDirection: Axis.horizontal)` |
| `snap-x` | `SnapPhysics()` or `PageView()` |
| `no-scrollbar` | Custom `ScrollBehavior` hiding scrollbar |
| `backdrop-blur` | `BackdropFilter(filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4))` |
| `position: absolute` | `Stack` + `Positioned` |
| `z-index: 10` | `Positioned` with `zIndex` in `Stack` |

---

*This guide is generic and reusable for any React-to-Flutter conversion project. Adapt the prompts, file paths, and specific details to your project.*
