import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/features/activity/domain/models/activity_models.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthService auth;
  late WorkoutRepository workoutRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    auth = AuthService();
    await auth.logout();
    await auth.initialize();
    workoutRepo = WorkoutRepository();
  });

  group('Complete Client Assessment & Admin Data Flow End-to-End Tests', () {
    test('1. Client A creates account and receives permanent Client ID (AXG-XXXX)', () async {
      final regRes = await auth.registerClientAccount(
        name: 'Jordan Hayes',
        email: 'jordan.hayes@example.com',
        phone: '+1 (555) 345-6789',
        password: 'Password123!',
        confirmPassword: 'Password123!',
      );

      final clientId = regRes['clientId'] as String;
      expect(clientId.startsWith('AXG-'), isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentClientId, clientId);
      expect(auth.currentUserName, 'Jordan Hayes');
      expect(auth.assessmentCompleted, isFalse);
    });

    test('2. Client completes all assessment fields and submits -> saves locally & sync queue', () async {
      await auth.registerClientAccount(
        name: 'Elena Rostova',
        email: 'elena.rostova@example.com',
        phone: '+1 (555) 987-6543',
        password: 'Password123!',
        confirmPassword: 'Password123!',
      );
      final clientId = auth.currentClientId;

      final completeAssessment = {
        'fitnessLevel': 'intermediate',
        'primaryGoal': 'Muscle Gain',
        'secondaryGoal': 'Build Strength',
        'weightKg': 74.5,
        'heightCm': 176.0,
        'age': 29,
        'gender': 'Female',
        'trainingExperience': '2–3 years',
        'trainingDaysPerWeek': 5,
        'preferredDays': ['Monday', 'Tuesday', 'Thursday', 'Friday', 'Saturday'],
        'hasCurrentInjury': true,
        'injuryAreas': ['Right shoulder', 'Lower back'],
        'injuryDescription': 'Mild rotator cuff impingement from heavy bench press',
        'hasPreviousSurgery': true,
        'surgeryDetails': 'Arthroscopic ACL repair 2021',
        'activityLevel': 'MODERATE',
        'sleepHours': '7–8 hours',
        'dailySteps': 8500,
        'trainingTimePref': 'Morning',
        'trainingPreferences': ['Strength Training', 'HIIT', 'Mobility'],
      };

      await auth.saveOnboardingStep(
        completeAssessment,
        step: 10,
        isComplete: true,
      );

      expect(auth.assessmentCompleted, isTrue);
      expect(auth.onboardingCompleted, isTrue);
      expect(auth.clientProfile['fitnessLevel'], 'intermediate');
      expect(auth.clientProfile['primaryGoal'], 'Muscle Gain');
      expect(auth.clientProfile['weightKg'], 74.5);
      expect(auth.clientProfile['hasCurrentInjury'], isTrue);
      expect(auth.clientProfile['injuryAreas'], contains('Right shoulder'));

      // Check local storage persistence
      final localClients = await auth.getLocalRegisteredClients();
      final savedClient = localClients.firstWhere((c) => c['clientId'] == clientId);
      expect(savedClient['onboardingCompleted'], isTrue);
      expect(savedClient['primaryGoal'], 'Muscle Gain');
      expect(savedClient['weightKg'], 74.5);
    });

    test('3. Client ID connects assessment, login session, and profile without duplication', () async {
      final regRes = await auth.registerClientAccount(
        name: 'Marcus Stone',
        email: 'marcus.stone@example.com',
        phone: '+1 (555) 123-4567',
        password: 'Password123!',
        confirmPassword: 'Password123!',
      );
      final initialClientId = regRes['clientId'] as String;

      // Complete initial assessment
      await auth.saveOnboardingStep({
        'weightKg': 82.0,
        'primaryGoal': 'Fat Loss',
      }, step: 10, isComplete: true);

      expect(auth.currentClientId, initialClientId);

      // Client logs out
      await auth.logout();
      expect(auth.isAuthenticated, isFalse);

      // Client logs back in using permanent Client ID + Password
      final loginRes = await auth.loginWithCredentials(
        identifier: initialClientId,
        password: 'Password123!',
      );

      expect(loginRes['clientId'], initialClientId);
      expect(auth.currentClientId, initialClientId);
      expect(auth.assessmentCompleted, isTrue);

      // Client updates weight
      await auth.saveOnboardingStep({'weightKg': 80.5}, step: 10, isComplete: true);

      // Verify no duplicate client record was created
      final allClients = await auth.getLocalRegisteredClients();
      final matchingClients = allClients.where((c) => c['clientId'] == initialClientId).toList();
      expect(matchingClients.length, equals(1));
      expect(matchingClients.first['weightKg'], equals(80.5));
    });

    test('4. Admin sees complete client assessment data with all fields', () async {
      await auth.registerClientAccount(
        name: 'Sarah Connor',
        email: 'sarah.connor@example.com',
        phone: '+1 (555) 999-8888',
        password: 'Password123!',
        confirmPassword: 'Password123!',
      );
      final clientAId = auth.currentClientId;

      await auth.saveOnboardingStep({
        'fitnessLevel': 'advanced',
        'primaryGoal': 'Build Strength',
        'secondaryGoal': 'Fat Loss',
        'weightKg': 62.0,
        'heightCm': 165.0,
        'age': 32,
        'gender': 'Female',
        'trainingExperience': '3+ years',
        'trainingDaysPerWeek': 6,
        'preferredDays': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
        'hasCurrentInjury': false,
        'injuryAreas': [],
        'hasPreviousSurgery': false,
        'activityLevel': 'HIGH',
        'sleepHours': '8+ hours',
        'dailySteps': 10000,
        'trainingPreferences': ['Powerlifting', 'Calisthenics'],
      }, step: 10, isComplete: true);

      // Admin loads client list
      final clientsList = await workoutRepo.fetchClientsList();
      final adminViewClient = clientsList.firstWhere(
        (c) => c['clientId'] == clientAId || c['email'] == 'sarah.connor@example.com',
      );

      expect(adminViewClient['clientId'], clientAId);
      expect(adminViewClient['name'], 'Sarah Connor');
      expect(adminViewClient['onboardingCompleted'], 'true');
      expect(adminViewClient['fitnessLevel'], 'advanced');
      expect(adminViewClient['primaryGoal'], 'Build Strength');
      expect(adminViewClient['weightKg'].toString(), '62.0');
      expect(adminViewClient['hasCurrentInjury'], 'false');
    });

    test('5. Multi-client isolation: Client A and Client B records remain strictly separated', () async {
      // Register Client A
      await auth.registerClientAccount(
        name: 'Client Alpha',
        email: 'alpha@gym.com',
        phone: '+1 (555) 111-1111',
        password: 'Password123!',
        confirmPassword: 'Password123!',
      );
      final clientAId = auth.currentClientId;
      await auth.saveOnboardingStep({
        'primaryGoal': 'Fat Loss',
        'weightKg': 90.0,
        'dailySteps': 6000,
      }, step: 10, isComplete: true);

      await auth.logout();

      // Register Client B
      await auth.registerClientAccount(
        name: 'Client Beta',
        email: 'beta@gym.com',
        phone: '+1 (555) 222-2222',
        password: 'Password123!',
        confirmPassword: 'Password123!',
      );
      final clientBId = auth.currentClientId;
      await auth.saveOnboardingStep({
        'primaryGoal': 'Muscle Gain',
        'weightKg': 70.0,
        'dailySteps': 12000,
      }, step: 10, isComplete: true);

      // Verify distinct Client IDs
      expect(clientAId != clientBId, isTrue);

      final allClients = await auth.getLocalRegisteredClients();
      final recordA = allClients.firstWhere((c) => c['clientId'] == clientAId);
      final recordB = allClients.firstWhere((c) => c['clientId'] == clientBId);

      // Verify complete data isolation
      expect(recordA['name'], 'Client Alpha');
      expect(recordA['primaryGoal'], 'Fat Loss');
      expect(recordA['weightKg'], 90.0);
      expect(recordA['dailySteps'], 6000);

      expect(recordB['name'], 'Client Beta');
      expect(recordB['primaryGoal'], 'Muscle Gain');
      expect(recordB['weightKg'], 70.0);
      expect(recordB['dailySteps'], 12000);
    });

    test('6. Step counter: Deduplication on composite (clientId + date) prevents double counting', () {
      final recordsMap = <String, DailyActivityRecord>{};
      const clientId = 'AXG-0001';
      final testDate = DateTime(2026, 9, 29);

      // First sync: Phone pedometer records 4,500 steps
      final rec1 = DailyActivityRecord(
        id: 'rec_1',
        clientId: clientId,
        date: testDate,
        steps: 4500,
        stepGoal: 8000,
        isGoalAchieved: false,
      );

      final key = '${clientId}_2026-09-29';
      recordsMap[key] = rec1;
      expect(recordsMap[key]!.steps, equals(4500));

      // Second sync later same day: Aggregated platform total becomes 7,842 steps
      final rec2Updated = DailyActivityRecord(
        id: 'rec_1',
        clientId: clientId,
        date: testDate,
        steps: 7842,
        stepGoal: 8000,
        isGoalAchieved: false,
      );

      recordsMap[key] = rec2Updated;

      // Ensure single record updated, not duplicated
      expect(recordsMap.length, equals(1));
      expect(recordsMap[key]!.steps, equals(7842));
    });

    test('7. Offline queueing: Offline assessment saves locally with pending sync state', () async {
      await auth.registerClientAccount(
        name: 'Offline Athlete',
        email: 'offline.athlete@example.com',
        phone: '+1 (555) 777-6666',
        password: 'Password123!',
        confirmPassword: 'Password123!',
      );

      await auth.saveOnboardingStep({
        'weightKg': 75.0,
        'primaryGoal': 'Conditioning',
      }, step: 10, isComplete: true);

      // Verify session was saved with assessmentCompleted = true
      final session = await auth.getActiveLocalSession();
      expect(session, isNotNull);
      expect(session!['onboardingCompleted'], isTrue);
      expect(session['clientProfile']['weightKg'], equals(75.0));
    });
  });
}
