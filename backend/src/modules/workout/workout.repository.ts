export interface StoredSessionExercise {
  id: string;
  sessionId: string;
  exerciseId: string;
  exerciseName: string;
  category: string;
  orderIndex: number;
  supersetTag?: string | null; // e.g. "A1", "A2"
  numberOfSets: number;
  targetReps: string;
  targetWeight?: number | null;
  restSeconds: number;
  targetRir?: number | null;
  targetRpe?: number | null;
  tempo?: string | null;
  setType: string; // 'Warm-up', 'Working', 'Failure', 'Drop set', 'Rest-pause'
  exerciseNotes?: string | null;
  adminInstruction?: string | null;
}

export interface StoredWorkoutSession {
  id: string;
  title: string;
  workoutType: string;
  targetMuscleGroup: string;
  difficulty: string;
  estimatedDurationMinutes: number;
  description?: string | null;
  isActive: boolean;
  startDate?: string | null;
  endDate?: string | null;
  recurringSchedule?: string | null;
  availabilityType: 'ALL' | 'SELECTED' | 'INDIVIDUAL';
  createdById?: string;
  createdAt: string;
  updatedAt: string;
  exercises: StoredSessionExercise[];
}

export interface StoredWorkoutAssignment {
  id: string;
  sessionId: string;
  clientId: string | null; // null for ALL clients
  isRecommended: boolean;
  assignedById: string;
  assignedAt: string;
  active: boolean;
}

export interface StoredWorkoutSetRecord {
  setNumber: number;
  setType: string;
  targetReps?: string | null;
  targetWeight?: number | null;
  actualWeight?: number | null;
  actualReps?: number | null;
  actualRir?: number | null;
  actualRpe?: number | null;
  tempo?: string | null;
  isCompleted: boolean;
  completedAt?: string | null;
  notes?: string | null;
}

export interface StoredWorkoutExerciseRecord {
  exerciseId: string;
  exerciseName: string;
  orderIndex: number;
  supersetTag?: string | null;
  isSkipped: boolean;
  skipReason?: string | null;
  clientNote?: string | null;
  adminNote?: string | null;
  sets: StoredWorkoutSetRecord[];
}

export interface StoredWorkoutRecord {
  id: string;
  clientId: string;
  sessionId?: string | null;
  sessionTitle: string;
  workoutType: string;
  startedAt: string;
  completedAt?: string | null;
  durationSeconds: number;
  totalVolume: number;
  completedSetsCount: number;
  skippedSetsCount: number;
  averageRpe?: number | null;
  averageRir?: number | null;
  isCompleted: boolean;
  personalRecords: any[];
  notes?: string | null;
  createdAt: string;
  updatedAt: string;
  exerciseRecords: StoredWorkoutExerciseRecord[];
}

export class WorkoutRepository {
  private sessions: Map<string, StoredWorkoutSession> = new Map();
  private assignments: Map<string, StoredWorkoutAssignment> = new Map();
  private records: Map<string, StoredWorkoutRecord> = new Map();

  // Real registered clients are queried dynamically from PostgreSQL via workoutService.getClientsList()
  public clientsList: { id: string; name: string; email: string; status: string }[] = [];

  constructor() {
    this.seedDefaultSessions();
  }

