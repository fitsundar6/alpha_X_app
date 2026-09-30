const fs = require('fs');

const finalMapping = JSON.parse(fs.readFileSync('C:/Users/johng/.gemini/antigravity-ide/brain/40c9f54a-01d5-4f80-a502-86ee2797af56/scratch/resolved_final_mapping.json', 'utf8'));

// Add the extra confirmed items
finalMapping['ex_machine_dip'] = {
  matchedName: 'lever seated dip',
  gifUrl: 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1451-BRImeP8.gif'
};
finalMapping['ex_single_leg_hip_thrust'] = {
  matchedName: 'single leg bridge with outstretched leg',
  gifUrl: 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/3645-rmEukuS.gif'
};
finalMapping['ex_farmer_carry'] = {
  matchedName: 'farmers walk',
  gifUrl: 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/2133-qPEzJjA.gif'
};
finalMapping['ex_turkish_get_up'] = {
  matchedName: 'kettlebell turkish get up (squat style)',
  gifUrl: 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/0551-Ha7SZ3y.gif'
};
finalMapping['ex_hanging_knee_raise'] = {
  matchedName: 'hanging leg hip raise',
  gifUrl: 'https://cdn.jsdelivr.net/gh/hasaneyldrm/exercises-dataset@main/videos/1764-VEcJRo2.gif'
};

// Aliases for backend / mobile ID parity
const idAliases = {
  'ex_bb_bench_press': 'ex_bb_bench',
  'ex_incline_smith_press': 'ex_incline_smith',
  'ex_incline_db_press': 'ex_incline_db',
  'ex_incline_bb_press': 'ex_incline_bb',
  'ex_decline_bb_press': 'ex_decline_bb_bench',
  'ex_dumbbell_rdl': 'ex_db_rdl',
  'ex_rdl_barbell': 'ex_romanian_deadlift',
  'ex_barbell_rdl': 'ex_romanian_deadlift',
  'ex_barbell_squat': 'ex_bb_squat',
  'ex_barbell_deadlift': 'ex_conventional_deadlift',
  'ex_lat_pulldown_wide': 'ex_lat_pulldown',
  'ex_seated_row_cable': 'ex_seated_cable_row',
  'ex_bent_over_row_bb': 'ex_bb_bent_row',
  'ex_bicep_curl_bb': 'ex_bb_curl',
  'ex_bicep_curl_db': 'ex_db_curl',
  'ex_lateral_raise_db': 'ex_db_lateral_raise',
  'ex_overhead_press_bb': 'ex_overhead_press',
  'ex_military_press': 'ex_overhead_press',
  'ex_tricep_rope_pushdown': 'ex_rope_pushdown',
};

for (const [alias, target] of Object.entries(idAliases)) {
  if (finalMapping[target]) {
    finalMapping[alias] = finalMapping[target];
  }
}

// Read catalog to get exercise names for name mapping
const catalog = fs.readFileSync('lib/features/exercise/data/default_exercise_catalog.dart', 'utf8');
const exBlocks = [...catalog.matchAll(/id:\s*'([^']+)',\s*name:\s*'([^']+)'/g)];
const nameToGifMap = {};

for (const m of exBlocks) {
  const id = m[1];
  const name = m[2];
  if (finalMapping[id]) {
    nameToGifMap[name.toLowerCase().trim()] = finalMapping[id].gifUrl;
    // Add variations without punctuation
    const clean = name.toLowerCase().replace(/[()\-–—/]/g, ' ').replace(/\s+/g, ' ').trim();
    nameToGifMap[clean] = finalMapping[id].gifUrl;
  }
}

console.log(`Generated ${Object.keys(finalMapping).length} ID mappings.`);
console.log(`Generated ${Object.keys(nameToGifMap).length} Name mappings.`);

// Construct Dart code
let dart = `// Alpha X Gym - Verified Exercise Media & Demonstration Mapping
// Auto-generated & audited against ExerciseDB / GymVisual 1,324 exercise dataset
// Total verified movements: ${Object.keys(finalMapping).length} IDs, ${Object.keys(nameToGifMap).length} normalized names.
//
// STRICT FALLBACK RULE:
// VALID EXERCISE GIF FOUND -> SHOW THE GIF
// NO VALID GIF FOUND       -> SHOW "DEMONSTRATION UNAVAILABLE"
// NEVER: SHOW HERO IMAGE AS DEMONSTRATION
// NEVER: SHOW ANOTHER EXERCISE'S GIF
// NEVER: SHOW PLACEHOLDER/DEMO MEDIA

class ExerciseMediaMapping {
  /// Strict Exercise ID -> Verified Animated GIF URL mapping
  static const Map<String, String> _idToGif = {
`;

