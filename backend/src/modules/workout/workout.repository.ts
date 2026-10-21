import { prisma } from '../../config/prisma';
import {
  getTodayISTDateString,
  toISTDateString,
  isSessionScheduledForDate,
  getTodayISTWeekday,
  getISTDateForWeekday,
  getWeekdayFromDayName,
  parseWeekdaysFromScheduleString,
  getWeekdayFromISTDateString,
} from '../../utils/istDate';

export interface StoredWorkoutSplitDay {
  id?: string;
  sessionId?: string;
  dayOfWeek: string;
  dayIndex: number;
  name: string;
  workoutType: string;
  targetMuscleGroup: string;
  estimatedDurationMinutes: number;
  isRestDay: boolean;
  notes?: string | null;
  exercises: StoredSessionExercise[];
}

export interface StoredWorkoutSplitPlan {
  id: string;
  title: string;
  splitType: string;
  description?: string | null;
  frequencyPerWeek: number;
  clientId?: string | null;
  clientIds?: string[];
  clientName?: string | null;
  createdAt: string;
  updatedAt: string;
  days: StoredWorkoutSplitDay[];
}

export interface StoredSessionExercise {
  id: string;
  sessionId: string;
  exerciseId: string;
  exerciseName: string;
  category: string;
  orderIndex: number;
  supersetTag?: string | null; // e.g. "A1", "A2"
  numberOfSets: number;
  setCount?: number;
  setsCount?: number;
  totalSets?: number;
  targetSets?: number;
  targetReps: string;
  targetWeight?: number | null;
  restSeconds: number;
  targetRir?: number | null;
  targetRpe?: number | null;
  tempo?: string | null;
  setType: string; // 'Warm-up', 'Working', 'Failure', 'Drop set', 'Rest-pause'
  exerciseNotes?: string | null;
  adminInstruction?: string | null;
  sets?: any[];
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
  scheduledDate?: string | null;
  isLocked?: boolean;
  lockedAt?: string | null;
  status?: string;
  assignmentId?: string | null;
  exercises: StoredSessionExercise[];
}

export interface StoredWorkoutAssignment {
  id: string;
  sessionId: string;
  clientId: string | null; // null for ALL clients
  isRecommended: boolean;
  assignedById: string;
  assignedAt: string;
  scheduledDate?: string | null;
  active: boolean;
  status?: string;
  completedAt?: string | null;
  isLocked?: boolean;
  lockedAt?: string | null;
  unlockedAt?: string | null;
  unlockedById?: string | null;
  unlockReason?: string | null;
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
  assignmentId?: string | null;
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
  isLocked?: boolean;
  lockedAt?: string | null;
  unlockedAt?: string | null;
  unlockedById?: string | null;
  unlockReason?: string | null;
  scheduledDate?: string | null;
  personalRecords: any[];
  notes?: string | null;
  createdAt: string;
  updatedAt: string;
  exerciseRecords: StoredWorkoutExerciseRecord[];
}

export interface ClientExerciseReplacement {
  originalExerciseId: string;
  originalExerciseName?: string;
  replacementExerciseId: string;
  replacementExerciseName: string;
  category?: string;
  primaryMusclesDisplay?: string;
  secondaryMusclesDisplay?: string;
  trainerNote?: string;
  numberOfSets?: number;
  targetReps?: string;
  targetWeight?: number | null;
  customSets?: any[];
}

export interface ClientSessionOverrideData {
  replacements?: ClientExerciseReplacement[];
  addedExercises?: any[];
  removedExerciseIds?: string[];
  customSetsByExercise?: Record<string, any[]>;
  customSetCounts?: Record<string, number>;
}

function toISO(val: any, fallback?: string): string {
  if (!val) return fallback || '';
  if (val instanceof Date) return val.toISOString();
  if (typeof val === 'string') return val;
  try {
    const d = new Date(val);
    return isNaN(d.getTime()) ? (fallback || '') : d.toISOString();
  } catch {
    return fallback || '';
  }
}

function toISONullable(val: any): string | null {
  if (!val) return null;
  if (val instanceof Date) return val.toISOString();
  if (typeof val === 'string') return val;
  try {
    const d = new Date(val);
    return isNaN(d.getTime()) ? null : d.toISOString();
  } catch {
    return null;
  }
}

function mapPrismaSessionToStored(s: any): StoredWorkoutSession {
  return {
    id: s.id,
    title: s.title,
    workoutType: s.workoutType,
    targetMuscleGroup: s.targetMuscleGroup,
    difficulty: s.difficulty,
    estimatedDurationMinutes: s.estimatedDurationMinutes,
    description: s.description,
    isActive: s.isActive,
    startDate: toISONullable(s.startDate),
    endDate: toISONullable(s.endDate),
    recurringSchedule: s.recurringSchedule,
    availabilityType: (s.availabilityType as any) || 'ALL',
    createdById: s.createdById,
    createdAt: toISO(s.createdAt, new Date().toISOString()),
    updatedAt: toISO(s.updatedAt, new Date().toISOString()),
    scheduledDate: s.scheduledDate || null,
    isLocked: s.isLocked ?? false,
    lockedAt: toISONullable(s.lockedAt),
    status: s.status || 'ASSIGNED',
    assignmentId: s.assignmentId || null,
    exercises: (s.exercises || []).map((ex: any) => {
      const numSets = Number(ex.numberOfSets) || (Array.isArray(ex.setTemplates) && ex.setTemplates.length > 0 ? ex.setTemplates.length : (Array.isArray(ex.sets) && ex.sets.length > 0 ? ex.sets.length : (Number(ex.setCount) || 3)));
      let setsList: any[] = [];
      if (Array.isArray(ex.setTemplates) && ex.setTemplates.length > 0) {
        setsList = ex.setTemplates.map((st: any, sIdx: number) => ({
          id: st.id || `set_${ex.id || 'ex'}_${sIdx + 1}`,
          setNumber: st.setNumber ?? (sIdx + 1),
          setType: st.setType || ex.setType || 'Working',
          targetRepsMin: st.targetRepsMin ?? 8,
          targetRepsMax: st.targetRepsMax ?? 12,
          targetReps: st.targetRepsMin ? (st.targetRepsMax ? `${st.targetRepsMin}–${st.targetRepsMax}` : `${st.targetRepsMin}`) : (ex.targetReps || '8–12'),
          targetWeight: st.targetWeight !== undefined && st.targetWeight !== null ? Number(st.targetWeight) : (ex.targetWeight !== undefined && ex.targetWeight !== null ? Number(ex.targetWeight) : null),
          targetRir: st.targetRir !== undefined && st.targetRir !== null ? Number(st.targetRir) : (ex.targetRir ?? 2),
          targetRpe: st.targetRpe !== undefined && st.targetRpe !== null ? Number(st.targetRpe) : (ex.targetRpe ?? 8.0),
          restSeconds: ex.restSeconds || 90,
          tempo: st.tempo || ex.tempo || '3-1-1-0',
          isCompleted: false,
        }));
      } else if (Array.isArray(ex.sets) && ex.sets.length > 0) {
        setsList = ex.sets.map((st: any, sIdx: number) => ({
          id: st.id || `set_${ex.id || 'ex'}_${sIdx + 1}`,
          setNumber: st.setNumber ?? (sIdx + 1),
          setType: st.setType || ex.setType || 'Working',
          targetRepsMin: st.targetRepsMin ?? 8,
          targetRepsMax: st.targetRepsMax ?? 12,
          targetReps: st.targetReps || ex.targetReps || '8–12',
          targetWeight: st.targetWeight !== undefined && st.targetWeight !== null ? Number(st.targetWeight) : (ex.targetWeight !== undefined && ex.targetWeight !== null ? Number(ex.targetWeight) : null),
          targetRir: st.targetRir !== undefined && st.targetRir !== null ? Number(st.targetRir) : (ex.targetRir ?? 2),
          targetRpe: st.targetRpe !== undefined && st.targetRpe !== null ? Number(st.targetRpe) : (ex.targetRpe ?? 8.0),
          restSeconds: st.restSeconds || ex.restSeconds || 90,
          tempo: st.tempo || ex.tempo || '3-1-1-0',
          isCompleted: false,
        }));
      } else {
        setsList = Array.from({ length: numSets }, (_, sIdx) => ({
          id: `set_${ex.id || 'ex'}_${sIdx + 1}`,
          setNumber: sIdx + 1,
          setType: ex.setType || 'Working',
          targetRepsMin: 8,
          targetRepsMax: 12,
          targetReps: ex.targetReps || '8–12',
          targetWeight: ex.targetWeight !== undefined && ex.targetWeight !== null ? Number(ex.targetWeight) : null,
          targetRir: ex.targetRir !== undefined && ex.targetRir !== null ? Number(ex.targetRir) : 2,
          targetRpe: ex.targetRpe !== undefined && ex.targetRpe !== null ? Number(ex.targetRpe) : 8.0,
          restSeconds: ex.restSeconds || 90,
          tempo: ex.tempo || '3-1-1-0',
          isCompleted: false,
        }));
      }

      return {
        id: ex.id,
        sessionId: ex.sessionId,
        exerciseId: ex.exerciseId,
        exerciseName: ex.exerciseName,
        category: ex.category || 'General',
        orderIndex: ex.orderIndex,
        supersetTag: ex.supersetTag,
        numberOfSets: numSets,
        setCount: numSets,
        setsCount: numSets,
        totalSets: numSets,
        targetSets: numSets,
        targetReps: ex.targetReps || '8–12',
        targetWeight: ex.targetWeight !== undefined && ex.targetWeight !== null ? Number(ex.targetWeight) : null,
        restSeconds: ex.restSeconds || 90,
        targetRir: ex.targetRir ?? 2,
        targetRpe: ex.targetRpe ?? 8.0,
        tempo: ex.tempo || '3-1-1-0',
        setType: ex.setType || 'Working',
        exerciseNotes: ex.exerciseNotes,
        adminInstruction: ex.adminInstruction,
        sets: setsList,
      };
    }),
  };
}

function mapPrismaAssignmentToStored(a: any): StoredWorkoutAssignment {
  return {
    id: a.id,
    sessionId: a.sessionId,
    clientId: a.clientId,
    isRecommended: a.isRecommended,
    assignedById: a.assignedById,
    assignedAt: toISO(a.assignedAt, new Date().toISOString()),
    scheduledDate: a.scheduledDate || toISTDateString(a.assignedAt),
    active: a.active,
    status: a.status || (a.isLocked ? 'LOCKED' : a.completedAt ? 'COMPLETED' : 'ASSIGNED'),
    completedAt: toISONullable(a.completedAt),
    isLocked: a.isLocked ?? false,
    lockedAt: toISONullable(a.lockedAt),
    unlockedAt: toISONullable(a.unlockedAt),
    unlockedById: a.unlockedById ?? null,
    unlockReason: a.unlockReason ?? null,
  };
}

function mapPrismaRecordToStored(r: any): StoredWorkoutRecord {
  return {
    id: r.id,
    clientId: r.clientId,
    sessionId: r.sessionId,
    assignmentId: r.assignmentId ?? null,
    sessionTitle: r.sessionTitle,
    workoutType: r.workoutType,
    startedAt: toISO(r.startedAt, new Date().toISOString()),
    completedAt: toISONullable(r.completedAt),
    durationSeconds: r.durationSeconds,
    totalVolume: r.totalVolume,
    completedSetsCount: r.completedSetsCount,
    skippedSetsCount: r.skippedSetsCount,
    averageRpe: r.averageRpe,
    averageRir: r.averageRir,
    isCompleted: r.isCompleted,
    isLocked: r.isLocked ?? (r.isCompleted ? true : false),
    lockedAt: toISONullable(r.lockedAt),
    unlockedAt: toISONullable(r.unlockedAt),
    unlockedById: r.unlockedById ?? null,
    unlockReason: r.unlockReason ?? null,
    scheduledDate: r.scheduledDate || toISTDateString(r.startedAt),
    personalRecords: r.personalRecordsJson ? JSON.parse(r.personalRecordsJson) : [],
    notes: r.notes,
    createdAt: toISO(r.createdAt, new Date().toISOString()),
    updatedAt: toISO(r.updatedAt, new Date().toISOString()),
    exerciseRecords: (r.exerciseRecords || []).map((er: any) => ({
      exerciseId: er.exerciseId,
      exerciseName: er.exerciseName,
      orderIndex: er.orderIndex,
      supersetTag: er.supersetTag,
      isSkipped: er.isSkipped,
      skipReason: er.skipReason,
      clientNote: er.clientNote,
      adminNote: er.adminNote,
      sets: (er.setRecords || []).map((sr: any) => ({
        setNumber: sr.setNumber,
        setType: sr.setType,
        targetReps: sr.targetReps,
        targetWeight: sr.targetWeight,
        actualWeight: sr.actualWeight,
        actualReps: sr.actualReps,
        actualRir: sr.actualRir,
        actualRpe: sr.actualRpe,
        tempo: sr.tempo,
        isCompleted: sr.isCompleted,
        completedAt: sr.completedAt ? sr.completedAt.toISOString() : null,
        notes: sr.notes,
      })),
    })),
  };
}

