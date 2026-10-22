import {
  workoutRepository,
  StoredWorkoutSession,
  StoredWorkoutAssignment,
  StoredWorkoutRecord,
  StoredWorkoutSplitPlan,
  StoredWorkoutSplitDay,
} from './workout.repository';
import { prisma } from '../../config/prisma';
import { maskEmail, maskPhone } from '../../utils/pii_mask';
import { aiNotificationEngine } from '../notifications/ai_notifications.service';
import { getISTDateForWeekday, getTodayISTWeekday, getWeekdayFromDayName } from '../../utils/istDate';

export class WorkoutService {
  // --- Admin Session Operations ---
  async getAllAdminSessions(): Promise<Array<StoredWorkoutSession & { assignmentCount: number; isAssignedToAll: boolean }>> {
    const sessions = await workoutRepository.getAllSessions();
    const allAssignments = await workoutRepository.getAllAssignments();

    return sessions.map((s) => {
      const sessionAssignments = allAssignments.filter((a) => a.sessionId === s.id);
      const isAssignedToAll = sessionAssignments.some((a) => a.clientId === null);
      return {
        ...s,
        assignmentCount: sessionAssignments.length,
        isAssignedToAll,
      };
    });
  }

  async getSessionById(id: string): Promise<StoredWorkoutSession | null> {
    return workoutRepository.getSessionById(id);
  }

  async createSession(data: any, adminId: string): Promise<StoredWorkoutSession> {
    return workoutRepository.createSession({
      ...data,
      createdById: adminId,
    });
  }

  async updateSession(id: string, data: any): Promise<StoredWorkoutSession | null> {
    return workoutRepository.updateSession(id, data);
  }

  async duplicateSession(id: string): Promise<StoredWorkoutSession | null> {
    return workoutRepository.duplicateSession(id);
  }

  async toggleActive(id: string): Promise<StoredWorkoutSession | null> {
    return workoutRepository.toggleActive(id);
  }

  async deleteSession(id: string): Promise<boolean> {
    return workoutRepository.deleteSession(id);
  }

  async assignSession(params: {
    sessionId: string;
    assignmentType: 'ALL' | 'SELECTED' | 'INDIVIDUAL';
    clientIds?: string[];
    individualClientId?: string | null;
    isRecommended?: boolean;
    scheduledDate?: string | null;
    assignedById: string;
  }): Promise<StoredWorkoutAssignment[]> {
    const assignments = await workoutRepository.assignSession(params);

    // Asynchronously dispatch plan assignment push notifications
    (async () => {
      try {
        const session = await workoutRepository.getSessionById(params.sessionId);
        const sessionTitle = session?.title || 'Workout Session';

        for (const a of assignments) {
          if (a.clientId) {
            await aiNotificationEngine.notifyWorkoutAssignment({
              assignmentId: a.id,
              clientId: a.clientId,
              sessionTitle,
              scheduledDate: a.scheduledDate,
            });
          } else {
            // Assigned to ALL clients
            const allClients = await prisma.user.findMany({
              where: { role: 'CLIENT', notificationsEnabled: true },
              select: { id: true },
            });
            for (const client of allClients) {
              await aiNotificationEngine.notifyWorkoutAssignment({
                assignmentId: `${a.id}_${client.id}`,
                clientId: client.id,
                sessionTitle,
                scheduledDate: a.scheduledDate,
              });
            }
          }
        }
      } catch (err: any) {
        console.warn('[WORKOUT SERVICE] Failed to dispatch assignment notifications:', err?.message);
      }
    })().catch(() => {});

    return assignments;
  }

  async unlockSession(adminId: string, params: {
    recordId?: string | null;
    sessionId?: string | null;
    assignmentId?: string | null;
    clientId: string;
    scheduledDate?: string | null;
    reason: string;
  }) {
    return workoutRepository.unlockSession(adminId, params);
  }

  async unassign(assignmentId: string): Promise<boolean> {
    return workoutRepository.unassign(assignmentId);
  }