const sortedIds = Object.keys(finalMapping).sort();
for (const id of sortedIds) {
  const item = finalMapping[id];
  dart += `    '${id}': '${item.gifUrl}', // ${item.matchedName}\n`;
}

dart += `  };

  /// Normalized Exercise Name -> Verified Animated GIF URL mapping
  static const Map<String, String> _nameToGif = {
`;

const sortedNames = Object.keys(nameToGifMap).sort();
for (const name of sortedNames) {
  const url = nameToGifMap[name];
  dart += `    '${name}': '${url}',\n`;
}

dart += `  };

  /// Resolves the verified animated GIF URL for a specific exercise ID.
  static String? getGifForExerciseId(String? exerciseId) {
    if (exerciseId == null || exerciseId.trim().isEmpty) return null;
    return _idToGif[exerciseId.trim()];
  }

  /// Resolves the verified animated GIF URL for a given exercise name.
  static String? getGifForExerciseName(String? exerciseName) {
    if (exerciseName == null || exerciseName.trim().isEmpty) return null;
    final normalized = normalizeName(exerciseName);
    return _nameToGif[normalized];
  }

  /// Normalizes exercise name for consistent lookup:
  /// trims, converts to lowercase, removes punctuation/parentheses/brackets.
  static String normalizeName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[\\(\\)\\-\\[\\]\\–\\—\\/]'), ' ')
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim();
  }

  /// Validates whether a candidate URL is a genuine animated GIF URL.
  /// Strictly rejects:
  /// - Unsplash photos (*.unsplash.com*)
  /// - Static hero images (hero.png, hero.jpg, hero.jpeg)
  /// - Non-GIF extensions (.png, .jpg, .jpeg, .webp, .mp4)
  static bool isValidGif(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final clean = url.trim().toLowerCase();

    // Reject static gym photos / Unsplash images
    if (clean.contains('unsplash.com') ||
        clean.contains('photo-') ||
        clean.contains('hero.') ||
        clean.endsWith('.jpg') ||
        clean.endsWith('.jpeg') ||
        clean.endsWith('.png') ||
        clean.endsWith('.webp') ||
        clean.endsWith('.mp4')) {
      return false;
    }

    return clean.endsWith('.gif') || clean.contains('.gif?');
  }

  /// Comprehensive resolution pipeline that strictly enforces the priority:
  /// 1. Direct explicit candidate URL (if it is a genuine, verified GIF)
  /// 2. Exercise ID lookup in verified mapping
  /// 3. Normalized Exercise Name lookup in verified mapping
  /// 4. STRICT FALLBACK: Returns null ("Demonstration unavailable")
  ///
  /// NEVER returns hero images, static photos, or other exercises' GIFs.
  static String? resolveGif({
    String? exerciseId,
    String? exerciseName,
    String? candidateUrl,
  }) {
    // 1. Direct candidate GIF
    if (isValidGif(candidateUrl)) {
      return candidateUrl!.trim();
    }

    // 2. Strict Exercise ID lookup
    final byId = getGifForExerciseId(exerciseId);
    if (byId != null && isValidGif(byId)) {
      return byId;
    }

    // 3. Strict Exercise Name lookup
    final byName = getGifForExerciseName(exerciseName);
    if (byName != null && isValidGif(byName)) {
      return byName;
    }

    // 4. Strict Fallback: Demonstration unavailable
    return null;
  }

  /// Returns true if this exercise has an audited, verified animated GIF demonstration.
  static bool hasDemonstration({String? exerciseId, String? exerciseName}) {
    return resolveGif(exerciseId: exerciseId, exerciseName: exerciseName) != null;
  }
}
`;

fs.writeFileSync('lib/features/exercise/data/exercise_media_mapping.dart', dart);
console.log('Successfully wrote updated exercise_media_mapping.dart');