  private seedDefaultSessions() {
    // 1. Session: Push A (Recommended)
    const pushAId = 'ws_push_a_01';
    const pushA: StoredWorkoutSession = {
      id: pushAId,
      title: 'Push A',
      workoutType: 'Strength',
      targetMuscleGroup: 'Chest • Shoulders • Triceps',
      difficulty: 'Intermediate',
      estimatedDurationMinutes: 55,
      description: 'High-intensity upper body pressing prioritizing clavicular chest and lateral delts with rest-pause work.',
      isActive: true,
      startDate: new Date().toISOString(),
      endDate: null,
      recurringSchedule: 'Monday, Thursday',
      availabilityType: 'ALL',
      createdById: 'admin_alex_stone',
      createdAt: new Date(Date.now() - 7 * 86400000).toISOString(),
      updatedAt: new Date().toISOString(),
      exercises: [
        {
          id: 'ex_s1_1',
          sessionId: pushAId,
          exerciseId: 'ex_incline_smith',
          exerciseName: 'Incline Smith Machine Press',
          category: 'Chest',
          orderIndex: 0,
          supersetTag: null,
          numberOfSets: 4,
          targetReps: '8',
          targetWeight: 80.0,
          restSeconds: 120,
          targetRir: 2,
          targetRpe: 8.0,
          tempo: '3-1-1-0',
          setType: 'Working',
          exerciseNotes: 'Keep scapulae retracted against bench. Control eccentric.',
          adminInstruction: 'Keep 2 RIR. 2-3 sec eccentric descent.',
        },
        {
          id: 'ex_s1_2',
          sessionId: pushAId,
          exerciseId: 'ex_incline_db',
          exerciseName: 'Incline Dumbbell Press',
          category: 'Chest',
          orderIndex: 1,
          supersetTag: null,
          numberOfSets: 3,
          targetReps: '10',
          targetWeight: 32.0,
          restSeconds: 90,
          targetRir: 2,
          targetRpe: 8.0,
          tempo: '3-1-1-0',
          setType: 'Working',
          exerciseNotes: 'Deep stretch at bottom.',
          adminInstruction: 'Do not clack dumbbells together at lockout.',
        },
        {
          id: 'ex_s1_3',
          sessionId: pushAId,
          exerciseId: 'ex_lat_raise',
          exerciseName: 'Dumbbell Lateral Raise',
          category: 'Shoulders',
          orderIndex: 2,
          supersetTag: 'A1',
          numberOfSets: 3,
          targetReps: '15',
          targetWeight: 14.0,
          restSeconds: 30, // Superset fast transition
          targetRir: 1,
          targetRpe: 9.0,
          tempo: '2-0-1-1',
          setType: 'Working',
          exerciseNotes: 'Superset Part 1: Strict form, lead with elbows.',
          adminInstruction: 'Superset A1: Proceed immediately to A2 Cable Fly without resting.',
        },
        {
          id: 'ex_s1_4',
          sessionId: pushAId,
          exerciseId: 'ex_cable_fly',
          exerciseName: 'Cable Chest Fly',
          category: 'Chest',
          orderIndex: 3,
          supersetTag: 'A2',
          numberOfSets: 3,
          targetReps: '12',
          targetWeight: 18.0,
          restSeconds: 90, // Superset full rest
          targetRir: 1,
          targetRpe: 8.5,
          tempo: '2-1-1-1',
          setType: 'Working',
          exerciseNotes: 'Superset Part 2: Squeeze pecs at midline hold 1 second.',
          adminInstruction: 'Superset A2: Full rest after completing both movements.',
        },
        {
          id: 'ex_s1_5',
          sessionId: pushAId,
          exerciseId: 'ex_rope_pushdown',
          exerciseName: 'Triceps Rope Pushdown',
          category: 'Triceps',
          orderIndex: 4,
          supersetTag: null,
          numberOfSets: 3,
          targetReps: '12',
          targetWeight: 25.0,
          restSeconds: 60,
          targetRir: 2,
          targetRpe: 8.5,
          tempo: '2-0-1-1',
          setType: 'Working',
          exerciseNotes: 'Flare rope outward at bottom contraction.',
          adminInstruction: 'Lock elbows to ribs.',
        },
      ],
    };
    this.sessions.set(pushAId, pushA);

    // Assignment: Push A is recommended for ALL clients
    const pushAAssignment: StoredWorkoutAssignment = {
      id: 'assign_push_a_all',
      sessionId: pushAId,
      clientId: null,
      isRecommended: true,
      assignedById: 'admin_alex_stone',
      assignedAt: new Date().toISOString(),
      active: true,
    };
    this.assignments.set(pushAAssignment.id, pushAAssignment);

    // 2. Session: Pull A
    const pullAId = 'ws_pull_a_02';
    const pullA: StoredWorkoutSession = {
      id: pullAId,
      title: 'Pull A',
      workoutType: 'Hypertrophy',
      targetMuscleGroup: 'Back • Biceps • Rear Delts',
      difficulty: 'Intermediate',
      estimatedDurationMinutes: 60,
      description: 'Lat width emphasis and elbow flexion strength with strict tempo control.',
      isActive: true,
      startDate: new Date().toISOString(),
      endDate: null,
      recurringSchedule: 'Tuesday, Friday',
      availabilityType: 'ALL',
      createdById: 'admin_alex_stone',
      createdAt: new Date(Date.now() - 6 * 86400000).toISOString(),
      updatedAt: new Date().toISOString(),
      exercises: [
        {
          id: 'ex_s2_1',
          sessionId: pullAId,
          exerciseId: 'ex_lat_pulldown',
          exerciseName: 'Wide Grip Lat Pulldown',
          category: 'Back',
          orderIndex: 0,
          supersetTag: null,
          numberOfSets: 4,
          targetReps: '10–12',
          targetWeight: 65.0,
          restSeconds: 90,
          targetRir: 2,
          targetRpe: 8.0,
          tempo: '3-0-1-1',
          setType: 'Working',
          exerciseNotes: 'Pull to collarbone, depress scapula.',
          adminInstruction: 'Do not swing hips.',
        },
        {
          id: 'ex_s2_2',
          sessionId: pullAId,
          exerciseId: 'ex_seated_cable_row',
          exerciseName: 'Seated Cable Row',
          category: 'Back',
          orderIndex: 1,
          supersetTag: null,
          numberOfSets: 3,
          targetReps: '8–10',
          targetWeight: 70.0,
          restSeconds: 90,
          targetRir: 2,
          targetRpe: 8.5,
          tempo: '2-1-1-0',
          setType: 'Working',
          exerciseNotes: 'Drive elbows back.',
          adminInstruction: 'Hold peak contraction 1 sec.',
        },
        {
          id: 'ex_s2_3',
          sessionId: pullAId,
          exerciseId: 'ex_face_pull',
          exerciseName: 'Cable Rope Face Pull',
          category: 'Shoulders',
          orderIndex: 2,
          supersetTag: null,
          numberOfSets: 3,
          targetReps: '15',
          targetWeight: 22.5,
          restSeconds: 60,
          targetRir: 2,
          targetRpe: 8.0,
          tempo: '2-1-1-0',
          setType: 'Working',
          exerciseNotes: 'Pull towards bridge of nose.',
          adminInstruction: 'Externally rotate thumbs backward.',
        },
      ],
    };
    this.sessions.set(pullAId, pullA);

    const pullAAssignment: StoredWorkoutAssignment = {
      id: 'assign_pull_a_all',
      sessionId: pullAId,
      clientId: null,
      isRecommended: false,
      assignedById: 'admin_alex_stone',
      assignedAt: new Date().toISOString(),
      active: true,
    };
    this.assignments.set(pullAAssignment.id, pullAAssignment);

    // 3. Session: Legs A
    const legsAId = 'ws_legs_a_03';
    const legsA: StoredWorkoutSession = {
      id: legsAId,
      title: 'Legs A',
      workoutType: 'Strength',
      targetMuscleGroup: 'Quads • Hamstrings • Calves',
      difficulty: 'Advanced',
      estimatedDurationMinutes: 65,
      description: 'Heavy compound leg session with quad-dominant squatting followed by hamstring curls.',
      isActive: true,
      startDate: new Date().toISOString(),
      endDate: null,
      recurringSchedule: 'Wednesday, Saturday',
      availabilityType: 'ALL',
      createdById: 'admin_alex_stone',
      createdAt: new Date(Date.now() - 5 * 86400000).toISOString(),
      updatedAt: new Date().toISOString(),
      exercises: [
        {
          id: 'ex_s3_1',
          sessionId: legsAId,
          exerciseId: 'ex_bb_squat',
          exerciseName: 'Barbell Back Squat',
          category: 'Legs',
          orderIndex: 0,
          supersetTag: null,
          numberOfSets: 4,
          targetReps: '6–8',
          targetWeight: 140.0,
          restSeconds: 150,
          targetRir: 2,
          targetRpe: 8.5,
          tempo: '3-1-X-0',
          setType: 'Working',
          exerciseNotes: 'Hit parallel depth, knees track over toes.',
          adminInstruction: 'Brace abdominal wall with valsalva maneuver.',
        },
        {
          id: 'ex_s3_2',
          sessionId: legsAId,
          exerciseId: 'ex_leg_press',
          exerciseName: '45-Degree Leg Press',
          category: 'Legs',
          orderIndex: 1,
          supersetTag: null,
          numberOfSets: 3,
          targetReps: '10–12',
          targetWeight: 220.0,
          restSeconds: 120,
          targetRir: 1,
          targetRpe: 9.0,
          tempo: '3-0-1-0',
          setType: 'Working',
          exerciseNotes: 'Do not lock out knees at top.',
          adminInstruction: 'Full deep range without pelvis lifting off pad.',
        },
      ],
    };
    this.sessions.set(legsAId, legsA);

    const legsAAssignment: StoredWorkoutAssignment = {
      id: 'assign_legs_a_all',
      sessionId: legsAId,
      clientId: null,
      isRecommended: false,
      assignedById: 'admin_alex_stone',
      assignedAt: new Date().toISOString(),
      active: true,
    };
    this.assignments.set(legsAAssignment.id, legsAAssignment);

    // Seed baseline historical record for client_john_doe (to power "LAST TIME: 80 kg x 8")
    const pastRecordId = 'rec_seed_push_a_john';
    const pastRecord: StoredWorkoutRecord = {
      id: pastRecordId,
      clientId: 'client_john_doe',
      sessionId: pushAId,
      sessionTitle: 'Push A',
      workoutType: 'Strength',
      startedAt: new Date(Date.now() - 3 * 86400000).toISOString(),
      completedAt: new Date(Date.now() - 3 * 86400000 + 58 * 60000).toISOString(),
      durationSeconds: 58 * 60,
      totalVolume: 5640.0,
      completedSetsCount: 16,
      skippedSetsCount: 0,
      averageRpe: 8.2,
      averageRir: 1.8,
      isCompleted: true,
      personalRecords: [
        {
          type: 'weight',
          exerciseName: 'Incline Smith Machine Press',
          value: 80.0,
          weight: 80.0,
          reps: 8,
          achievedAt: new Date(Date.now() - 3 * 86400000).toISOString(),
        },
      ],
      notes: 'Felt strong on incline press, solid stability.',
      createdAt: new Date(Date.now() - 3 * 86400000).toISOString(),
      updatedAt: new Date(Date.now() - 3 * 86400000).toISOString(),
      exerciseRecords: [
        {
          exerciseId: 'ex_incline_smith',
          exerciseName: 'Incline Smith Machine Press',
          orderIndex: 0,
          isSkipped: false,
          clientNote: 'Solid bar speed on set 2 and 3.',
          adminNote: 'Keep 2 RIR. 2-3 sec eccentric descent.',
          sets: [
            {
              setNumber: 1,
              setType: 'Working',
              targetReps: '8',
              targetWeight: 80.0,
              actualWeight: 80.0,
              actualReps: 8,
              actualRir: 2,
              actualRpe: 8.0,
              isCompleted: true,
            },
            {
              setNumber: 2,
              setType: 'Working',
              targetReps: '8',
              targetWeight: 80.0,
              actualWeight: 80.0,
              actualReps: 8,
              actualRir: 2,
              actualRpe: 8.0,
              isCompleted: true,
            },
            {
              setNumber: 3,
              setType: 'Working',
              targetReps: '8',
              targetWeight: 80.0,
              actualWeight: 82.5,
              actualReps: 7,
              actualRir: 1,
              actualRpe: 8.5,
              isCompleted: true,
            },
          ],
        },
      ],
    };
    this.records.set(pastRecordId, pastRecord);
  }