  async getClientsList() {
    try {
      const dbUsers = await prisma.user.findMany({
        where: { role: 'CLIENT' },
        select: {
          id: true,
          name: true,
          email: true,
          role: true,
          photoUrl: true,
          googleUid: true,
          createdAt: true,
          clientProfile: {
            select: {
              id: true,
              clientId: true,
              googleUid: true,
              photoUrl: true,
              phone: true,
              adminNotes: true,
              dailyStepGoal: true,
              fitnessLevel: true,
              primaryGoal: true,
              secondaryGoal: true,
              weightKg: true,
              heightCm: true,
              age: true,
              gender: true,
              trainingExperience: true,
              trainingDaysPerWeek: true,
              hasCurrentInjury: true,
              injuryAreas: true,
              injuryDescription: true,
              hasPreviousSurgery: true,
              surgeryDetails: true,
              activityLevel: true,
              sleepHours: true,
              dailySteps: true,
              trainingTimePref: true,
              preferredDays: true,
              trainingPreferences: true,
              onboardingCompleted: true,
              onboardingStep: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
      });

      return dbUsers.map((u) => {
        const cp = u.clientProfile;
        const displayClientId = cp?.clientId || u.id;
        return {
          id: u.id,
          clientId: displayClientId,
          userId: u.id,
          name: u.name,
          // PII masking: admin list shows partial email & phone only
          email: maskEmail(u.email) ?? '',
          phone: maskPhone(cp?.phone ?? null),
          adminNotes: cp?.adminNotes ?? null,
          photoUrl: cp?.photoUrl || u.photoUrl || null,
          googleUid: cp?.googleUid || u.googleUid || null,
          status: 'Active',
          tier: 'Athlete',
          role: u.role,
          createdAt: u.createdAt.toISOString(),
          dailyStepGoal: cp?.dailyStepGoal ?? 6000,
          fitnessLevel: cp?.fitnessLevel ?? 'beginner',
          primaryGoal: cp?.primaryGoal ?? 'Fat Loss',
          secondaryGoal: cp?.secondaryGoal ?? null,
          weightKg: cp?.weightKg ?? null,
          heightCm: cp?.heightCm ?? null,
          age: cp?.age ?? null,
          gender: cp?.gender ?? null,
          trainingExperience: cp?.trainingExperience ?? null,
          trainingDaysPerWeek: cp?.trainingDaysPerWeek ?? 3,
          hasCurrentInjury: cp?.hasCurrentInjury ?? false,
          injuryAreas: cp?.injuryAreas ?? [],
          injuryDescription: cp?.injuryDescription ?? null,
          hasPreviousSurgery: cp?.hasPreviousSurgery ?? false,
          surgeryDetails: cp?.surgeryDetails ?? null,
          activityLevel: cp?.activityLevel ?? 'MODERATE',
          sleepHours: cp?.sleepHours ?? '7–8 hours',
          dailySteps: cp?.dailySteps ?? (cp?.dailyStepGoal ?? 6000),
          trainingTimePref: cp?.trainingTimePref ?? null,
          preferredDays: cp?.preferredDays ?? [],
          trainingPreferences: cp?.trainingPreferences ?? [],
          onboardingCompleted: cp?.onboardingCompleted ?? false,
          onboardingStep: cp?.onboardingStep ?? 0,
        };
      });
    } catch (err) {
      console.error('[DATABASE GET CLIENTS ERROR]', err);
      return [];
    }
  }

  async getClientWorkoutResults(clientId: string) {
    const history = await workoutRepository.getClientWorkoutHistory(clientId);
    let clientName = 'Athlete Member';
    let clientEmail = 'client@alphaxgym.com';

    try {
      const dbUser = await prisma.user.findUnique({
        where: { id: clientId },
        select: { id: true, name: true, email: true },
      });
      if (dbUser) {
        clientName = dbUser.name;
        clientEmail = dbUser.email;
      }
    } catch (_) {}

    const totalCompleted = history.filter((h) => h.isCompleted).length;
    const totalVolume = history.reduce((sum, h) => sum + h.totalVolume, 0);
    const totalDurationSeconds = history.reduce((sum, h) => sum + h.durationSeconds, 0);

    return {
      client: { id: clientId, name: clientName, email: clientEmail },
      stats: {
        totalCompleted,
        totalVolumeKg: totalVolume,
        totalHours: Number((totalDurationSeconds / 3600).toFixed(1)),
      },
      history,
    };
  }

  // --- Client Scoped Operations ---
  async getClientSessions(clientId: string) {
    return workoutRepository.getClientAuthorizedSessions(clientId);
  }

  async getClientSessionById(sessionId: string, clientId: string): Promise<StoredWorkoutSession | null> {
    const authData = await workoutRepository.getClientAuthorizedSessions(clientId);
    const session = authData.available.find((s) => s.id === sessionId)
                 || authData.pendingWorkouts?.find((s) => s.id === sessionId)
                 || (authData.todaySession?.id === sessionId ? authData.todaySession : null);
    return session ?? null;
  }

  async getPreviousPerformance(clientId: string, exerciseId: string) {
    return workoutRepository.getPreviousPerformance(clientId, exerciseId);
  }

  async recordWorkout(clientId: string, data: any): Promise<StoredWorkoutRecord> {
    const savedRecord = await workoutRepository.saveWorkoutRecord(clientId, data);

    // Autonomous Proactive AI Event Trigger: Post-Workout Celebration & Recovery Guidance
    // Strictly guarded: only fires upon final workout session completion
    if (savedRecord.isCompleted) {
      aiNotificationEngine.sendPostWorkoutCelebration(clientId, savedRecord).catch((err) => {
        console.warn('[WORKOUT SERVICE] Post-workout proactive notification error:', err?.message);
      });
    }

    return savedRecord;
  }

  async getClientHistory(clientId: string): Promise<StoredWorkoutRecord[]> {
    return workoutRepository.getClientWorkoutHistory(clientId);
  }

  async getWorkoutRecordById(recordId: string, clientId: string): Promise<StoredWorkoutRecord | null> {
    const record = await workoutRepository.getWorkoutRecordById(recordId);
    if (!record || record.clientId !== clientId) {
      return null;
    }
    return record;
  }

  async toggleSetCompletion(clientId: string, sessionId: string, data: any) {
    return workoutRepository.saveSetCompletion(clientId, sessionId, data);
  }

  async getActiveSetCompletions(clientId: string, sessionId: string) {
    return workoutRepository.getActiveSetCompletions(clientId, sessionId);
  }

  // --- Client Session Customizations & Persistent Overrides ---
  async getClientSessionOverride(clientId: string, sessionId: string, dayOfWeek?: string) {
    return workoutRepository.getClientSessionOverride(clientId, sessionId, dayOfWeek);
  }

  async saveClientSessionOverride(clientId: string, sessionId: string, data: any, dayOfWeek?: string) {
    return workoutRepository.saveClientSessionOverride(clientId, sessionId, data, dayOfWeek);
  }

  async replaceExerciseInSession(clientId: string, sessionId: string, replacement: any, dayOfWeek?: string) {
    return workoutRepository.replaceExerciseInSession(clientId, sessionId, replacement, dayOfWeek);
  }

  async addExerciseToSessionOverride(clientId: string, sessionId: string, exercise: any, dayOfWeek?: string) {
    return workoutRepository.addExerciseToSessionOverride(clientId, sessionId, exercise, dayOfWeek);
  }

  async removeExerciseFromSessionOverride(clientId: string, sessionId: string, exerciseId: string, dayOfWeek?: string) {
    return workoutRepository.removeExerciseFromSessionOverride(clientId, sessionId, exerciseId, dayOfWeek);
  }

  async resetSessionOverride(clientId: string, sessionId: string, exerciseId?: string) {
    if (exerciseId) {
      return workoutRepository.resetExerciseInSessionOverride(clientId, sessionId, exerciseId);
    }
    return workoutRepository.resetSessionOverride(clientId, sessionId);
  }

  // --- Workout Split Operations ---
  async createWorkoutSplit(data: any, adminId: string): Promise<StoredWorkoutSplitPlan> {
    return workoutRepository.saveWorkoutSplit(data, adminId);
  }

  async getClientWorkoutSplit(clientId: string): Promise<StoredWorkoutSplitPlan | null> {
    return workoutRepository.getClientWorkoutSplit(clientId);
  }

  async getWorkoutSplitById(splitId: string): Promise<StoredWorkoutSplitPlan | null> {
    return workoutRepository.getWorkoutSplitById(splitId);
  }

  async updateWorkoutSplitDay(splitId: string, dayId: string, dayData: any): Promise<StoredWorkoutSession | null> {
    return workoutRepository.updateWorkoutSplitDay(splitId, dayId, dayData);
  }

  async assignWorkoutSplit(splitId: string, params: { clientIds?: string[]; isRecommended?: boolean }, adminId: string): Promise<boolean> {
    const split = await workoutRepository.getClientWorkoutSplit(params.clientIds?.[0] || '');
    if (!split) return false;
    const todayWeekday = getTodayISTWeekday();
    for (const d of split.days) {
      if (d.sessionId && !d.isRestDay) {
        const weekdayNum = d.dayIndex || (d.dayOfWeek ? getWeekdayFromDayName(d.dayOfWeek) : 1);
        const scheduledDate = getISTDateForWeekday(weekdayNum);
        const isToday = weekdayNum === todayWeekday;
        await this.assignSession({
          sessionId: d.sessionId,
          assignmentType: 'SELECTED',
          clientIds: params.clientIds,
          isRecommended: isToday,
          scheduledDate,
          assignedById: adminId,
        });
      }
    }
    return true;
  }
}

export const workoutService = new WorkoutService();