export class WorkoutRepository {
  private sessions: Map<string, StoredWorkoutSession> = new Map();
  private assignments: Map<string, StoredWorkoutAssignment> = new Map();
  private records: Map<string, StoredWorkoutRecord> = new Map();
  private activeSetRecords: Map<string, {
    sessionId: string;
    exerciseId: string;
    setNumber: number;
    isCompleted: boolean;
    actualWeight?: number | null;
    actualReps?: number | null;
    actualRir?: number | null;
    actualRpe?: number | null;
    completedAt?: string | null;
  }> = new Map();
  private isInitialized = false;
  private activeSaveLocks: Map<string, Promise<StoredWorkoutRecord>> = new Map();
  private splitPlans: Map<string, StoredWorkoutSplitPlan> = new Map();
  private clientSplitMap: Map<string, string> = new Map();
  private clientSessionOverrides: Map<string, ClientSessionOverrideData> = new Map();

  // Real registered clients are queried dynamically from PostgreSQL via workoutService.getClientsList()
  public clientsList: { id: string; name: string; email: string; status: string }[] = [];

  constructor() {
    // Production clean: No demo workout sessions seeded
  }

  private seedDefaultSessions() {
    return;
    // In-memory baseline for immediate synchronous availability
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
          restSeconds: 30,
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
          restSeconds: 90,
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

    const pushAAssignment: StoredWorkoutAssignment = {
      id: 'assign_push_a_all',
      sessionId: pushAId,
      clientId: null,
      isRecommended: false,
      assignedById: 'admin_alex_stone',
      assignedAt: new Date().toISOString(),
      active: true,
    };
    this.assignments.set(pushAAssignment.id, pushAAssignment);

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

    // Normalize seeded exercises so setCount and sets array are fully populated
    for (const [sId, s] of this.sessions.entries()) {
      s.exercises = s.exercises.map((ex) => {
        const numSets = Number(ex.numberOfSets) || 3;
        const setsList = Array.isArray(ex.sets) && ex.sets.length > 0
          ? ex.sets
          : Array.from({ length: numSets }, (_, sIdx) => ({
              id: `set_${ex.id || 'ex'}_${sIdx + 1}`,
              setNumber: sIdx + 1,
              setType: ex.setType || 'Working',
              targetWeight: ex.targetWeight ?? null,
              targetReps: ex.targetReps || '8–12',
              targetRir: ex.targetRir ?? 2,
              targetRpe: ex.targetRpe ?? 8.0,
              tempo: ex.tempo || '3-1-1-0',
              restSeconds: ex.restSeconds || 90,
            }));
        return {
          ...ex,
          numberOfSets: numSets,
          setCount: numSets,
          setsCount: numSets,
          totalSets: numSets,
          targetSets: numSets,
          sets: setsList,
        };
      });
      this.sessions.set(sId, s);
    }

    // Initial past records for performance history
    const pastRecordId = 'rec_seed_push_a_01';
    const pastRecord: StoredWorkoutRecord = {
      id: pastRecordId,
      clientId: 'client_john_doe',
      sessionId: pushAId,
      sessionTitle: 'Push A',
      workoutType: 'Strength',
      startedAt: new Date(Date.now() - 3 * 86400000 - 3600000).toISOString(),
      completedAt: new Date(Date.now() - 3 * 86400000).toISOString(),
      durationSeconds: 3600,
      totalVolume: 5600.0,
      completedSetsCount: 12,
      skippedSetsCount: 0,
      averageRpe: 8.2,
      averageRir: 1.8,
      isCompleted: true,
      personalRecords: [
        {
          type: 'weight',
          exerciseName: 'Incline Smith Machine Press',
          value: '80 kg',
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
          sets: [
            {
              setNumber: 1,
              setType: 'Working',
              targetReps: '8–10',
              targetWeight: 80.0,
              actualWeight: 80.0,
              actualReps: 8,
              actualRpe: 8.0,
              actualRir: 2,
              tempo: '3-1-1-0',
              isCompleted: true,
              completedAt: new Date(Date.now() - 3 * 86400000).toISOString(),
            },
            {
              setNumber: 2,
              setType: 'Working',
              targetReps: '8–10',
              targetWeight: 80.0,
              actualWeight: 80.0,
              actualReps: 8,
              actualRpe: 8.5,
              actualRir: 2,
              tempo: '3-1-1-0',
              isCompleted: true,
              completedAt: new Date(Date.now() - 3 * 86400000).toISOString(),
            },
          ],
        },
      ],
    };
    this.records.set(pastRecordId, pastRecord);
    this.records.set('rec_seed_push_a_marcus', {
      ...pastRecord,
      id: 'rec_seed_push_a_marcus',
      clientId: 'client_marcus_vance',
    });
  }

  public async ensureDatabaseSeeded(): Promise<void> {
    return;
  }

  private async resolveUserId(idOrClientId: string): Promise<string> {
    const clean = idOrClientId.trim();
    try {
      const user = await prisma.user.findFirst({
        where: {
          OR: [
            { id: clean },
            { clientProfile: { clientId: clean.toUpperCase() } },
            { clientProfile: { id: clean } },
            { email: clean.toLowerCase() },
          ],
        },
        select: { id: true },
      });
      if (user) return user.id;
    } catch (_) {}
    return clean;
  }

  // --- Admin Session Operations ---
  async getAllSessions(): Promise<StoredWorkoutSession[]> {
    try {
      const sessions = await prisma.workoutSession.findMany({
        include: {
          exercises: {
            include: { setTemplates: true },
            orderBy: { orderIndex: 'asc' },
          },
        },
        orderBy: { createdAt: 'desc' },
      });
      return sessions.map(mapPrismaSessionToStored);
    } catch (e) {
      console.warn('[WorkoutRepository] Failed to fetch sessions from DB, using cache:', e);
      return Array.from(this.sessions.values());
    }
  }

  private resolveSessionCandidateIds(id: string): string[] {
    const aliasMap: Record<string, string> = {
      'ws_push_day_01': 'ws_push_a_01',
      'ws_pull_day_02': 'ws_pull_a_02',
      'ws_legs_day_03': 'ws_legs_a_03',
      'ws_push_a_01': 'ws_push_day_01',
      'ws_pull_a_02': 'ws_pull_day_02',
      'ws_legs_a_03': 'ws_legs_day_03',
    };
    const candidates = [id];
    if (aliasMap[id] && !candidates.includes(aliasMap[id])) {
      candidates.push(aliasMap[id]);
    }
    return candidates;
  }

  async getSessionById(id: string): Promise<StoredWorkoutSession | null> {
    const candidateIds = this.resolveSessionCandidateIds(id);
    try {
      const session = await prisma.workoutSession.findFirst({
        where: { id: { in: candidateIds } },
        include: {
          exercises: {
            include: { setTemplates: true },
            orderBy: { orderIndex: 'asc' },
          },
        },
      });
      if (session) {
        return mapPrismaSessionToStored(session);
      }
    } catch (_) {}
    for (const cid of candidateIds) {
      const mem = this.sessions.get(cid);
      if (mem) return mem;
    }
    return null;
  }

  async createSession(data: any): Promise<StoredWorkoutSession> {
    const id = data.id || `ws_${Date.now()}`;
    const now = new Date().toISOString();

    const mappedExercises: StoredSessionExercise[] = (data.exercises || []).map((ex: any, idx: number) => {
      const numSets = Number(ex.numberOfSets) || (Array.isArray(ex.sets) && ex.sets.length > 0 ? ex.sets.length : (Number(ex.setCount) || 3));
      const exId = ex.id || `ex_${id}_${idx + 1}`;
      const setsList = Array.isArray(ex.sets) && ex.sets.length > 0
        ? ex.sets
        : Array.from({ length: numSets }, (_, sIdx) => ({
            id: `set_${exId}_${sIdx + 1}`,
            setNumber: sIdx + 1,
            setType: ex.setType || 'Working',
            targetWeight: ex.targetWeight ? Number(ex.targetWeight) : null,
            targetReps: ex.targetReps || '8–12',
            targetRir: ex.targetRir ?? 2,
            targetRpe: ex.targetRpe ?? 8.0,
            tempo: ex.tempo || '3-1-1-0',
            restSeconds: Number(ex.restSeconds) || 90,
          }));

      return {
        ...ex,
        id: exId,
        sessionId: id,
        orderIndex: ex.orderIndex ?? idx,
        numberOfSets: numSets,
        setCount: numSets,
        setsCount: numSets,
        totalSets: numSets,
        targetSets: numSets,
        sets: setsList,
      };
    });

    // In-memory update
    const session: StoredWorkoutSession = {
      ...data,
      id,
      createdAt: now,
      updatedAt: now,
      exercises: mappedExercises,
    };
    this.sessions.set(id, session);

    // Database persistence
    try {
      const created = await prisma.workoutSession.create({
        data: {
          id,
          title: data.title,
          workoutType: data.workoutType || 'Strength',
          targetMuscleGroup: data.targetMuscleGroup || 'Full Body',
          difficulty: data.difficulty || 'Intermediate',
          estimatedDurationMinutes: Number(data.estimatedDurationMinutes) || 45,
          description: data.description || null,
          isActive: data.isActive !== false,
          startDate: data.startDate ? new Date(data.startDate) : new Date(),
          endDate: data.endDate ? new Date(data.endDate) : null,
          recurringSchedule: data.recurringSchedule || null,
          availabilityType: data.availabilityType || 'ALL',
          createdById: data.createdById || null,
          exercises: {
            create: (data.exercises || []).map((ex: any, idx: number) => {
              const numSets = Number(ex.numberOfSets) || (Array.isArray(ex.sets) && ex.sets.length > 0 ? ex.sets.length : (Number(ex.setCount) || 3));
              return {
                exerciseId: ex.exerciseId,
                exerciseName: ex.exerciseName,
                category: ex.category || 'General',
                orderIndex: ex.orderIndex ?? idx,
                supersetTag: ex.supersetTag || null,
                numberOfSets: numSets,
                targetReps: ex.targetReps ? String(ex.targetReps) : '8–12',
                targetWeight: ex.targetWeight ? Number(ex.targetWeight) : null,
                restSeconds: Number(ex.restSeconds) || 90,
                targetRir: ex.targetRir !== undefined ? Number(ex.targetRir) : 2,
                targetRpe: ex.targetRpe !== undefined ? Number(ex.targetRpe) : 8.0,
                tempo: ex.tempo || '3-1-1-0',
                setType: ex.setType || 'Working',
                exerciseNotes: ex.exerciseNotes || null,
                adminInstruction: ex.adminInstruction || null,
                setTemplates: {
                  create: Array.from({ length: numSets }, (_, setIdx) => ({
                    setNumber: setIdx + 1,
                    setType: ex.setType === 'Warm-up' ? 'WARMUP' : 'WORKING',
                    targetWeight: ex.targetWeight ? Number(ex.targetWeight) : null,
                    targetRepsMin: 8,
                    targetRepsMax: 12,
                    targetRir: ex.targetRir !== undefined ? Number(ex.targetRir) : 2,
                    targetRpe: ex.targetRpe !== undefined ? Number(ex.targetRpe) : 8.0,
                    tempo: ex.tempo || '3-1-1-0',
                  })),
                },
              };
            }),
          },
        },
        include: {
          exercises: {
            include: { setTemplates: true },
            orderBy: { orderIndex: 'asc' },
          },
        },
      });
      return mapPrismaSessionToStored(created);
    } catch (e: any) {
      console.warn('[WorkoutRepository] Failed to persist workout session to DB, using cache:', e?.message);
      return session;
    }
  }