  // --- Admin Session Operations ---
  async getAllSessions(): Promise<StoredWorkoutSession[]> {
    return Array.from(this.sessions.values()).sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  }

  async getSessionById(id: string): Promise<StoredWorkoutSession | null> {
    return this.sessions.get(id) ?? null;
  }

  async createSession(data: Omit<StoredWorkoutSession, 'id' | 'createdAt' | 'updatedAt'>): Promise<StoredWorkoutSession> {
    const id = `ws_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const now = new Date().toISOString();
    const session: StoredWorkoutSession = {
      ...data,
      id,
      createdAt: now,
      updatedAt: now,
      exercises: data.exercises.map((ex, idx) => ({
        ...ex,
        id: ex.id || `ex_${id}_${idx + 1}`,
        sessionId: id,
        orderIndex: ex.orderIndex ?? idx,
      })),
    };
    this.sessions.set(id, session);
    return session;
  }

  async updateSession(id: string, data: Partial<StoredWorkoutSession>): Promise<StoredWorkoutSession | null> {
    const existing = this.sessions.get(id);
    if (!existing) return null;

    const updated: StoredWorkoutSession = {
      ...existing,
      ...data,
      updatedAt: new Date().toISOString(),
      exercises: data.exercises
        ? data.exercises.map((ex, idx) => ({
            ...ex,
            id: ex.id || `ex_${id}_${idx + 1}`,
            sessionId: id,
            orderIndex: ex.orderIndex ?? idx,
          }))
        : existing.exercises,
    };
    this.sessions.set(id, updated);
    return updated;
  }

  async duplicateSession(id: string): Promise<StoredWorkoutSession | null> {
    const existing = this.sessions.get(id);
    if (!existing) return null;

    const newId = `ws_${Date.now()}_copy`;
    const now = new Date().toISOString();
    const copy: StoredWorkoutSession = {
      ...existing,
      id: newId,
      title: `${existing.title} (Copy)`,
      createdAt: now,
      updatedAt: now,
      exercises: existing.exercises.map((ex, idx) => ({
        ...ex,
        id: `ex_${newId}_${idx + 1}`,
        sessionId: newId,
      })),
    };
    this.sessions.set(newId, copy);
    return copy;
  }

  async toggleActive(id: string): Promise<StoredWorkoutSession | null> {
    const existing = this.sessions.get(id);
    if (!existing) return null;
    existing.isActive = !existing.isActive;
    existing.updatedAt = new Date().toISOString();
    this.sessions.set(id, existing);
    return existing;
  }

  async deleteSession(id: string): Promise<boolean> {
    if (!this.sessions.has(id)) return false;
    this.sessions.delete(id);
    // Remove cascade assignments
    for (const [key, assign] of this.assignments.entries()) {
      if (assign.sessionId === id) {
        this.assignments.delete(key);
      }
    }
    return true;
  }

  // --- Assignment Operations ---
  async getAssignmentsForSession(sessionId: string): Promise<StoredWorkoutAssignment[]> {
    return Array.from(this.assignments.values()).filter((a) => a.sessionId === sessionId && a.active);
  }

  async getAllAssignments(): Promise<StoredWorkoutAssignment[]> {
    return Array.from(this.assignments.values()).filter((a) => a.active);
  }

  async assignSession(params: {
    sessionId: string;
    assignmentType: 'ALL' | 'SELECTED' | 'INDIVIDUAL';
    clientIds?: string[];
    individualClientId?: string | null;
    isRecommended?: boolean;
    assignedById: string;
  }): Promise<StoredWorkoutAssignment[]> {
    const { sessionId, assignmentType, clientIds = [], individualClientId, isRecommended = false, assignedById } = params;
    const results: StoredWorkoutAssignment[] = [];
    const now = new Date().toISOString();

    // If making this session recommended, unset existing recommended assignments for these targets
    if (isRecommended) {
      for (const a of this.assignments.values()) {
        if (assignmentType === 'ALL' && a.clientId === null) {
          a.isRecommended = false;
        } else if (assignmentType === 'INDIVIDUAL' && a.clientId === individualClientId) {
          a.isRecommended = false;
        }
      }
    }

    if (assignmentType === 'ALL') {
      const existingKey = `assign_${sessionId}_all`;
      const assignment: StoredWorkoutAssignment = {
        id: existingKey,
        sessionId,
        clientId: null,
        isRecommended,
        assignedById,
        assignedAt: now,
        active: true,
      };
      this.assignments.set(existingKey, assignment);
      results.push(assignment);
    } else if (assignmentType === 'INDIVIDUAL' && individualClientId) {
      const existingKey = `assign_${sessionId}_${individualClientId}`;
      const assignment: StoredWorkoutAssignment = {
        id: existingKey,
        sessionId,
        clientId: individualClientId,
        isRecommended,
        assignedById,
        assignedAt: now,
        active: true,
      };
      this.assignments.set(existingKey, assignment);
      results.push(assignment);
    } else if (assignmentType === 'SELECTED') {
      for (const cId of clientIds) {
        const key = `assign_${sessionId}_${cId}`;
        const assignment: StoredWorkoutAssignment = {
          id: key,
          sessionId,
          clientId: cId,
          isRecommended,
          assignedById,
          assignedAt: now,
          active: true,
        };
        this.assignments.set(key, assignment);
        results.push(assignment);
      }
    }

    return results;
  }

  async unassign(assignmentId: string): Promise<boolean> {
    if (this.assignments.has(assignmentId)) {
      this.assignments.delete(assignmentId);
      return true;
    }
    return false;
  }

  // --- Client Operations (Scoped) ---
  async getClientAuthorizedSessions(clientId: string): Promise<{
    recommended: (StoredWorkoutSession & { isRecommended: boolean }) | null;
    available: StoredWorkoutSession[];
  }> {
    const activeSessions = Array.from(this.sessions.values()).filter((s) => s.isActive);
    // Client-specific assignments take priority over global (null) assignments
    const clientAssignments = Array.from(this.assignments.values())
      .filter((a) => a.active && (a.clientId === null || a.clientId === clientId))
      .sort((a, b) => {
        if (a.clientId !== null && b.clientId === null) return -1;
        if (a.clientId === null && b.clientId !== null) return 1;
        return 0;
      });

    const authorizedSessionIds = new Set(clientAssignments.map((a) => a.sessionId));
    const authorizedSessions = activeSessions.filter((s) => authorizedSessionIds.has(s.id));

    // Find recommended session
    const recommendedAssignment = clientAssignments.find((a) => a.isRecommended);
    let recommended: (StoredWorkoutSession & { isRecommended: boolean }) | null = null;

    if (recommendedAssignment) {
      const recSession = authorizedSessions.find((s) => s.id === recommendedAssignment.sessionId);
      if (recSession) {
        recommended = { ...recSession, isRecommended: true };
      }
    }

    return {
      recommended,
      available: authorizedSessions,
    };
  }

  async getPreviousPerformance(clientId: string, exerciseId: string): Promise<{
    lastWeight?: number;
    lastReps?: number;
    lastRir?: number;
    lastRpe?: number;
    sets: Array<{ weight: number; reps: number; rpe?: number; rir?: number }>;
    completedAt?: string;
  } | null> {
    const clientRecords = Array.from(this.records.values())
      .filter((r) => r.clientId === clientId && r.isCompleted)
      .sort((a, b) => b.startedAt.localeCompare(a.startedAt));

    for (const record of clientRecords) {
      const exRecord = record.exerciseRecords.find((e) => e.exerciseId === exerciseId && !e.isSkipped);
      if (exRecord && exRecord.sets.length > 0) {
        const completedSets = exRecord.sets.filter((s) => s.isCompleted && s.actualWeight && s.actualReps);
        if (completedSets.length > 0) {
          const firstSet = completedSets[0];
          return {
            lastWeight: firstSet.actualWeight ?? undefined,
            lastReps: firstSet.actualReps ?? undefined,
            lastRir: firstSet.actualRir ?? undefined,
            lastRpe: firstSet.actualRpe ?? undefined,
            sets: completedSets.map((s) => ({
              weight: s.actualWeight!,
              reps: s.actualReps!,
              rpe: s.actualRpe ?? undefined,
              rir: s.actualRir ?? undefined,
            })),
            completedAt: record.completedAt ?? record.startedAt,
          };
        }
      }
    }
    return null;
  }

  async saveWorkoutRecord(clientId: string, data: Omit<StoredWorkoutRecord, 'id' | 'clientId' | 'createdAt' | 'updatedAt'>): Promise<StoredWorkoutRecord> {
    const id = `rec_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const now = new Date().toISOString();
    const record: StoredWorkoutRecord = {
      ...data,
      id,
      clientId,
      createdAt: now,
      updatedAt: now,
    };
    this.records.set(id, record);
    return record;
  }

  async getClientWorkoutHistory(clientId: string, limit: number = 50): Promise<StoredWorkoutRecord[]> {
    return Array.from(this.records.values())
      .filter((r) => r.clientId === clientId)
      .sort((a, b) => b.startedAt.localeCompare(a.startedAt))
      .slice(0, limit);
  }

  async getWorkoutRecordById(id: string): Promise<StoredWorkoutRecord | null> {
    return this.records.get(id) ?? null;
  }
}

export const workoutRepository = new WorkoutRepository();
