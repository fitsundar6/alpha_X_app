import { INITIAL_EXERCISE_CATALOG } from './modules/exercise/exercise.seed';

const requested = [
  // CHEST
  'Barbell Bench Press', 'Incline Barbell Bench Press', 'Decline Barbell Bench Press',
  'Dumbbell Bench Press', 'Incline Dumbbell Press', 'Decline Dumbbell Press',
  'Dumbbell Fly', 'Cable Fly', 'Low-to-High Cable Fly', 'High-to-Low Cable Fly',
  'Machine Chest Press', 'Pec Deck', 'Push-Up', 'Wide Push-Up', 'Close-Grip Push-Up',
  'Deficit Push-Up', 'Ring Push-Up', 'Weighted Push-Up', 'Smith Machine Bench Press',
  'Incline Smith Machine Press', 'Landmine Press',

  // BACK
  'Pull-Up', 'Chin-Up', 'Neutral-Grip Pull-Up', 'Lat Pulldown', 'Wide-Grip Lat Pulldown',
  'Close-Grip Lat Pulldown', 'Neutral-Grip Lat Pulldown', 'Single-Arm Lat Pulldown',
  'Barbell Row', 'Pendlay Row', 'T-Bar Row', 'Chest-Supported Row', 'Dumbbell Row',
  'One-Arm Dumbbell Row', 'Cable Row', 'Seated Cable Row', 'Single-Arm Cable Row',
  'Machine Row', 'Inverted Row', 'Meadows Row', 'Seal Row', 'Rack Pull',
  'Straight-Arm Pulldown', 'Dumbbell Pullover', 'Barbell Pullover', 'Back Extension',

  // SHOULDERS
  'Barbell Overhead Press', 'Dumbbell Shoulder Press', 'Arnold Press', 'Machine Shoulder Press',
  'Smith Machine Shoulder Press', 'Seated Dumbbell Press', 'Cable Lateral Raise',
  'Dumbbell Lateral Raise', 'Machine Lateral Raise', 'Lean-Away Lateral Raise',
  'Single-Arm Lateral Raise', 'Front Raise', 'Cable Front Raise', 'Plate Front Raise',
  'Reverse Fly', 'Cable Reverse Fly', 'Machine Reverse Fly', 'Rear Delt Row',
  'Face Pull', 'Cable Y-Raise', 'Dumbbell Y-Raise', 'Cuban Press',
  'External Rotation', 'Internal Rotation',

  // BICEPS
  'Barbell Curl', 'EZ-Bar Curl', 'Dumbbell Curl', 'Alternating Dumbbell Curl',
  'Hammer Curl', 'Cross-Body Hammer Curl', 'Incline Dumbbell Curl', 'Preacher Curl',
  'Machine Preacher Curl', 'Cable Curl', 'Bayesian Cable Curl', 'Concentration Curl',
  'Spider Curl', 'Drag Curl', 'Reverse Curl', 'Zottman Curl', 'Cable Hammer Curl', 'High Cable Curl',

  // TRICEPS
  'Cable Pushdown', 'Rope Pushdown', 'Straight-Bar Pushdown', 'Reverse-Grip Pushdown',
  'Single-Arm Pushdown', 'Overhead Cable Extension', 'Rope Overhead Extension',
  'Dumbbell Overhead Extension', 'EZ-Bar Skull Crusher', 'Dumbbell Skull Crusher',
  'Close-Grip Bench Press', 'JM Press', 'Bench Dip', 'Parallel Bar Dip',
  'Assisted Dip', 'Cross-Body Cable Extension', 'Tate Press', 'Kickback', 'Cable Kickback',

  // QUADS
  'Barbell Back Squat', 'Front Squat', 'Hack Squat', 'Smith Machine Squat', 'Goblet Squat',
  'Leg Press', 'Horizontal Leg Press', 'Single-Leg Press', 'Bulgarian Split Squat',
  'Reverse Lunge', 'Forward Lunge', 'Walking Lunge', 'Step-Up', 'Sissy Squat', 'Belt Squat',
  'Safety Bar Squat', 'Zercher Squat', 'Box Squat', 'Pause Squat', 'Leg Extension',

  // HAMSTRINGS
  'Romanian Deadlift', 'Stiff-Leg Deadlift', 'Conventional Deadlift', 'Sumo Deadlift',
  'Trap-Bar Deadlift', 'Single-Leg Romanian Deadlift', 'Good Morning', 'Lying Leg Curl',
  'Seated Leg Curl', 'Standing Leg Curl', 'Nordic Hamstring Curl', 'Glute-Ham Raise',
  'Stability Ball Leg Curl', 'Slider Leg Curl',

  // GLUTES
  'Barbell Hip Thrust', 'Dumbbell Hip Thrust', 'Machine Hip Thrust', 'Glute Bridge',
  'Single-Leg Glute Bridge', 'Hip Abduction', 'Banded Hip Abduction', 'Curtsy Lunge',
  'Sumo Squat', 'Cable Pull-Through',

  // CALVES
  'Standing Calf Raise', 'Seated Calf Raise', 'Leg Press Calf Raise', 'Single-Leg Calf Raise',
  'Donkey Calf Raise', 'Smith Machine Calf Raise', 'Tibialis Raise', 'Band Tibialis Raise', 'Toe Raise',

  // ABS
  'Crunch', 'Cable Crunch', 'Machine Crunch', 'Reverse Crunch', 'Hanging Knee Raise',
  'Hanging Leg Raise', 'Captain\'s Chair Knee Raise', 'Ab Wheel Rollout', 'Plank',
  'Side Plank', 'RKC Plank', 'Dead Bug', 'Bird Dog', 'Hollow Body Hold', 'V-Up',
  'Sit-Up', 'Bicycle Crunch', 'Russian Twist', 'Pallof Press', 'Cable Wood Chop',
  'Cable Lift', 'Mountain Climber', 'Bear Crawl',

  // FUNCTIONAL
  'Farmer Carry', 'Suitcase Carry', 'Front Rack Carry', 'Overhead Carry',
  'Sled Push', 'Sled Pull', 'Battle Rope Waves', 'Medicine Ball Slam',
  'Medicine Ball Throw', 'Kettlebell Swing', 'Kettlebell Clean', 'Kettlebell Snatch',
  'Turkish Get-Up', 'Kettlebell Goblet Squat', 'Kettlebell Press',

  // CALISTHENICS
  'Handstand', 'Handstand Push-Up', 'Pike Push-Up', 'Archer Push-Up',
  'Pseudo Planche Push-Up', 'Muscle-Up', 'L-Sit', 'Human Flag progression',
  'Front Lever progression', 'Back Lever progression', 'Planche progression',

  // BOXING
  'Shadow Boxing', 'Jab', 'Cross', 'Hook', 'Uppercut', 'Jab-Cross',
  'Combination drills', 'Heavy Bag Punching', 'Speed Bag', 'Footwork drills',
  'Agility Ladder', 'Shuttle Runs', 'Sprint', 'Hill Sprint', 'Jump Rope',
  'Burpee', 'Box Jump', 'Broad Jump',

  // MOBILITY & WARM-UP & COOL-DOWN
  'Shoulder CARs', 'Hip CARs', 'Ankle CARs', 'Thoracic Rotation',
  '90/90 Hip Rotation', 'World\'s Greatest Stretch', 'Cat-Cow', 'Scapular CARs',
  'Leg Swings', 'Arm Circles', 'High Knees', 'Butt Kicks', 'Inchworm',
  'Dynamic Hamstring Sweep', 'Pigeon Pose', 'Cobra Stretch', 'Child\'s Pose'
];

const existingNames = INITIAL_EXERCISE_CATALOG.map(e => e.name.toLowerCase());
const missing: string[] = [];

for (const req of requested) {
  const norm = req.toLowerCase();
  const found = existingNames.some(n => n.includes(norm) || norm.includes(n));
  if (!found) {
    missing.push(req);
  }
}

console.log('Total requested checked:', requested.length);
console.log('Missing count:', missing.length);
console.log('Missing items:', missing);