  async updateSession(id: string, data: Partial<StoredWorkoutSession>): Promise<StoredWorkoutSession | null> {
    const existing = this.sessions.get(id);
    let mappedExercises: StoredSessionExercise[] | undefined;
    if (data.exercises && Array.isArray(data.exercises)) {
      mappedExercises = data.exercises.map((ex: any, idx: number) => {
        const numSets = Number(ex.numberOfSets) || (Array.isArray(ex.sets) && ex.sets.length > 0 ? ex.sets.length : (Number(ex.setCount) || 3));
        const exId = ex.id || `ex_${id}_${idx + 1}`;
        const setsList = Array.isArray(ex.sets) && ex.sets.length > 0
          ? ex.sets
          : Array.from({ length: numSets }, (_, sIdx) => ({
              id: `set_${exId}_${sIdx + 1}`,
              setNumber: sIdx + 1,
              setType: ex.setType || 'Working',
              targetWeight: ex.targetWeight ? Number(ex.targetWeight) : null,
              targetReps: ex.targetReps || '8–12',
              targetRir: ex.targetRir ?? 2,
              targetRpe: ex.targetRpe ?? 8.0,
              tempo: ex.tempo || '3-1-1-0',
              restSeconds: Number(ex.restSeconds) || 90,
            }));

        return {
          ...ex,
          id: exId,
          sessionId: id,
          exerciseName: ex.exerciseName || ex.name || `Exercise ${idx + 1}`,
          exerciseId: ex.exerciseId || `ex_${id}_${idx + 1}`,
          orderIndex: ex.orderIndex ?? idx,
          numberOfSets: numSets,
          setCount: numSets,
          setsCount: numSets,
          totalSets: numSets,
          targetSets: numSets,
          sets: setsList,
        };
      });
    }

    if (existing) {
      const updated: StoredWorkoutSession = {
        ...existing,
        ...data,
        exercises: mappedExercises || existing.exercises,
        updatedAt: new Date().toISOString(),
      };
      this.sessions.set(id, updated);
    }

    try {
      const updateData: any = {};
      if (data.title !== undefined) updateData.title = data.title;
      if (data.workoutType !== undefined) updateData.workoutType = data.workoutType;
      if (data.targetMuscleGroup !== undefined) updateData.targetMuscleGroup = data.targetMuscleGroup;
      if (data.difficulty !== undefined) updateData.difficulty = data.difficulty;
      if (data.estimatedDurationMinutes !== undefined) updateData.estimatedDurationMinutes = data.estimatedDurationMinutes;
      if (data.description !== undefined) updateData.description = data.description;
      if (data.isActive !== undefined) updateData.isActive = data.isActive;
      if (data.recurringSchedule !== undefined) updateData.recurringSchedule = data.recurringSchedule;
      if (data.availabilityType !== undefined) updateData.availabilityType = data.availabilityType;

      if (data.exercises && Array.isArray(data.exercises)) {
        await prisma.workoutSessionExercise.deleteMany({ where: { sessionId: id } });
        for (const [idx, ex] of data.exercises.entries()) {
          const numSets = Number(ex.numberOfSets) || (Array.isArray(ex.sets) && ex.sets.length > 0 ? ex.sets.length : (Number(ex.setCount) || 3));
          await prisma.workoutSessionExercise.create({
            data: {
              sessionId: id,
              exerciseId: ex.exerciseId || `ex_${idx + 1}`,
              exerciseName: ex.exerciseName || (ex as any).name || 'Exercise',
              category: ex.category || 'General',
              orderIndex: ex.orderIndex ?? idx,
              supersetTag: ex.supersetTag || null,
              numberOfSets: numSets,
              targetReps: ex.targetReps ? String(ex.targetReps) : '8–12',
              targetWeight: ex.targetWeight ? Number(ex.targetWeight) : null,
              restSeconds: Number(ex.restSeconds) || 90,
              targetRir: ex.targetRir !== undefined ? Number(ex.targetRir) : 2,
              targetRpe: ex.targetRpe !== undefined ? Number(ex.targetRpe) : 8.0,
              tempo: ex.tempo || '3-1-1-0',
              setType: ex.setType || 'Working',
              exerciseNotes: ex.exerciseNotes || null,
              adminInstruction: ex.adminInstruction || null,
              setTemplates: {
                create: Array.from({ length: numSets }, (_, setIdx) => {
                  let templateSetType = 'WORKING';
                  const sType = String(ex.setType || '').toUpperCase();
                  if (sType.includes('WARM')) templateSetType = 'WARMUP';
                  else if (sType.includes('DROP')) templateSetType = 'DROP_SET';
                  else if (sType.includes('FAIL')) templateSetType = 'FAILURE';
                  else if (sType.includes('REST') || sType.includes('PAUSE')) templateSetType = 'REST_PAUSE';
                  return {
                    setNumber: setIdx + 1,
                    setType: templateSetType,
                    targetWeight: ex.targetWeight ? Number(ex.targetWeight) : null,
                    targetRepsMin: 8,
                    targetRepsMax: 12,
                    targetRir: ex.targetRir !== undefined ? Number(ex.targetRir) : 2,
                    targetRpe: ex.targetRpe !== undefined ? Number(ex.targetRpe) : 8.0,
                    tempo: ex.tempo || '3-1-1-0',
                  };
                }),
              },
            },
          });
        }
      }

      const updated = await prisma.workoutSession.update({
        where: { id },
        data: updateData,
        include: {
          exercises: {
            include: { setTemplates: true },
            orderBy: { orderIndex: 'asc' },
          },
        },
      });
      return mapPrismaSessionToStored(updated);
    } catch (e: any) {
      console.warn('[WorkoutRepository] DB session update failed, using cache:', e?.message);
    }
    return this.sessions.get(id) ?? null;
  }

  async duplicateSession(id: string): Promise<StoredWorkoutSession | null> {
    const existing = await this.getSessionById(id);
    if (!existing) return null;

    const newId = `ws_${Date.now()}_copy`;
    const copyData = {
      ...existing,
      id: newId,
      title: `${existing.title} (Copy)`,
      exercises: existing.exercises.map((ex, idx) => ({
        ...ex,
        id: `ex_${newId}_${idx + 1}`,
        sessionId: newId,
      })),
    };

    return this.createSession(copyData);
  }

  async toggleActive(id: string): Promise<StoredWorkoutSession | null> {
    const existing = await this.getSessionById(id);
    if (!existing) return null;
    return this.updateSession(id, { isActive: !existing.isActive });
  }

  async deleteSession(id: string): Promise<boolean> {
    const candidateIds = this.resolveSessionCandidateIds(id);
    let memoryDeleted = false;
    for (const cid of candidateIds) {
      if (this.sessions.delete(cid)) {
        memoryDeleted = true;
      }
      for (const [key, assign] of this.assignments.entries()) {
        if (assign.sessionId === cid) {
          this.assignments.delete(key);
        }
      }
    }

    try {
      const existingInDb = await prisma.workoutSession.findFirst({
        where: { id: { in: candidateIds } },
        select: { id: true },
      });

      if (existingInDb) {
        const foundId = existingInDb.id;
        // Clean up related assignments and exercises first to prevent foreign key errors
        await prisma.workoutAssignment.deleteMany({ where: { sessionId: foundId } });
        await prisma.workoutSessionExercise.deleteMany({ where: { sessionId: foundId } });
        await prisma.workoutSession.deleteMany({ where: { id: foundId } });
        this.sessions.delete(foundId);
        return true;
      }

      return memoryDeleted;
    } catch (err) {
      console.warn(`[WorkoutRepository] Error deleting session ${id}:`, err);
      return memoryDeleted;
    }
  }

  // --- Assignment Operations ---
  async getAssignmentsForSession(sessionId: string): Promise<StoredWorkoutAssignment[]> {
    try {
      const assignments = await prisma.workoutAssignment.findMany({
        where: { sessionId, active: true },
      });
      if (assignments.length > 0) {
        return assignments.map(mapPrismaAssignmentToStored);
      }
    } catch (_) {}
    return Array.from(this.assignments.values()).filter((a) => a.sessionId === sessionId && a.active);
  }

  async getAllAssignments(): Promise<StoredWorkoutAssignment[]> {
    try {
      const assignments = await prisma.workoutAssignment.findMany({
        where: { active: true },
      });
      if (assignments.length > 0) {
        return assignments.map(mapPrismaAssignmentToStored);
      }
    } catch (_) {}
    return Array.from(this.assignments.values()).filter((a) => a.active);
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
    const { sessionId, assignmentType, clientIds = [], individualClientId, isRecommended = false, scheduledDate: inputScheduledDate, assignedById } = params;
    const results: StoredWorkoutAssignment[] = [];
    const now = new Date().toISOString();
    const scheduledDate = inputScheduledDate || getTodayISTDateString();

    // 1. Resolve author user id
    let resolvedAdminId = assignedById;
    try {
      resolvedAdminId = await this.resolveUserId(assignedById);
    } catch (_) {}

    // 2. Resolve client target IDs
    let targetUserIds: Array<string | null> = [];
    if (assignmentType === 'ALL') {
      targetUserIds = [null];
    } else if (assignmentType === 'INDIVIDUAL' && individualClientId) {
      const uid = await this.resolveUserId(individualClientId);
      targetUserIds = [uid];
    } else if (assignmentType === 'SELECTED') {
      for (const cid of clientIds) {
        const uid = await this.resolveUserId(cid);
        targetUserIds.push(uid);
      }
    }

    // 3. Clear previous recommendations if this assignment is recommended
    if (isRecommended) {
      for (const targetId of targetUserIds) {
        try {
          await prisma.workoutAssignment.updateMany({
            where: { clientId: targetId, isRecommended: true },
            data: { isRecommended: false },
          });
        } catch (_) {}

        for (const a of this.assignments.values()) {
          if (a.clientId === targetId) {
            a.isRecommended = false;
          }
        }
      }
    }

    // 4. Persist to PostgreSQL via Prisma & update in-memory cache
    for (const targetId of targetUserIds) {
      const inMemoryKey = `assign_${sessionId}_${targetId || 'all'}_${scheduledDate}`;
      const memAssignment: StoredWorkoutAssignment = {
        id: inMemoryKey,
        sessionId,
        clientId: targetId,
        isRecommended,
        assignedById: resolvedAdminId,
        assignedAt: now,
        scheduledDate,
        active: true,
        status: 'ASSIGNED',
        isLocked: false,
      };
      this.assignments.set(inMemoryKey, memAssignment);

      try {
        const existing = await prisma.workoutAssignment.findFirst({
          where: {
            sessionId,
            clientId: targetId,
            OR: [
              { scheduledDate },
              { scheduledDate: null },
            ],
          },
        });

        let saved;
        if (existing) {
          saved = await prisma.workoutAssignment.update({
            where: { id: existing.id },
            data: {
              isRecommended,
              assignedById: resolvedAdminId,
              active: true,
              assignedAt: new Date(),
              scheduledDate,
              status: 'ASSIGNED',
              isLocked: false,
              completedAt: null,
              lockedAt: null,
            },
          });
        } else {
          saved = await prisma.workoutAssignment.create({
            data: {
              sessionId,
              clientId: targetId,
              isRecommended,
              assignedById: resolvedAdminId,
              active: true,
              scheduledDate,
              status: 'ASSIGNED',
              isLocked: false,
            },
          });
        }
        results.push(mapPrismaAssignmentToStored(saved));
      } catch (err: any) {
        console.warn('[WorkoutRepository] DB assignment fallback to memory:', err?.message);
        results.push(memAssignment);
      }
    }

    return results;
  }

  async unassign(assignmentId: string): Promise<boolean> {
    if (this.assignments.has(assignmentId)) {
      this.assignments.delete(assignmentId);
    }

    try {
      const res = await prisma.workoutAssignment.deleteMany({
        where: {
          OR: [
            { id: assignmentId },
            { sessionId: assignmentId },
          ],
        },
      });
      return res.count > 0;
    } catch (_) {
      return false;
    }
  }

