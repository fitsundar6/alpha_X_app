# Workout Complete Summary Screen (Alpha X Gym)

A high-performance, production-grade "Workout Complete" summary modal bottom sheet built for Flutter 3.x using Clean Architecture, null safety, and Riverpod state management.

---

## 📸 Architecture & Feature Overview

When a client finishes a workout, `showWorkoutCompleteModal` presents a modal bottom sheet:
- **Sheet Configuration**: `showModalBottomSheet`, `isScrollControlled: true`, `backgroundColor: Colors.transparent`, rounded top corners `28`, white background container sizing to ~92% screen height.
- **Header**:
  - Centered grey drag handle (40x4, rounded).
  - Yellow **"Done"** button (`#FFC400`, radius 10, bold black text) to dismiss the sheet.
  - Title: **"Well done!"** (bold, 32sp, black).
  - Subtitle: **"This is your {n}th workout"** (grey, 18sp) with ordinal helper (`1st`, `2nd`, `3rd`, `81st`, etc.).
- **Share Card Carousel**:
  - `PageView` with `viewportFraction: 0.88` (so the next card peeks in).
  - 6 dedicated card pages, each wrapped in a `RepaintBoundary` with a `GlobalKey` for ultra-crisp 3x PNG export.
  - Active dot indicator below using `smooth_page_indicator` (active dot `#FFC400`, inactive dots grey).
  - **Page 1**: Workout Summary (duration, volume, exercises, PR count).
  - **Page 2**: **Muscle Activation Card** (Anatomy Front & Back vector view with orange/amber highlight shades, dark wrap chips `[colored dot] Muscle "N set(s)"`, footer with app logo + wordmark and athlete handle).
  - **Page 3**: Exercise list breakdown.
  - **Page 4**: Personal Records (trophy badge and deltas).
  - **Page 5**: Consistency & streak tracker.
  - **Page 6**: Minimal editorial typography card.
- **Bottom Action Row**:
  - 5 circular 64px buttons with light grey border and labels:
    - **Stories**: Shares high-res PNG to Instagram Stories via `instagram-stories://share` or system story share sheet.
    - **Share**: Opens system share sheet (`share_plus`) with the card PNG.
    - **Save**: Saves current card PNG to the device gallery using `gallery_saver_plus` and `permission_handler`.
    - **Save All**: Iterates and exports all 6 cards to the photo gallery.
    - **Text**: Generates and shares a formatted plain-text workout summary.

---

## 📁 Directory Structure

```
lib/features/workout_summary/
├── models/
│   └── workout_summary_models.dart      # WorkoutSummary, ExerciseLog, MuscleActivation
├── utils/
│   ├── ordinal_formatter.dart           # English ordinal helper (1st, 2nd, 81st...)
│   ├── muscle_mapping.dart              # Exercise-to-muscle mapping & color calculation
│   └── card_capture_service.dart        # RepaintBoundary.toImage(pixelRatio: 3.0) exporter
├── services/
│   └── workout_summary_service.dart     # Riverpod Notifier, gallery saver & share handlers
├── widgets/
│   ├── share_card_base.dart             # Standardized #0A0A0A dark card wrapper
│   ├── muscle_body_widget.dart          # SVG string loader & dynamic path fill recoloring
│   ├── action_row.dart                  # 64px circular action button row
│   └── cards/
│       ├── card_1_workout_overview.dart # Page 1: Overview stats
│       ├── card_2_muscle_activation.dart# Page 2: Flagship Anatomy diagram & chips
│       ├── card_3_exercise_list.dart    # Page 3: Exercise log list
│       ├── card_4_personal_records.dart # Page 4: PR trophies & milestones
│       ├── card_5_streak_calendar.dart  # Page 5: Weekly tracker & streak flame
│       └── card_6_minimal_text.dart     # Page 6: Typographic poster
└── screens/
    ├── workout_complete_modal.dart      # showWorkoutCompleteModal modal bottom sheet
    └── workout_summary_demo_screen.dart # Standalone demo screen with "Finish Workout"
```

---

## 🔌 1. How to Plug In Real Workout Data

To show the modal with your workout repository's completed session or record:

```dart
import 'package:alpha_x_gym/features/workout_summary/models/workout_summary_models.dart';
import 'package:alpha_x_gym/features/workout_summary/screens/workout_complete_modal.dart';

void onWorkoutFinished(WorkoutSession session, Duration duration) {
  final summary = WorkoutSummary(
    planName: session.title,
    week: session.weekNumber ?? 1,
    day: session.dayNumber ?? 1,
    date: DateTime.now(),
    workoutNumber: 81, // Can fetch from repository history count
    duration: duration,
    totalVolume: session.totalVolume,
    username: '@${authService.currentUsername}',
    streakDays: 14,
    prsCount: 3,
    exercises: session.exercises.map((e) => ExerciseLog(
      name: e.title,
      primaryMuscles: e.targetMuscles,
      secondaryMuscles: e.secondaryMuscles,
      sets: e.completedSetsCount,
      reps: e.targetReps,
      weight: e.targetWeightKg,
    )).toList(),
  );

  showWorkoutCompleteModal(context, summary: summary);
}
```

If no `summary` argument is passed, it automatically falls back to `WorkoutSummary.mock()` (matching Quadriceps 1 set, Glutes 1 set, Hamstrings 1 set).

---

## 🎨 2. How to Swap the Anatomy SVGs

Vector SVG assets are located in:
- `assets/svg/body_front.svg`
- `assets/svg/body_back.svg`

### Muscle ID Requirements:
When replacing with customized vector artwork (e.g., from Figma or Illustrator):
1. Ensure the `<svg>` contains standard `<path id="...">` or `<g id="...">` tags with unique muscle IDs:
   - **Front view**: `quadriceps`, `chest`, `shoulders`, `biceps`, `forearms`, `abs`, `obliques`, `calves`, `traps`
   - **Back view**: `glutes`, `hamstrings`, `calves`, `lats`, `traps`, `lower_back`, `shoulders`, `triceps`, `forearms`
2. Set default untrained fill to `#3A3A3A` on each muscle path or group.
3. Keep non-muscle anatomical elements (head, neck, contours) under `<g id="base_silhouette">` or `<path id="contour_lines">`.
4. `MuscleBodyWidget` will automatically locate each `id="muscleId"` attribute and inject the dynamic computed hex fill color at runtime without requiring any code modifications.

---

## 📱 3. Platform Setup Instructions

### Android (`android/app/src/main/AndroidManifest.xml`)

1. **Storage / Photo Library Permissions**:
   ```xml
   <!-- Android 13+ (API 33+) -->
   <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
   <!-- Android 12 and below -->
   <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
   <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29"/>
   ```

2. **Package & Intent Queries** (required on Android 11+ / API 30+ for Instagram Stories & image sharing):
   ```xml
   <queries>
       <package android:name="com.instagram.android" />
       <intent>
           <action android:name="android.intent.action.VIEW"/>
           <data android:scheme="instagram-stories"/>
       </intent>
       <intent>
           <action android:name="android.intent.action.SEND"/>
           <data android:mimeType="image/png"/>
       </intent>
       <intent>
           <action android:name="android.intent.action.PROCESS_TEXT"/>
           <data android:mimeType="text/plain"/>
       </intent>
   </queries>
   ```

---

### iOS (`ios/Runner/Info.plist`)

1. **Photo Library Permissions**:
   ```xml
   <key>NSPhotoLibraryUsageDescription</key>
   <string>Alpha X Gym needs photo library access to save and share your workout accomplishment cards.</string>
   <key>NSPhotoLibraryAddUsageDescription</key>
   <string>Alpha X Gym needs permission to save workout accomplishment cards to your photo gallery.</string>
   ```

2. **Instagram URL Schemes**:
   ```xml
   <key>LSApplicationQueriesSchemes</key>
   <array>
       <string>instagram</string>
       <string>instagram-stories</string>
   </array>
   ```

---

## 🚀 4. How to Test & Demo

1. Run the app:
   ```bash
   flutter run
   ```
2. On the launch screen, tap **"FINISH WORKOUT DEMO"** (or navigate to `/workout-summary-demo`).
3. Tap the yellow **"Finish Workout"** button to open the modal bottom sheet.
4. Swipe through the 6 cards, observe the dynamic muscle activation highlights, and test the 5 export action buttons.