  // --- Client Operations (Strictly Scoped by Date & Auth) ---
  async getClientAuthorizedSessions(clientId: string, simulatedDateOrDay?: string): Promise<{
    recommended: (StoredWorkoutSession & { isRecommended: boolean }) | null;
    available: (StoredWorkoutSession & { isRecommended: boolean })[];
  }> {
    const resolvedUserId = await this.resolveUserId(clientId);
    const todayIST = simulatedDateOrDay && simulatedDateOrDay.includes('-')
      ? simulatedDateOrDay
      : getTodayISTDateString();

    try {
      // 1. Query client-specific assignments
      const clientSpecificAssignments = await prisma.workoutAssignment.findMany({
        where: {
          clientId: resolvedUserId,
          active: true,
        },
        include: {
          session: {
            include: {
              exercises: {
                include: { setTemplates: true },
                orderBy: { orderIndex: 'asc' },
              },
            },
          },
        },
        orderBy: [
          { isRecommended: 'desc' },
          { assignedAt: 'desc' },
        ],
      });

      // 2. Query ALL (global) active assignments
      const allAssignments = await prisma.workoutAssignment.findMany({
        where: {
          clientId: null,
          active: true,
        },
        include: {
          session: {
            include: {
              exercises: {
                include: { setTemplates: true },
                orderBy: { orderIndex: 'asc' },
              },
            },
          },
        },
        orderBy: { assignedAt: 'desc' },
      });

      // Combine client-specific and global assignments (client-specific takes precedence)
      const clientSessionIds = new Set(clientSpecificAssignments.map((a) => a.sessionId));
      const combinedAssignments = [
        ...clientSpecificAssignments,
        ...allAssignments.filter((a) => !clientSessionIds.has(a.sessionId)),
      ].filter((a) => a.session && a.session.isActive);

      if (combinedAssignments.length > 0) {
        const available: (StoredWorkoutSession & { isRecommended: boolean; isLocked?: boolean; assignmentId?: string })[] = [];

        for (const a of combinedAssignments) {
          const candidateIds = this.resolveSessionCandidateIds(a.sessionId);

          // Check if this workout session has been completed & locked
          const lockedRecord = await prisma.workoutRecord.findFirst({
            where: {
              clientId: resolvedUserId,
              sessionId: { in: candidateIds },
              isCompleted: true,
            },
            orderBy: { completedAt: 'desc' },
          });

          const isLockedForToday = lockedRecord?.isLocked ?? (a.isLocked && !a.unlockedAt);
          const statusForToday = lockedRecord
            ? (lockedRecord.isCompleted ? 'COMPLETED' : 'IN_PROGRESS')
            : (a.status || 'ASSIGNED');

          available.push({
            ...mapPrismaSessionToStored(a.session),
            scheduledDate: a.scheduledDate || todayIST,
            assignmentId: a.id,
            isLocked: isLockedForToday,
            status: statusForToday,
            lockedAt: lockedRecord?.lockedAt ? lockedRecord.lockedAt.toISOString() : null,
            isRecommended: a.isRecommended,
          });
        }

        // Determine recommended session for today:
        // Scheduling rules (Section 4 & 5):
        // 1. Identify all scheduled days for this client in the current cycle / week.
        // 2. Progression check: If any prior scheduled workout day in the current cycle is incomplete,
        //    that prior incomplete workout remains the required/eligible session!
        //    Subsequent days remain locked with status 'PREVIOUS_SESSION_REQUIRED'.
        // 3. If all prior scheduled workouts are completed (or none exist):
        //    - If today has a scheduled session:
        //        - If completed & locked: recItem = today's session (isLocked = true, status = 'COMPLETED')
        //        - If not completed: recItem = today's session (isLocked = false, isRecommended = true)
        //    - If today has NO scheduled session (Rest Day):
        //        - recItem = null! (Do NOT pick available[0]!)
        const todayWeekday = simulatedDateOrDay && !simulatedDateOrDay.includes('-')
          ? parseWeekdaysFromScheduleString(simulatedDateOrDay)[0] ?? getTodayISTWeekday()
          : getTodayISTWeekday();

        const getScheduledWeekday = (item: typeof available[0]) => {
          const matchingAssignment = combinedAssignments.find((a) => a.session.id === item.id);
          if (!matchingAssignment) return null;
          const recurringDays = parseWeekdaysFromScheduleString(matchingAssignment.session.recurringSchedule);
          if (recurringDays.length > 0) return recurringDays[0];
          if (matchingAssignment.scheduledDate) return getWeekdayFromISTDateString(matchingAssignment.scheduledDate);
          return null;
        };

        const priorScheduledItems = available
          .map((item) => ({ item, weekday: getScheduledWeekday(item) }))
          .filter((x): x is { item: typeof available[0]; weekday: number } => x.weekday !== null && x.weekday < todayWeekday)
          .sort((a, b) => a.weekday - b.weekday);

        const priorIncomplete = priorScheduledItems.find((x) => !x.item.isLocked && x.item.status !== 'COMPLETED');

        let recItem: (typeof available)[0] | undefined;

        const todayItems = available.filter((item) => {
          const matchingAssignment = combinedAssignments.find((a) => a.session.id === item.id);
          if (!matchingAssignment) return false;
          if (simulatedDateOrDay && !simulatedDateOrDay.includes('-')) {
            return (matchingAssignment.session.recurringSchedule || '').toLowerCase().includes(simulatedDateOrDay.toLowerCase());
          }
          return isSessionScheduledForDate(matchingAssignment.session, matchingAssignment, todayIST);
        });

        if (todayItems.length === 0) {
          // REST DAY: No workout scheduled for today. Do not display another day's workout.
          recItem = undefined;
        } else if (priorIncomplete) {
          // A prior required workout is incomplete! That prior session remains the required/eligible session.
          recItem = priorIncomplete.item;

          // Lock any subsequent sessions to prevent premature unlocking
          for (const s of available) {
            const w = getScheduledWeekday(s);
            if (w !== null && w > priorIncomplete.weekday && !s.isLocked && s.status !== 'COMPLETED') {
              s.isLocked = true;
              s.status = 'PREVIOUS_SESSION_REQUIRED';
            }
          }
        } else {
          // All prior workouts completed (or Day 1): recommend today's scheduled workout
          recItem = todayItems.find((s) => s.isRecommended) || todayItems[0];
        }

        return this.applyActiveSetOverlays({
          recommended: recItem ? { ...recItem, isRecommended: true } : null,
          available,
        }, resolvedUserId);
      }
    } catch (e: any) {
      console.warn('[WorkoutRepository] Failed to query client sessions from DB, falling back to cache:', e?.message);
    }

    // In-memory fallback: active client-specific and global assignments
    const activeSessions = Array.from(this.sessions.values()).filter((s) => s.isActive);
    const clientSpecificAssignments = Array.from(this.assignments.values())
      .filter((a) => a.active && (a.clientId === resolvedUserId || a.clientId === clientId))
      .sort((a, b) => {
        if (a.isRecommended && !b.isRecommended) return -1;
        if (!a.isRecommended && b.isRecommended) return 1;
        return b.assignedAt.localeCompare(a.assignedAt);
      });

    const globalAssignments = Array.from(this.assignments.values())
      .filter((a) => a.active && a.clientId === null);

    const clientSessionIds = new Set(clientSpecificAssignments.map((a) => a.sessionId));
    const combinedMemAssignments = [
      ...clientSpecificAssignments,
      ...globalAssignments.filter((a) => !clientSessionIds.has(a.sessionId)),
    ];

    if (combinedMemAssignments.length > 0) {
      const authorizedSessionIds = new Set(combinedMemAssignments.map((a) => a.sessionId));
      const authorizedSessions = activeSessions
        .filter((s) => authorizedSessionIds.has(s.id))
        .map((s) => {
          const assign = combinedMemAssignments.find((a) => a.sessionId === s.id);
          const candidateIds = this.resolveSessionCandidateIds(s.id);
          const memLockedRecord = Array.from(this.records.values()).find(
            (r) => candidateIds.includes(r.sessionId || '') &&
                   (r.clientId === resolvedUserId || r.clientId === clientId) &&
                   r.isCompleted &&
                   r.isLocked
          );

          const isLockedForToday = memLockedRecord?.isLocked ?? (assign?.isLocked && !assign?.unlockedAt);
          const statusForToday = memLockedRecord ? 'COMPLETED' : (assign?.status || 'ASSIGNED');

          return {
            ...s,
            scheduledDate: assign?.scheduledDate || todayIST,
            assignmentId: assign?.id,
            isLocked: isLockedForToday ?? false,
            status: statusForToday,
            isRecommended: assign?.isRecommended ?? false,
          };
        });

      if (authorizedSessions.length > 0) {
        const todayWeekday = simulatedDateOrDay && !simulatedDateOrDay.includes('-')
          ? parseWeekdaysFromScheduleString(simulatedDateOrDay)[0] ?? getTodayISTWeekday()
          : getTodayISTWeekday();
        const getMemScheduledWeekday = (item: typeof authorizedSessions[0]) => {
          const assign = combinedMemAssignments.find((a) => a.sessionId === item.id);
          if (!assign) return null;
          const recurringDays = parseWeekdaysFromScheduleString(item.recurringSchedule);
          if (recurringDays.length > 0) return recurringDays[0];
          if (assign.scheduledDate) return getWeekdayFromISTDateString(assign.scheduledDate);
          return null;
        };

        const priorMemScheduled = authorizedSessions
          .map((item) => ({ item, weekday: getMemScheduledWeekday(item) }))
          .filter((x): x is { item: typeof authorizedSessions[0]; weekday: number } => x.weekday !== null && x.weekday < todayWeekday)
          .sort((a, b) => a.weekday - b.weekday);

        const priorMemIncomplete = priorMemScheduled.find((x) => !x.item.isLocked && x.item.status !== 'COMPLETED');

        let recItem: (typeof authorizedSessions)[0] | undefined;

        const todayMemItems = authorizedSessions.filter((item) => {
          const assign = combinedMemAssignments.find((a) => a.sessionId === item.id);
          if (!assign) return false;
          if (simulatedDateOrDay && !simulatedDateOrDay.includes('-')) {
            return (item.recurringSchedule || '').toLowerCase().includes(simulatedDateOrDay.toLowerCase());
          }
          return isSessionScheduledForDate(item, assign, todayIST);
        });

        if (todayMemItems.length === 0) {
          // REST DAY: No workout scheduled for today. Do not display another day's workout.
          recItem = undefined;
        } else if (priorMemIncomplete) {
          recItem = priorMemIncomplete.item;
          for (const s of authorizedSessions) {
            const w = getMemScheduledWeekday(s);
            if (w !== null && w > priorMemIncomplete.weekday && !s.isLocked && s.status !== 'COMPLETED') {
              s.isLocked = true;
              s.status = 'PREVIOUS_SESSION_REQUIRED';
            }
          }
        } else {
          recItem = todayMemItems.find((s) => s.isRecommended) || todayMemItems[0];
        }

        return this.applyActiveSetOverlays({
          recommended: recItem ? { ...recItem, isRecommended: true } : null,
          available: authorizedSessions,
        }, resolvedUserId);
      }
    }

    return {
      recommended: null,
      available: [],
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
    const resolvedUserId = await this.resolveUserId(clientId);

    try {
      const lastExercise = await prisma.workoutExerciseRecord.findFirst({
        where: {
          exerciseId,
          isSkipped: false,
          record: {
            clientId: resolvedUserId,
            isCompleted: true,
          },
        },
        orderBy: {
          record: {
            startedAt: 'desc',
          },
        },
        include: {
          record: true,
          setRecords: {
            where: { isCompleted: true },
            orderBy: { setNumber: 'asc' },
          },
        },
      });

      if (lastExercise && lastExercise.setRecords.length > 0) {
        const firstSet = lastExercise.setRecords[0];
        return {
          lastWeight: firstSet.actualWeight ?? undefined,
          lastReps: firstSet.actualReps ?? undefined,
          lastRir: firstSet.actualRir ?? undefined,
          lastRpe: firstSet.actualRpe ?? undefined,
          sets: lastExercise.setRecords.map((s) => ({
            weight: s.actualWeight || 0,
            reps: s.actualReps || 0,
            rpe: s.actualRpe ?? undefined,
            rir: s.actualRir ?? undefined,
          })),
          completedAt: lastExercise.record.completedAt
            ? lastExercise.record.completedAt.toISOString()
            : lastExercise.record.startedAt.toISOString(),
        };
      }
    } catch (_) {}

    // In-memory fallback
    const clientRecords = Array.from(this.records.values())
      .filter((r) => (r.clientId === clientId || r.clientId === resolvedUserId) && r.isCompleted)
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
    const resolvedUserId = await this.resolveUserId(clientId);
    const scheduledDate = data.scheduledDate || getTodayISTDateString();
    const candidateIds = data.sessionId ? this.resolveSessionCandidateIds(data.sessionId) : [];
    const lockKey = `${resolvedUserId}_${data.sessionId || 'session'}_${scheduledDate}`;

    // Concurrency protection: prevent duplicate concurrent saves / double taps
    if (this.activeSaveLocks.has(lockKey)) {
      return await this.activeSaveLocks.get(lockKey)!;
    }

    const saveExecution = (async () => {
      // 1. Check if session is already completed & locked for this specific scheduledDate
      if (candidateIds.length > 0) {
        try {
          const existingLocked = await prisma.workoutRecord.findFirst({
            where: {
              clientId: resolvedUserId,
              sessionId: { in: candidateIds },
              scheduledDate,
              isCompleted: true,
            },
          });
          if (existingLocked && existingLocked.isLocked) {
            throw new Error(`SESSION_LOCKED: Workout session has already been completed and locked for ${scheduledDate}.`);
          }
        } catch (err: any) {
          if (err.message && err.message.includes('SESSION_LOCKED')) {
            throw err;
          }
        }

        const memExistingLocked = Array.from(this.records.values()).find(
          (r) => candidateIds.includes(r.sessionId || '') &&
                 (r.clientId === resolvedUserId || r.clientId === clientId) &&
                 r.scheduledDate === scheduledDate &&
                 r.isCompleted &&
                 r.isLocked
        );
        if (memExistingLocked) {
          throw new Error(`SESSION_LOCKED: Workout session has already been completed and locked for ${scheduledDate}.`);
        }
      }

      const id = `rec_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
      const now = new Date().toISOString();

      const memRecord: StoredWorkoutRecord = {
        ...data,
        id,
        clientId: resolvedUserId,
        isCompleted: data.isCompleted ?? true,
        isLocked: true,
        lockedAt: now,
        scheduledDate,
        createdAt: now,
        updatedAt: now,
      };
      this.records.set(id, memRecord);

      if (data.sessionId && (data.isCompleted ?? true)) {
        for (const assign of this.assignments.values()) {
          if ((assign.clientId === resolvedUserId || assign.clientId === clientId) && candidateIds.includes(assign.sessionId)) {
            assign.status = 'COMPLETED';
            assign.completedAt = now;
            assign.isLocked = true;
            assign.lockedAt = now;
          }
        }
      }

      try {
        const created = await prisma.workoutRecord.create({
          data: {
            clientId: resolvedUserId,
            sessionId: data.sessionId || null,
            assignmentId: data.assignmentId || null,
            sessionTitle: data.sessionTitle,
            workoutType: data.workoutType,
            startedAt: data.startedAt ? new Date(data.startedAt) : new Date(),
            completedAt: data.completedAt ? new Date(data.completedAt) : new Date(),
            durationSeconds: data.durationSeconds || 0,
            totalVolume: data.totalVolume || 0,
            completedSetsCount: data.completedSetsCount || 0,
            skippedSetsCount: data.skippedSetsCount || 0,
            averageRpe: data.averageRpe,
            averageRir: data.averageRir,
            isCompleted: data.isCompleted ?? true,
            isLocked: true,
            lockedAt: new Date(),
            scheduledDate,
            personalRecordsJson: data.personalRecords ? JSON.stringify(data.personalRecords) : null,
            notes: data.notes || null,
            exerciseRecords: {
              create: (data.exerciseRecords || []).map((er: any, idx: number) => ({
                exerciseId: er.exerciseId,
                exerciseName: er.exerciseName,
                orderIndex: er.orderIndex ?? idx,
                supersetTag: er.supersetTag || null,
                isSkipped: er.isSkipped || false,
                skipReason: er.skipReason || null,
                clientNote: er.clientNote || null,
                adminNote: er.adminNote || null,
                setRecords: {
                  create: (er.sets || []).map((sr: any) => ({
                    setNumber: sr.setNumber,
                    setType: sr.setType || 'WORKING',
                    targetReps: sr.targetReps || null,
                    targetWeight: sr.targetWeight || null,
                    actualWeight: sr.actualWeight || null,
                    actualReps: sr.actualReps || null,
                    actualRir: sr.actualRir || null,
                    actualRpe: sr.actualRpe || null,
                    tempo: sr.tempo || null,
                    isCompleted: sr.isCompleted ?? true,
                    completedAt: sr.completedAt ? new Date(sr.completedAt) : null,
                    notes: sr.notes || null,
                  })),
                },
              })),
            },
          },
          include: {
            exerciseRecords: {
              include: { setRecords: true },
              orderBy: { orderIndex: 'asc' },
            },
          },
        });

        if (data.sessionId) {
          // Delete any incomplete in-progress records for this session
          try {
            await prisma.workoutRecord.deleteMany({
              where: {
                clientId: resolvedUserId,
                sessionId: { in: candidateIds },
                isCompleted: false,
              },
            });
          } catch (_) {}

          try {
            await prisma.workoutAssignment.updateMany({
              where: {
                clientId: resolvedUserId,
                sessionId: { in: candidateIds },
              },
              data: {
                status: 'COMPLETED',
                completedAt: new Date(),
                isLocked: true,
                lockedAt: new Date(),
              },
            });
          } catch (_) {}

          // Clear in-memory active set records
          for (const sid of candidateIds) {
            const prefix = `${resolvedUserId}_${sid}_`;
            for (const k of Array.from(this.activeSetRecords.keys())) {
              if (k.startsWith(prefix)) {
                this.activeSetRecords.delete(k);
              }
            }
          }
        }
        return mapPrismaRecordToStored(created);
      } catch (e: any) {
        if (e.message && e.message.includes('SESSION_LOCKED')) {
          throw e;
        }
        if (data.sessionId) {
          for (const sid of candidateIds) {
            const prefix = `${resolvedUserId}_${sid}_`;
            for (const k of Array.from(this.activeSetRecords.keys())) {
              if (k.startsWith(prefix)) {
                this.activeSetRecords.delete(k);
              }
            }
          }
        }
        return memRecord;
      }
    })();

    this.activeSaveLocks.set(lockKey, saveExecution);
    try {
      return await saveExecution;
    } finally {
      this.activeSaveLocks.delete(lockKey);
    }
  }

  async getClientWorkoutHistory(clientId: string, limit: number = 50): Promise<StoredWorkoutRecord[]> {
    const resolvedUserId = await this.resolveUserId(clientId);

    try {
      const records = await prisma.workoutRecord.findMany({
        where: { clientId: resolvedUserId },
        orderBy: { startedAt: 'desc' },
        take: limit,
        include: {
          exerciseRecords: {
            include: { setRecords: true },
            orderBy: { orderIndex: 'asc' },
          },
        },
      });
      if (records.length > 0) {
        return records.map(mapPrismaRecordToStored);
      }
    } catch (_) {}

    return Array.from(this.records.values())
      .filter((r) => r.clientId === clientId || r.clientId === resolvedUserId)
      .sort((a, b) => b.startedAt.localeCompare(a.startedAt))
      .slice(0, limit);
  }

  async getWorkoutRecordById(id: string): Promise<StoredWorkoutRecord | null> {
    try {
      const record = await prisma.workoutRecord.findUnique({
        where: { id },
        include: {
          exerciseRecords: {
            include: { setRecords: true },
            orderBy: { orderIndex: 'asc' },
          },
        },
      });
      if (record) {
        return mapPrismaRecordToStored(record);
      }
    } catch (_) {}
    return this.records.get(id) ?? null;
  }

  async saveSetCompletion(
    clientId: string,
    sessionId: string,
    payload: {
      exerciseId: string;
      setNumber: number;
      isCompleted: boolean;
      actualWeight?: number | null;
      actualReps?: number | null;
      actualRir?: number | null;
      actualRpe?: number | null;
      tempo?: string | null;
      scheduledDate?: string | null;
    }
  ): Promise<{
    sessionId: string;
    exerciseId: string;
    setNumber: number;
    isCompleted: boolean;
    completedAt?: string | null;
    actualWeight?: number | null;
    actualReps?: number | null;
    isExerciseCompleted: boolean;
    completedSetsCount: number;
    totalSetsCount: number;
  }> {
    const resolvedUserId = await this.resolveUserId(clientId);
    const candidateIds = this.resolveSessionCandidateIds(sessionId);
    const resolvedSessionId = candidateIds[0] || sessionId;
    const todayIST = getTodayISTDateString();
    const targetDate = (payload as any).scheduledDate || todayIST;

    // Check if session for targetDate (or historical completed occurrence) is locked in database
    try {
      let lockedRecord = await prisma.workoutRecord.findFirst({
        where: {
          clientId: resolvedUserId,
          sessionId: { in: candidateIds },
          scheduledDate: targetDate,
          isCompleted: true,
          isLocked: true,
        },
      });

      // If no lock for todayIST, check most recent completed record for this session
      if (!lockedRecord && !(payload as any).scheduledDate) {
        const recentRecord = await prisma.workoutRecord.findFirst({
          where: {
            clientId: resolvedUserId,
            sessionId: { in: candidateIds },
            isCompleted: true,
            isLocked: true,
          },
          orderBy: { completedAt: 'desc' },
        });

        if (recentRecord && recentRecord.scheduledDate) {
          const session = await this.getSessionById(resolvedSessionId);
          const assignment = await prisma.workoutAssignment.findFirst({
            where: { clientId: resolvedUserId, sessionId: { in: candidateIds }, active: true },
          });
          const isTodayScheduled = isSessionScheduledForDate(session || {}, assignment || {}, todayIST);
          // Only block if today is NOT a newly scheduled recurring occurrence of this session!
          if (!isTodayScheduled || recentRecord.scheduledDate === todayIST) {
            lockedRecord = recentRecord;
          }
        }
      }

      if (lockedRecord) {
        throw new Error('SESSION_LOCKED: Workout session is completed and locked. Modifications are forbidden unless unlocked by an administrator.');
      }

      const lockedAssignment = await prisma.workoutAssignment.findFirst({
        where: {
          clientId: resolvedUserId,
          sessionId: { in: candidateIds },
          isLocked: true,
          unlockedAt: null,
        },
      });
      if (lockedAssignment && lockedAssignment.scheduledDate === targetDate) {
        throw new Error('SESSION_LOCKED: Workout session is completed and locked. Modifications are forbidden unless unlocked by an administrator.');
      }
    } catch (e: any) {
      if (e.message && e.message.includes('SESSION_LOCKED')) {
        throw e;
      }
    }

    // In-memory check for offline/test environments
    let memLockedRecord = Array.from(this.records.values()).find(
      (r) => candidateIds.includes(r.sessionId || '') &&
             (r.clientId === resolvedUserId || r.clientId === clientId) &&
             r.scheduledDate === targetDate &&
             r.isCompleted &&
             r.isLocked
    );

    if (!memLockedRecord && !(payload as any).scheduledDate) {
      const recentMem = Array.from(this.records.values())
        .filter((r) => candidateIds.includes(r.sessionId || '') &&
                       (r.clientId === resolvedUserId || r.clientId === clientId) &&
                       r.isCompleted &&
                       r.isLocked)
        .sort((a, b) => b.createdAt.localeCompare(a.createdAt))[0];

      if (recentMem && recentMem.scheduledDate) {
        const memSession = this.sessions.get(resolvedSessionId);
        const memAssign = Array.from(this.assignments.values()).find(
          (a) => candidateIds.includes(a.sessionId) && (a.clientId === resolvedUserId || a.clientId === clientId) && a.active
        );
        const isTodayScheduled = isSessionScheduledForDate(memSession || {}, memAssign || {}, todayIST);
        if (!isTodayScheduled || recentMem.scheduledDate === todayIST) {
          memLockedRecord = recentMem;
        }
      }
    }

    if (memLockedRecord) {
      throw new Error('SESSION_LOCKED: Workout session is completed and locked. Modifications are forbidden unless unlocked by an administrator.');
    }

    // 1. In-memory update for instant availability and test support
    const completedAtStr = payload.isCompleted ? new Date().toISOString() : null;
    for (const sid of candidateIds) {
      const key = `${resolvedUserId}_${sid}_${targetDate}_${payload.exerciseId}_${payload.setNumber}`;
      this.activeSetRecords.set(key, {
        sessionId: sid,
        exerciseId: payload.exerciseId,
        setNumber: payload.setNumber,
        isCompleted: payload.isCompleted,
        actualWeight: payload.actualWeight,
        actualReps: payload.actualReps,
        actualRir: payload.actualRir,
        actualRpe: payload.actualRpe,
        completedAt: completedAtStr,
      });
    }

    // 2. Fetch session definition to know target counts
    const session = await this.getSessionById(resolvedSessionId);
    const sessionWithOverrides = session ? await this.applyClientOverridesToSession(session, resolvedUserId) : null;
    const sessionEx = (sessionWithOverrides || session)?.exercises.find((e) => e.id === payload.exerciseId || e.exerciseId === payload.exerciseId);
    const totalRequiredSets = Number(sessionEx?.numberOfSets) || (sessionEx?.sets ? sessionEx.sets.length : 3);

    // 3. PostgreSQL persistence via Prisma
    let totalCompletedSetsCount = 0;
    let exerciseCompletedCount = 0;

    try {
      const dbUser = await prisma.user.findFirst({
        where: { id: resolvedUserId },
        select: { id: true },
      });

      if (dbUser) {
        // Find or create in-progress workout record strictly for targetDate
        let activeRecord = await prisma.workoutRecord.findFirst({
          where: {
            clientId: resolvedUserId,
            sessionId: { in: candidateIds },
            isCompleted: false,
            scheduledDate: targetDate,
          },
          include: {
            exerciseRecords: {
              include: { setRecords: true },
            },
          },
        });

        if (!activeRecord) {
          activeRecord = await prisma.workoutRecord.create({
            data: {
              clientId: resolvedUserId,
              sessionId: resolvedSessionId,
              sessionTitle: session?.title || 'Workout Session',
              workoutType: session?.workoutType || 'Strength',
              startedAt: new Date(),
              isCompleted: false,
              isLocked: false,
              scheduledDate: targetDate,
            },
            include: {
              exerciseRecords: {
                include: { setRecords: true },
              },
            },
          });
        }

        // Find or create exercise record
        let exRecord = activeRecord.exerciseRecords.find(
          (e) => e.exerciseId === payload.exerciseId || e.exerciseName === sessionEx?.exerciseName
        );
        if (!exRecord) {
          exRecord = await prisma.workoutExerciseRecord.create({
            data: {
              recordId: activeRecord.id,
              exerciseId: payload.exerciseId,
              exerciseName: sessionEx?.exerciseName || payload.exerciseId,
              orderIndex: sessionEx?.orderIndex ?? activeRecord.exerciseRecords.length,
              supersetTag: sessionEx?.supersetTag || null,
            },
            include: { setRecords: true },
          });
        }

        // Find or upsert set record
        let setRecord = exRecord.setRecords?.find((s) => s.setNumber === payload.setNumber);
        if (setRecord) {
          await prisma.workoutSetRecord.update({
            where: { id: setRecord.id },
            data: {
              isCompleted: payload.isCompleted,
              completedAt: payload.isCompleted ? new Date() : null,
              actualWeight: payload.actualWeight !== undefined ? payload.actualWeight : setRecord.actualWeight,
              actualReps: payload.actualReps !== undefined ? payload.actualReps : setRecord.actualReps,
              actualRir: payload.actualRir !== undefined ? payload.actualRir : setRecord.actualRir,
              actualRpe: payload.actualRpe !== undefined ? payload.actualRpe : setRecord.actualRpe,
              tempo: payload.tempo || setRecord.tempo,
            },
          });
        } else {
          await prisma.workoutSetRecord.create({
            data: {
              exerciseRecordId: exRecord.id,
              setNumber: payload.setNumber,
              setType: sessionEx?.setType === 'Warm-up' ? 'WARMUP' : 'WORKING',
              isCompleted: payload.isCompleted,
              completedAt: payload.isCompleted ? new Date() : null,
              actualWeight: payload.actualWeight ?? null,
              actualReps: payload.actualReps ?? null,
              actualRir: payload.actualRir ?? null,
              actualRpe: payload.actualRpe ?? null,
              tempo: payload.tempo || null,
            },
          });
        }

        // Re-query set counts
        totalCompletedSetsCount = await prisma.workoutSetRecord.count({
          where: {
            exerciseRecord: { recordId: activeRecord.id },
            isCompleted: true,
          },
        });

        exerciseCompletedCount = await prisma.workoutSetRecord.count({
          where: {
            exerciseRecordId: exRecord.id,
            isCompleted: true,
          },
        });

        await prisma.workoutRecord.update({
          where: { id: activeRecord.id },
          data: { completedSetsCount: totalCompletedSetsCount },
        });
      }
    } catch (dbErr: any) {
      if (dbErr.message && dbErr.message.includes('SESSION_LOCKED')) {
        throw dbErr;
      }
      console.warn('[WorkoutRepository] DB notice during saveSetCompletion:', dbErr?.message);
    }

    // Determine counts from in-memory fallback if DB count is 0 or offline
    if (totalCompletedSetsCount === 0 || exerciseCompletedCount === 0) {
      let memTotal = 0;
      let memEx = 0;
      for (const [k, v] of this.activeSetRecords.entries()) {
        if (k.startsWith(`${resolvedUserId}_`) && v.isCompleted) {
          memTotal++;
          if (v.exerciseId === payload.exerciseId) {
            memEx++;
          }
        }
      }
      if (totalCompletedSetsCount === 0) totalCompletedSetsCount = memTotal;
      if (exerciseCompletedCount === 0) exerciseCompletedCount = memEx;
    }

    const isExerciseCompleted = exerciseCompletedCount >= totalRequiredSets && totalRequiredSets > 0;

    return {
      sessionId: resolvedSessionId,
      exerciseId: payload.exerciseId,
      setNumber: payload.setNumber,
      isCompleted: payload.isCompleted,
      completedAt: completedAtStr,
      actualWeight: payload.actualWeight,
      actualReps: payload.actualReps,
      isExerciseCompleted,
      completedSetsCount: totalCompletedSetsCount,
      totalSetsCount: totalRequiredSets,
    };
  }

  // --- Admin Unlock / Reopen Session Operation ---
  async unlockSession(
    adminId: string,
    params: {
      recordId?: string | null;
      sessionId?: string | null;
      assignmentId?: string | null;
      clientId: string;
      scheduledDate?: string | null;
      reason: string;
    }
  ): Promise<{ success: boolean; message: string; unlockedAt: string; adminId: string; reason: string }> {
    const resolvedAdminId = await this.resolveUserId(adminId);
    const resolvedClientId = await this.resolveUserId(params.clientId);
    const now = new Date();
    const nowIso = now.toISOString();
    const candidateIds = params.sessionId ? this.resolveSessionCandidateIds(params.sessionId) : [];

    // 1. Update DB assignments
    try {
      const assignmentWhere: any = {
        clientId: resolvedClientId,
      };
      if (params.assignmentId) {
        assignmentWhere.id = params.assignmentId;
      } else if (candidateIds.length > 0) {
        assignmentWhere.sessionId = { in: candidateIds };
      }

      await prisma.workoutAssignment.updateMany({
        where: assignmentWhere,
        data: {
          isLocked: false,
          status: 'IN_PROGRESS',
          unlockedAt: now,
          unlockedById: resolvedAdminId,
          unlockReason: params.reason,
        },
      });

      // 2. Update DB workout records
      if (params.recordId) {
        await prisma.workoutRecord.update({
          where: { id: params.recordId },
          data: {
            isLocked: false,
            unlockedAt: now,
            unlockedById: resolvedAdminId,
            unlockReason: params.reason,
          },
        });
      }

      const recordWhere: any = {
        clientId: resolvedClientId,
      };
      if (candidateIds.length > 0) {
        recordWhere.sessionId = { in: candidateIds };
      }
      if (params.scheduledDate) {
        recordWhere.scheduledDate = params.scheduledDate;
      }
      await prisma.workoutRecord.updateMany({
        where: recordWhere,
        data: {
          isLocked: false,
          unlockedAt: now,
          unlockedById: resolvedAdminId,
          unlockReason: params.reason,
        },
      });
    } catch (err: any) {
      console.warn('[WorkoutRepository] DB notice during unlockSession:', err?.message);
    }

    // 3. Update in-memory assignments and records
    for (const a of this.assignments.values()) {
      if (
        (a.clientId === resolvedClientId || a.clientId === params.clientId) &&
        (params.assignmentId ? a.id === params.assignmentId : (params.sessionId ? candidateIds.includes(a.sessionId) : true))
      ) {
        a.isLocked = false;
        a.status = 'IN_PROGRESS';
        a.unlockedAt = nowIso;
        a.unlockedById = resolvedAdminId;
        a.unlockReason = params.reason;
      }
    }

    if (params.recordId && this.records.has(params.recordId)) {
      const r = this.records.get(params.recordId)!;
      r.isLocked = false;
      r.unlockedAt = nowIso;
      r.unlockedById = resolvedAdminId;
      r.unlockReason = params.reason;
    }

    for (const r of this.records.values()) {
      if (
        (r.clientId === resolvedClientId || r.clientId === params.clientId) &&
        (params.sessionId ? candidateIds.includes(r.sessionId || '') : true)
      ) {
        r.isLocked = false;
        r.unlockedAt = nowIso;
        r.unlockedById = resolvedAdminId;
        r.unlockReason = params.reason;
      }
    }

    return {
      success: true,
      message: `Workout session successfully unlocked by administrator for client "${params.clientId}".`,
      unlockedAt: nowIso,
      adminId: resolvedAdminId,
      reason: params.reason,
    };
  }

  async getActiveSetCompletions(clientId: string, sessionId: string): Promise<any[]> {
    const resolvedUserId = await this.resolveUserId(clientId);
    const candidateIds = this.resolveSessionCandidateIds(sessionId);

    try {
      const activeRecord = await prisma.workoutRecord.findFirst({
        where: {
          clientId: resolvedUserId,
          sessionId: { in: candidateIds },
          isCompleted: false,
        },
        include: {
          exerciseRecords: {
            include: { setRecords: true },
          },
        },
        orderBy: { startedAt: 'desc' },
      });

      if (activeRecord) {
        const results: any[] = [];
        for (const er of activeRecord.exerciseRecords) {
          for (const sr of er.setRecords) {
            results.push({
              exerciseId: er.exerciseId,
              setNumber: sr.setNumber,
              isCompleted: sr.isCompleted,
              actualWeight: sr.actualWeight,
              actualReps: sr.actualReps,
              actualRpe: sr.actualRpe,
              actualRir: sr.actualRir,
              completedAt: sr.completedAt ? sr.completedAt.toISOString() : null,
            });
          }
        }
        return results;
      }
    } catch (_) {}

    // In-memory fallback: active in-progress records for candidateIds
    const results: any[] = [];
    for (const sid of candidateIds) {
      const prefix = `${resolvedUserId}_${sid}_`;
      for (const [k, v] of this.activeSetRecords.entries()) {
        if (k.startsWith(prefix)) {
          results.push(v);
        }
      }
    }
    return results;
  }

  async overlayActiveSetsOnSession(session: StoredWorkoutSession, clientId: string): Promise<StoredWorkoutSession> {
    const completions = await this.getActiveSetCompletions(clientId, session.id);
    if (!completions || completions.length === 0) return session;

    const completionMap = new Map<string, any>();
    for (const c of completions) {
      completionMap.set(`${c.exerciseId}_${c.setNumber}`, c);
    }

    const updatedExercises = session.exercises.map((ex) => {
      const updatedSets = (ex.sets || []).map((s: any) => {
        const match = completionMap.get(`${ex.exerciseId}_${s.setNumber}`) ||
                      completionMap.get(`${ex.id}_${s.setNumber}`);
        if (match) {
          return {
            ...s,
            isCompleted: match.isCompleted,
            actualWeight: match.actualWeight ?? s.actualWeight,
            actualReps: match.actualReps ?? s.actualReps,
            actualRpe: match.actualRpe ?? s.actualRpe,
            actualRir: match.actualRir ?? s.actualRir,
            completedAt: match.completedAt ?? s.completedAt,
          };
        }
        return s;
      });

      return {
        ...ex,
        sets: updatedSets,
      };
    });

    return {
      ...session,
      exercises: updatedExercises,
    };
  }

  // --- Client Session Customizations & Persistent Exercise Overrides ---
  async getClientSessionOverride(
    clientId: string,
    sessionId: string,
    dayOfWeek?: string
  ): Promise<ClientSessionOverrideData | null> {
    const resolvedUserId = await this.resolveUserId(clientId);
    const memKey = `${resolvedUserId}_${sessionId}`;
    const cached = this.clientSessionOverrides.get(memKey);

    try {
      const dbOverride = await prisma.clientSessionOverride.findFirst({
        where: {
          clientId: resolvedUserId,
          OR: [
            { sessionId },
            ...(dayOfWeek ? [{ dayOfWeek }] : []),
          ],
        },
      });

      if (dbOverride && dbOverride.overrides) {
        const parsed = (typeof dbOverride.overrides === 'string'
          ? JSON.parse(dbOverride.overrides)
          : dbOverride.overrides) as ClientSessionOverrideData;
        this.clientSessionOverrides.set(memKey, parsed);
        return parsed;
      }
    } catch (e: any) {
      console.warn('[WorkoutRepository] Failed to query clientSessionOverride from DB:', e?.message);
    }

    return cached || null;
  }

  async saveClientSessionOverride(
    clientId: string,
    sessionId: string,
    data: ClientSessionOverrideData,
    dayOfWeek?: string
  ): Promise<ClientSessionOverrideData> {
    const resolvedUserId = await this.resolveUserId(clientId);
    const memKey = `${resolvedUserId}_${sessionId}`;
    this.clientSessionOverrides.set(memKey, data);

    try {
      await prisma.clientSessionOverride.upsert({
        where: {
          clientId_sessionId: {
            clientId: resolvedUserId,
            sessionId,
          },
        },
        create: {
          clientId: resolvedUserId,
          sessionId,
          dayOfWeek: dayOfWeek || null,
          overrides: data as any,
        },
        update: {
          dayOfWeek: dayOfWeek || undefined,
          overrides: data as any,
          updatedAt: new Date(),
        },
      });
    } catch (e: any) {
      console.warn('[WorkoutRepository] Failed to save clientSessionOverride to DB:', e?.message);
    }

    return data;
  }

  async replaceExerciseInSession(
    clientId: string,
    sessionId: string,
    replacement: ClientExerciseReplacement,
    dayOfWeek?: string
  ): Promise<ClientSessionOverrideData> {
    const current = (await this.getClientSessionOverride(clientId, sessionId, dayOfWeek)) || {
      replacements: [],
      addedExercises: [],
      removedExerciseIds: [],
    };

    const replacements = (current.replacements || []).filter(
      (r) =>
        r.originalExerciseId !== replacement.originalExerciseId &&
        r.replacementExerciseId !== replacement.replacementExerciseId
    );
    replacements.push(replacement);

    const removedExerciseIds = (current.removedExerciseIds || []).filter(
      (id) => id !== replacement.originalExerciseId && id !== replacement.replacementExerciseId
    );

    const updated: ClientSessionOverrideData = {
      ...current,
      replacements,
      removedExerciseIds,
    };

    return this.saveClientSessionOverride(clientId, sessionId, updated, dayOfWeek);
  }

  async addExerciseToSessionOverride(
    clientId: string,
    sessionId: string,
    exercise: any,
    dayOfWeek?: string
  ): Promise<ClientSessionOverrideData> {
    const current = (await this.getClientSessionOverride(clientId, sessionId, dayOfWeek)) || {
      replacements: [],
      addedExercises: [],
      removedExerciseIds: [],
    };

    const exerciseId = exercise.exerciseId || exercise.id;
    const addedExercises = (current.addedExercises || []).filter(
      (ex) => (ex.exerciseId || ex.id) !== exerciseId
    );
    addedExercises.push(exercise);

    const updated: ClientSessionOverrideData = {
      ...current,
      addedExercises,
    };

    return this.saveClientSessionOverride(clientId, sessionId, updated, dayOfWeek);
  }

  async removeExerciseFromSessionOverride(
    clientId: string,
    sessionId: string,
    exerciseId: string,
    dayOfWeek?: string
  ): Promise<ClientSessionOverrideData> {
    const current = (await this.getClientSessionOverride(clientId, sessionId, dayOfWeek)) || {
      replacements: [],
      addedExercises: [],
      removedExerciseIds: [],
    };

    const addedExercises = (current.addedExercises || []).filter(
      (ex) => (ex.exerciseId || ex.id) !== exerciseId
    );

    const replacements = (current.replacements || []).filter(
      (r) => r.replacementExerciseId !== exerciseId && r.originalExerciseId !== exerciseId
    );

    const removedExerciseIds = Array.from(new Set([...(current.removedExerciseIds || []), exerciseId]));

    const updated: ClientSessionOverrideData = {
      ...current,
      addedExercises,
      replacements,
      removedExerciseIds,
    };

    return this.saveClientSessionOverride(clientId, sessionId, updated, dayOfWeek);
  }

  async resetExerciseInSessionOverride(
    clientId: string,
    sessionId: string,
    exerciseId: string
  ): Promise<ClientSessionOverrideData | null> {
    const current = await this.getClientSessionOverride(clientId, sessionId);
    if (!current) return null;

    const replacements = (current.replacements || []).filter(
      (r) => r.replacementExerciseId !== exerciseId && r.originalExerciseId !== exerciseId
    );
    const addedExercises = (current.addedExercises || []).filter(
      (ex) => (ex.exerciseId || ex.id) !== exerciseId
    );
    const removedExerciseIds = (current.removedExerciseIds || []).filter((id) => id !== exerciseId);

    const updated: ClientSessionOverrideData = {
      ...current,
      replacements,
      addedExercises,
      removedExerciseIds,
    };

    if (
      (!updated.replacements || updated.replacements.length === 0) &&
      (!updated.addedExercises || updated.addedExercises.length === 0) &&
      (!updated.removedExerciseIds || updated.removedExerciseIds.length === 0) &&
      !updated.customSetsByExercise &&
      !updated.customSetCounts
    ) {
      await this.resetSessionOverride(clientId, sessionId);
      return null;
    }

    return this.saveClientSessionOverride(clientId, sessionId, updated);
  }

  async resetSessionOverride(clientId: string, sessionId: string): Promise<boolean> {
    const resolvedUserId = await this.resolveUserId(clientId);
    const memKey = `${resolvedUserId}_${sessionId}`;
    this.clientSessionOverrides.delete(memKey);

    try {
      await prisma.clientSessionOverride.deleteMany({
        where: {
          clientId: resolvedUserId,
          sessionId,
        },
      });
      return true;
    } catch (e: any) {
      console.warn('[WorkoutRepository] Failed to delete clientSessionOverride from DB:', e?.message);
      return false;
    }
  }

  async applyClientOverridesToSession(
    session: StoredWorkoutSession,
    clientId: string
  ): Promise<StoredWorkoutSession> {
    if (!session || !session.exercises) return session;
    const resolvedUserId = await this.resolveUserId(clientId);
    const override = await this.getClientSessionOverride(
      resolvedUserId,
      session.id,
      session.recurringSchedule || undefined
    );

    if (!override) return session;

    const removedIds = new Set(override.removedExerciseIds || []);
    const replacementsMap = new Map<string, ClientExerciseReplacement>();
    for (const r of override.replacements || []) {
      replacementsMap.set(r.originalExerciseId, r);
    }

    const seenExerciseIds = new Set<string>();
    const updatedExercises: StoredSessionExercise[] = [];

    // Process base exercises
    for (let i = 0; i < session.exercises.length; i++) {
      const ex = session.exercises[i];
      if (removedIds.has(ex.exerciseId) || removedIds.has(ex.id)) {
        continue; // user removed this exercise
      }

      const replacement = replacementsMap.get(ex.exerciseId) || replacementsMap.get(ex.id);
      if (replacement) {
        const replacementId = replacement.replacementExerciseId;
        if (seenExerciseIds.has(replacementId)) continue; // prevent duplicates
        seenExerciseIds.add(replacementId);

        const customSets = replacement.customSets && replacement.customSets.length > 0
          ? replacement.customSets.map((s, idx) => ({
              ...s,
              id: s.id || `set_${replacementId}_${idx + 1}`,
              setNumber: s.setNumber ?? (idx + 1),
              isCompleted: false,
            }))
          : (ex.sets || []).map((s, idx) => ({
              ...s,
              id: `set_${replacementId}_${idx + 1}`,
              setNumber: idx + 1,
              targetWeight: replacement.targetWeight !== undefined && replacement.targetWeight !== null ? Number(replacement.targetWeight) : s.targetWeight,
              targetReps: replacement.targetReps || s.targetReps,
              isCompleted: false,
            }));

        updatedExercises.push({
          ...ex,
          id: `ex_${replacementId}_${ex.id}`,
          exerciseId: replacementId,
          exerciseName: replacement.replacementExerciseName,
          category: replacement.category || ex.category,
          primaryMusclesDisplay: replacement.primaryMusclesDisplay || (ex as any).primaryMusclesDisplay,
          secondaryMusclesDisplay: replacement.secondaryMusclesDisplay || (ex as any).secondaryMusclesDisplay,
          trainerNote: replacement.trainerNote || (ex as any).trainerNote || ex.exerciseNotes,
          exerciseNotes: replacement.trainerNote || ex.exerciseNotes || null,
          targetReps: replacement.targetReps || ex.targetReps,
          targetWeight: replacement.targetWeight !== undefined && replacement.targetWeight !== null ? Number(replacement.targetWeight) : ex.targetWeight,
          numberOfSets: replacement.numberOfSets || customSets.length || ex.numberOfSets,
          sets: customSets,
          isCustomReplacement: true,
          originalExerciseId: ex.exerciseId,
          originalExerciseName: ex.exerciseName,
        } as any);
      } else {
        if (seenExerciseIds.has(ex.exerciseId)) continue;
        seenExerciseIds.add(ex.exerciseId);

        const customSets = override.customSetsByExercise?.[ex.exerciseId] || override.customSetsByExercise?.[ex.id];
        if (customSets && customSets.length > 0) {
          updatedExercises.push({
            ...ex,
            numberOfSets: customSets.length,
            sets: customSets,
          });
        } else {
          updatedExercises.push(ex);
        }
      }
    }

    // Process added exercises
    for (const added of override.addedExercises || []) {
      const addedId = added.exerciseId || added.id;
      if (!addedId || seenExerciseIds.has(addedId)) continue;
      seenExerciseIds.add(addedId);

      const numSets = Number(added.numberOfSets) || (Array.isArray(added.sets) ? added.sets.length : 3);
      const addedSets = Array.isArray(added.sets) && added.sets.length > 0
        ? added.sets.map((s: any, idx: number) => ({
            id: s.id || `set_${addedId}_${idx + 1}`,
            setNumber: s.setNumber ?? (idx + 1),
            setType: s.setType || 'WORKING',
            targetRepsMin: s.targetRepsMin ?? 8,
            targetRepsMax: s.targetRepsMax ?? 12,
            targetReps: s.targetReps || '8–12',
            targetWeight: s.targetWeight !== undefined && s.targetWeight !== null ? Number(s.targetWeight) : 0,
            targetRpe: s.targetRpe ?? 8.0,
            targetRir: s.targetRir ?? 2,
            restSeconds: s.restSeconds || added.restSeconds || 90,
            tempo: s.tempo || '3-1-1-0',
            isCompleted: false,
          }))
        : Array.from({ length: numSets }, (_, idx) => ({
            id: `set_${addedId}_${idx + 1}`,
            setNumber: idx + 1,
            setType: 'WORKING',
            targetRepsMin: 8,
            targetRepsMax: 12,
            targetReps: added.targetReps || '8–12',
            targetWeight: added.targetWeight !== undefined && added.targetWeight !== null ? Number(added.targetWeight) : 0,
            targetRpe: 8.0,
            targetRir: 2,
            restSeconds: added.restSeconds || 90,
            tempo: '3-1-1-0',
            isCompleted: false,
          }));

      updatedExercises.push({
        id: `custom_ex_${addedId}_${Date.now()}`,
        exerciseId: addedId,
        exerciseName: added.exerciseName || added.name || 'Custom Exercise',
        category: added.category || 'Custom',
        orderIndex: updatedExercises.length,
        numberOfSets: numSets,
        targetReps: added.targetReps || '8–12',
        targetWeight: added.targetWeight !== undefined && added.targetWeight !== null ? Number(added.targetWeight) : 0,
        restSeconds: added.restSeconds || 90,
        targetRir: 2,
        targetRpe: 8.0,
        tempo: '3-1-1-0',
        setType: 'WORKING',
        exerciseNotes: added.trainerNote || added.notes || null,
        trainerNote: added.trainerNote || null,
        sets: addedSets,
        isCustomAdded: true,
      } as any);
    }

    return {
      ...session,
      exercises: updatedExercises,
      hasClientCustomization: true,
    } as any;
  }

  private async applyActiveSetOverlays<T extends StoredWorkoutSession>(
    result: { recommended: (T & { isRecommended: boolean }) | null; available: T[] },
    clientId: string
  ): Promise<{ recommended: (T & { isRecommended: boolean }) | null; available: T[] }> {
    const overlaidAvailable: T[] = [];
    for (const s of result.available) {
      const withOverrides = await this.applyClientOverridesToSession(s, clientId);
      const overlaid = await this.overlayActiveSetsOnSession(withOverrides, clientId);
      overlaidAvailable.push({ ...withOverrides, ...overlaid } as T);
    }
    let overlaidRec: (T & { isRecommended: boolean }) | null = null;
    if (result.recommended) {
      const withOverrides = await this.applyClientOverridesToSession(result.recommended, clientId);
      const baseRec = await this.overlayActiveSetsOnSession(withOverrides, clientId);
      overlaidRec = { ...withOverrides, ...baseRec, isRecommended: result.recommended.isRecommended } as (T & { isRecommended: boolean });
    }
    return {
      recommended: overlaidRec,
      available: overlaidAvailable,
    };
  }

  async saveWorkoutSplit(data: any, authorId: string): Promise<StoredWorkoutSplitPlan> {
    const splitId = data.id || `split_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;
    const splitTitle = data.title || 'Weekly Workout Split';
    const splitType = data.splitType || 'Custom';
    const description = data.description || null;
    const frequency = Number(data.frequencyPerWeek) || 6;
    const targetClientIds: string[] = [];
    if (data.clientId) targetClientIds.push(data.clientId);
    if (Array.isArray(data.clientIds)) {
      for (const cid of data.clientIds) {
        if (cid && !targetClientIds.includes(cid)) targetClientIds.push(cid);
      }
    }

    const resolvedClientIds: string[] = [];
    for (const cid of targetClientIds) {
      const resolved = await this.resolveUserId(cid);
      if (resolved && !resolvedClientIds.includes(resolved)) resolvedClientIds.push(resolved);
    }
    const resolvedClientId = resolvedClientIds[0] || null;
    const todayWeekday = getTodayISTWeekday();

    const storedDays: StoredWorkoutSplitDay[] = [];

    // If clients are specified, deactivate previous active assignments
    for (const rCid of resolvedClientIds) {
      try {
        await prisma.workoutAssignment.updateMany({
          where: { clientId: rCid, active: true },
          data: { active: false },
        });
      } catch (_) {}
    }

    const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const rawInputDays: any[] = Array.isArray(data.days) ? data.days : [];

    const defaultPatternByCount: Record<number, string[]> = {
      2: ['Monday', 'Thursday'],
      3: ['Monday', 'Wednesday', 'Friday'],
      4: ['Monday', 'Tuesday', 'Thursday', 'Friday'],
      5: ['Monday', 'Tuesday', 'Wednesday', 'Friday', 'Saturday'],
      6: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
      7: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
    };
    const defaultPattern = defaultPatternByCount[rawInputDays.length] || dayNames;

    // Construct canonical 7 days: sort by Monday-Sunday order and insert Rest Day for unassigned days
    const inputDays: any[] = [];
    for (let i = 0; i < 7; i++) {
      const dayName = dayNames[i];
      const targetWeekdayNum = i + 1;

      // 1. Try explicit weekday string match (guard against numeric dayOfWeek like 1,2,3)
      let found = rawInputDays.find((d: any) => {
        const rawVal = d.dayOfWeek ?? d.dayName ?? d.day ?? '';
        const raw = String(rawVal).toLowerCase();
        // Skip pure-numeric strings (e.g. "1") — those are weekday numbers, handled in step 2
        if (/^\d+$/.test(raw)) return false;
        return raw.includes(dayName.toLowerCase());
      });

      // 2. Try explicit dayIndex / dayNumber / numeric dayOfWeek match
      if (!found) {
        found = rawInputDays.find((d: any) =>
          d.dayIndex === targetWeekdayNum ||
          d.dayNumber === targetWeekdayNum ||
          Number(d.dayOfWeek) === targetWeekdayNum
        );
      }

      // 3. Try standard pattern index match if split days were passed without weekday names
      if (!found && defaultPattern.includes(dayName)) {
        const patternIdx = defaultPattern.indexOf(dayName);
        if (patternIdx !== -1 && rawInputDays[patternIdx]) {
          found = rawInputDays[patternIdx];
        }
      }

      if (found && !found.isRestDay) {
        inputDays.push({
          ...found,
          dayIndex: targetWeekdayNum,
          dayOfWeek: dayName,
          name: found.sessionTitle || found.title || found.name || `${splitTitle} — ${dayName}`,
        });
      } else {
        inputDays.push({
          dayOfWeek: dayName,
          dayIndex: targetWeekdayNum,
          name: `${dayName} — Rest & Recovery`,
          isRestDay: true,
          exercises: [],
        });
      }
    }

    for (let idx = 0; idx < inputDays.length; idx++) {
      const d = inputDays[idx];
      const dayIndex = d.dayIndex ?? (idx + 1);
      const dayOfWeek = d.dayOfWeek || 'Monday';
      const isRestDay = Boolean(d.isRestDay);
      const weekdayNum = getWeekdayFromDayName(dayOfWeek);
      const scheduledDate = getISTDateForWeekday(weekdayNum);
      const isToday = weekdayNum === todayWeekday;

      if (isRestDay) {
        storedDays.push({
          id: d.id || `split_day_${splitId}_${dayIndex}`,
          dayOfWeek,
          dayIndex,
          name: d.name || `${dayOfWeek} — Rest & Recovery`,
          workoutType: 'Rest',
          targetMuscleGroup: 'Recovery',
          estimatedDurationMinutes: 0,
          isRestDay: true,
          notes: d.notes || 'Scheduled rest & active recovery day.',
          exercises: [],
        });
        continue;
      }

      const dayTitle = d.sessionTitle || d.title || d.name || `${splitTitle} — ${dayOfWeek}`;
      const dayWorkoutType = d.workoutType || 'Strength';
      const dayTargetMuscle = d.targetMuscleGroup || 'Full Body';
      const dayDuration = Number(d.estimatedDurationMinutes) || 45;
      const dayNotes = d.notes || null;
      const dayExercises = Array.isArray(d.exercises) ? d.exercises : [];

      let session: any = null;

      // Check if updating existing session for this day
      if (d.sessionId) {
        try {
          session = await prisma.workoutSession.findUnique({
            where: { id: d.sessionId },
          });
        } catch (_) {}
      }

      if (session) {
        // Update existing session
        try {
          await prisma.workoutSession.update({
            where: { id: session.id },
            data: {
              title: dayTitle,
              workoutType: dayWorkoutType,
              targetMuscleGroup: dayTargetMuscle,
              estimatedDurationMinutes: dayDuration,
              description: dayNotes || `${dayTitle} [SPLIT:${splitId}]`,
              recurringSchedule: dayOfWeek,
              updatedAt: new Date(),
            },
          });

          // Delete existing exercises & templates to replace cleanly
          await prisma.workoutSessionExercise.deleteMany({
            where: { sessionId: session.id },
          });
        } catch (_) {}
      } else {
        // Create new session
        const sessionId = d.sessionId || `ws_${splitId}_day_${dayIndex}_${Date.now()}`;
        try {
          session = await prisma.workoutSession.create({
            data: {
              id: sessionId,
              title: dayTitle,
              workoutType: dayWorkoutType,
              targetMuscleGroup: dayTargetMuscle,
              difficulty: data.difficulty || 'Intermediate',
              estimatedDurationMinutes: dayDuration,
              description: dayNotes || `${dayTitle} [SPLIT:${splitId}]`,
              recurringSchedule: dayOfWeek,
              createdById: authorId,
              isActive: true,
              availabilityType: resolvedClientId ? 'INDIVIDUAL' : 'ALL',
            },
          });
        } catch (_) {
          session = { id: sessionId, title: dayTitle };
        }
      }

      // Create session exercises and templates
      const createdExercises: StoredSessionExercise[] = [];
      for (let exIdx = 0; exIdx < dayExercises.length; exIdx++) {
        const ex = dayExercises[exIdx];
        const exName = ex.exerciseName || ex.name || `Exercise ${exIdx + 1}`;
        const exId = ex.exerciseId || `ex_${session.id}_${exIdx + 1}`;
        const numSets = Number(ex.numberOfSets || ex.sets || ex.setCount) || 3;
        const targetReps = String(ex.targetReps || ex.reps || '8–12');
        const targetWeight = ex.targetWeight !== undefined && ex.targetWeight !== null ? Number(ex.targetWeight) : null;
        const restSec = Number(ex.restSeconds || ex.rest) || 90;
        const rir = ex.targetRir !== undefined && ex.targetRir !== null ? Number(ex.targetRir) : 2;
        const rpe = ex.targetRpe !== undefined && ex.targetRpe !== null ? Number(ex.targetRpe) : 8.0;
        const tempo = ex.tempo || '3-1-1-0';
        const setType = ex.setType || 'WORKING';

        let createdSessionEx: any = null;
        try {
          createdSessionEx = await prisma.workoutSessionExercise.create({
            data: {
              sessionId: session.id,
              exerciseId: exId,
              exerciseName: exName,
              category: ex.category || dayWorkoutType || 'Strength',
              orderIndex: exIdx,
              supersetTag: ex.supersetTag || null,
              numberOfSets: numSets,
              targetReps,
              targetWeight,
              restSeconds: restSec,
              targetRir: rir,
              targetRpe: rpe,
              tempo,
              setType,
              adminInstruction: ex.adminInstruction || ex.notes || null,
            },
          });

          for (let s = 1; s <= numSets; s++) {
            await prisma.workoutSetTemplate.create({
              data: {
                sessionExerciseId: createdSessionEx.id,
                setNumber: s,
                setType,
                targetWeight,
                targetRepsMin: typeof targetReps === 'string' && targetReps.includes('–')
                  ? (parseInt(targetReps.split('–')[0]) || 8)
                  : (parseInt(targetReps) || 8),
                targetRepsMax: typeof targetReps === 'string' && targetReps.includes('–')
                  ? (parseInt(targetReps.split('–')[1]) || 12)
                  : (parseInt(targetReps) || 12),
                targetRir: rir,
                targetRpe: rpe,
                tempo,
              },
            });
          }
        } catch (_) {}

        createdExercises.push({
          id: createdSessionEx?.id || `se_${session.id}_${exIdx}`,
          sessionId: session.id,
          exerciseId: exId,
          exerciseName: exName,
          category: ex.category || dayWorkoutType || 'Strength',
          orderIndex: exIdx,
          supersetTag: ex.supersetTag || null,
          numberOfSets: numSets,
          targetReps,
          targetWeight,
          restSeconds: restSec,
          targetRir: rir,
          targetRpe: rpe,
          tempo,
          setType,
          adminInstruction: ex.adminInstruction || ex.notes || null,
        });
      }

      // Memory session cache update
      const storedSession: StoredWorkoutSession = {
        id: session.id,
        title: dayTitle,
        workoutType: dayWorkoutType,
        targetMuscleGroup: dayTargetMuscle,
        difficulty: data.difficulty || 'Intermediate',
        estimatedDurationMinutes: dayDuration,
        description: dayNotes || `${dayTitle} [SPLIT:${splitId}]`,
        isActive: true,
        recurringSchedule: dayOfWeek,
        availabilityType: resolvedClientId ? 'INDIVIDUAL' : 'ALL',
        createdById: authorId,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        exercises: createdExercises,
      };
      this.sessions.set(session.id, storedSession);

      // Assign to clients if specified
      if (resolvedClientIds.length > 0) {
        for (const rCid of resolvedClientIds) {
          try {
            const userExists = await prisma.user.findUnique({
              where: { id: rCid },
              select: { id: true },
            });
            if (userExists) {
              await prisma.workoutAssignment.create({
                data: {
                  sessionId: session.id,
                  clientId: rCid,
                  assignedById: authorId,
                  isRecommended: isToday || dayIndex === 1,
                  active: true,
                  scheduledDate,
                  status: 'ASSIGNED',
                },
              });
            }
          } catch (_) {}

          this.assignments.set(`as_${session.id}_${rCid}`, {
            id: `as_${session.id}_${rCid}`,
            sessionId: session.id,
            clientId: rCid,
            assignedById: authorId,
            isRecommended: isToday || dayIndex === 1,
            active: true,
            scheduledDate,
            status: 'ASSIGNED',
            assignedAt: new Date().toISOString(),
          });
        }
      }

      storedDays.push({
        id: session.id,
        sessionId: session.id,
        dayOfWeek,
        dayIndex,
        name: dayTitle,
        workoutType: dayWorkoutType,
        targetMuscleGroup: dayTargetMuscle,
        estimatedDurationMinutes: dayDuration,
        isRestDay: false,
        notes: dayNotes,
        exercises: createdExercises,
      });
    }

    const splitPlan: StoredWorkoutSplitPlan = {
      id: splitId,
      title: splitTitle,
      splitType,
      description,
      frequencyPerWeek: frequency,
      clientId: resolvedClientId,
      clientIds: resolvedClientIds,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      days: storedDays,
    };

    this.splitPlans.set(splitId, splitPlan);
    for (const cid of resolvedClientIds) {
      this.clientSplitMap.set(cid, splitId);
    }
    if (resolvedClientId) {
      this.clientSplitMap.set(resolvedClientId, splitId);
    }

    return splitPlan;
  }

  async getClientWorkoutSplit(clientId: string): Promise<StoredWorkoutSplitPlan | null> {
    const resolvedUserId = await this.resolveUserId(clientId);
    const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    // 1. Fetch active client assignments
    let assignments: any[] = [];
    try {
      assignments = await prisma.workoutAssignment.findMany({
        where: { clientId: resolvedUserId, active: true },
        include: {
          session: {
            include: {
              exercises: {
                include: { setTemplates: true },
                orderBy: { orderIndex: 'asc' },
              },
            },
          },
        },
      });
    } catch (_) {}

    if (!assignments || assignments.length === 0) {
      assignments = Array.from(this.assignments.values())
        .filter((a) => a.active && (a.clientId === resolvedUserId || a.clientId === clientId))
        .map((a) => ({
          ...a,
          session: this.sessions.get(a.sessionId),
        }));
    }

    if (!assignments || assignments.length === 0) {
      return null;
    }

    const days: StoredWorkoutSplitDay[] = [];

    for (let i = 0; i < 7; i++) {
      const dayName = dayNames[i];
      const weekdayNum = i + 1;

      // Find assignment matching this dayOfWeek
      const match = assignments.find((a) => {
        if (!a.session) return false;
        const schedule = (a.session.recurringSchedule || '').toLowerCase();
        if (schedule.includes(dayName.toLowerCase())) return true;
        if (a.scheduledDate) {
          const w = getWeekdayFromISTDateString(a.scheduledDate);
          if (w === weekdayNum) return true;
        }
        return false;
      });

      if (match && match.session) {
        let stored = mapPrismaSessionToStored(match.session);
        stored = await this.applyClientOverridesToSession(stored, resolvedUserId);
        days.push({
          id: match.session.id,
          sessionId: match.session.id,
          dayOfWeek: dayName,
          dayIndex: weekdayNum,
          name: match.session.title,
          workoutType: match.session.workoutType,
          targetMuscleGroup: match.session.targetMuscleGroup,
          estimatedDurationMinutes: match.session.estimatedDurationMinutes,
          isRestDay: false,
          notes: match.session.description,
          exercises: stored.exercises,
        });
      } else {
        days.push({
          id: `split_day_rest_${weekdayNum}`,
          dayOfWeek: dayName,
          dayIndex: weekdayNum,
          name: 'Rest Day',
          workoutType: 'Rest',
          targetMuscleGroup: 'Recovery',
          estimatedDurationMinutes: 0,
          isRestDay: true,
          notes: 'Rest & recovery day.',
          exercises: [],
        });
      }
    }

    const firstActive = days.find((d) => !d.isRestDay);
    const splitId = this.clientSplitMap.get(resolvedUserId) || this.clientSplitMap.get(clientId);
    const existingPlan = splitId ? this.splitPlans.get(splitId) : null;
    const splitTitle = existingPlan?.title || (firstActive ? `${firstActive.name.split('—')[0].trim()} Split` : 'Personalized Workout Split');

    return {
      id: existingPlan?.id || `split_${resolvedUserId}`,
      title: splitTitle,
      splitType: existingPlan?.splitType || 'Custom',
      description: existingPlan?.description,
      frequencyPerWeek: days.filter((d) => !d.isRestDay).length,
      clientId: resolvedUserId,
      clientIds: existingPlan?.clientIds || [resolvedUserId],
      createdAt: existingPlan?.createdAt || new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      days,
    };
  }

  async updateWorkoutSplitDay(splitId: string, dayId: string, dayData: any): Promise<StoredWorkoutSession | null> {
    const cleanDayId = dayId.startsWith('split_day_') ? dayId.replace('split_day_', '') : dayId;
    let sessionId = dayData.sessionId || cleanDayId;
    let existingSession = await this.getSessionById(sessionId);

    if (!existingSession && cleanDayId !== dayId) {
      existingSession = await this.getSessionById(dayId);
    }

    if (!existingSession) {
      const allSessions = await this.getAllSessions();
      existingSession = allSessions.find((s) =>
        s.id === sessionId ||
        s.id === dayId ||
        s.id === cleanDayId ||
        s.id.includes(cleanDayId) ||
        cleanDayId.includes(s.id) ||
        (s.description?.includes(splitId) && (s.recurringSchedule === dayData.dayOfWeek || (dayData.dayOfWeek && s.title.toLowerCase().includes(dayData.dayOfWeek.toLowerCase()))))
      ) || null;
      if (existingSession) sessionId = existingSession.id;
    }

    if (!existingSession) {
      existingSession = await this.createSession({
        id: sessionId.startsWith('ws_') ? sessionId : `ws_${splitId}_${cleanDayId}`,
        title: dayData.name || dayData.title || dayData.sessionTitle || `${dayData.dayOfWeek || cleanDayId} Workout`,
        workoutType: dayData.workoutType || 'Strength',
        targetMuscleGroup: dayData.targetMuscleGroup || 'Full Body',
        difficulty: dayData.difficulty || 'Intermediate',
        estimatedDurationMinutes: dayData.estimatedDurationMinutes || 45,
        description: dayData.description || `Session for ${dayData.dayOfWeek || cleanDayId} in split ${splitId}`,
        recurringSchedule: dayData.dayOfWeek || cleanDayId,
        isActive: true,
        availabilityType: 'ALL',
        exercises: dayData.exercises || [],
      });
      sessionId = existingSession.id;
    }

    const updated = await this.updateSession(sessionId, {
      ...dayData,
      title: dayData.name || dayData.title || existingSession.title,
      workoutType: dayData.workoutType || existingSession.workoutType,
      targetMuscleGroup: dayData.targetMuscleGroup || existingSession.targetMuscleGroup,
      recurringSchedule: dayData.dayOfWeek || existingSession.recurringSchedule,
      exercises: dayData.exercises || existingSession.exercises,
    });

    if (this.splitPlans.has(splitId)) {
      const plan = this.splitPlans.get(splitId)!;
      const day = plan.days.find((d) => d.id === sessionId || d.sessionId === sessionId || d.id === dayId || d.dayOfWeek === dayData.dayOfWeek);
      if (day) {
        if (dayData.name) day.name = dayData.name;
        if (dayData.targetMuscleGroup) day.targetMuscleGroup = dayData.targetMuscleGroup;
        if (dayData.workoutType) day.workoutType = dayData.workoutType;
        if (dayData.estimatedDurationMinutes) day.estimatedDurationMinutes = dayData.estimatedDurationMinutes;
        if (dayData.exercises) day.exercises = updated?.exercises || dayData.exercises;
        day.sessionId = sessionId;
      }
    }

    return updated;
  }

  async getWorkoutSplitById(splitId: string): Promise<StoredWorkoutSplitPlan | null> {
    return this.splitPlans.get(splitId) || null;
  }
}

export const workoutRepository = new WorkoutRepository();
