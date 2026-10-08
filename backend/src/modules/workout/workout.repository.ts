import { prisma } from '../../config/prisma';

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
    startDate: s.startDate ? s.startDate.toISOString() : null,
    endDate: s.endDate ? s.endDate.toISOString() : null,
    recurringSchedule: s.recurringSchedule,
    availabilityType: (s.availabilityType as any) || 'ALL',
    createdById: s.createdById,
    createdAt: s.createdAt ? s.createdAt.toISOString() : new Date().toISOString(),
    updatedAt: s.updatedAt ? s.updatedAt.toISOString() : new Date().toISOString(),
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
    assignedAt: a.assignedAt ? a.assignedAt.toISOString() : new Date().toISOString(),
    active: a.active,
  };
}

function mapPrismaRecordToStored(r: any): StoredWorkoutRecord {
  return {
    id: r.id,
    clientId: r.clientId,
    sessionId: r.sessionId,
    sessionTitle: r.sessionTitle,
    workoutType: r.workoutType,
    startedAt: r.startedAt ? r.startedAt.toISOString() : new Date().toISOString(),
    completedAt: r.completedAt ? r.completedAt.toISOString() : null,
    durationSeconds: r.durationSeconds,
    totalVolume: r.totalVolume,
    completedSetsCount: r.completedSetsCount,
    skippedSetsCount: r.skippedSetsCount,
    averageRpe: r.averageRpe,
    averageRir: r.averageRir,
    isCompleted: r.isCompleted,
    personalRecords: r.personalRecordsJson ? JSON.parse(r.personalRecordsJson) : [],
    notes: r.notes,
    createdAt: r.createdAt ? r.createdAt.toISOString() : new Date().toISOString(),
    updatedAt: r.updatedAt ? r.updatedAt.toISOString() : new Date().toISOString(),
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

  // Real registered clients are queried dynamically from PostgreSQL via workoutService.getClientsList()
  public clientsList: { id: string; name: string; email: string; status: string }[] = [];

  constructor() {
    this.seedDefaultSessions();
  }

  private seedDefaultSessions() {
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
    if (this.isInitialized) return;
    this.isInitialized = true;
    try {
      const defaultSessionIds = ['ws_push_a_01', 'ws_pull_a_02', 'ws_legs_a_03'];
      for (const id of defaultSessionIds) {
        const session = this.sessions.get(id);
        if (!session) continue;
        const existing = await prisma.workoutSession.findUnique({
          where: { id: session.id },
        });
        if (!existing) {
          await prisma.workoutSession.create({
            data: {
              id: session.id,
              title: session.title,
              workoutType: session.workoutType,
              targetMuscleGroup: session.targetMuscleGroup,
              difficulty: session.difficulty,
              estimatedDurationMinutes: session.estimatedDurationMinutes,
              description: session.description,
              isActive: session.isActive,
              startDate: session.startDate ? new Date(session.startDate) : new Date(),
              endDate: session.endDate ? new Date(session.endDate) : null,
              recurringSchedule: session.recurringSchedule,
              availabilityType: session.availabilityType,
              createdById: session.createdById,
              exercises: {
                create: session.exercises.map((ex, idx) => ({
                  exerciseId: ex.exerciseId,
                  exerciseName: ex.exerciseName,
                  category: ex.category,
                  orderIndex: ex.orderIndex ?? idx,
                  supersetTag: ex.supersetTag,
                  numberOfSets: ex.numberOfSets,
                  targetReps: ex.targetReps,
                  targetWeight: ex.targetWeight,
                  restSeconds: ex.restSeconds,
                  targetRir: ex.targetRir,
                  targetRpe: ex.targetRpe,
                  tempo: ex.tempo,
                  setType: ex.setType,
                  exerciseNotes: ex.exerciseNotes,
                  adminInstruction: ex.adminInstruction,
                  setTemplates: {
                    create: Array.from({ length: ex.numberOfSets }, (_, setIdx) => ({
                      setNumber: setIdx + 1,
                      setType: ex.setType === 'Warm-up' ? 'WARMUP' : 'WORKING',
                      targetWeight: ex.targetWeight,
                      targetRepsMin: 8,
                      targetRepsMax: 12,
                      targetRir: ex.targetRir ?? 2,
                      targetRpe: ex.targetRpe ?? 8.0,
                      tempo: ex.tempo,
                    })),
                  },
                })),
              },
            },
          });
        }

        const existingAssign = await prisma.workoutAssignment.findFirst({
          where: { sessionId: id, clientId: null },
        });
        if (!existingAssign) {
          await prisma.workoutAssignment.create({
            data: {
              sessionId: id,
              clientId: null,
              isRecommended: false,
              assignedById: 'admin_alex_stone',
              active: true,
            },
          });
        }
      }
    } catch (e: any) {
      console.warn('[WorkoutRepository] Database seed check note:', e?.message);
    }
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
      await this.ensureDatabaseSeeded();
      const sessions = await prisma.workoutSession.findMany({
        include: {
          exercises: {
            include: { setTemplates: true },
            orderBy: { orderIndex: 'asc' },
          },
        },
        orderBy: { createdAt: 'desc' },
      });
      if (sessions.length > 0) {
        return sessions.map(mapPrismaSessionToStored);
      }
    } catch (e) {
      console.warn('[WorkoutRepository] Failed to fetch sessions from DB, using cache:', e);
    }
    return Array.from(this.sessions.values());
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
              exerciseName: ex.exerciseName || 'Exercise',
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
    assignedById: string;
  }): Promise<StoredWorkoutAssignment[]> {
    const { sessionId, assignmentType, clientIds = [], individualClientId, isRecommended = false, assignedById } = params;
    const results: StoredWorkoutAssignment[] = [];
    const now = new Date().toISOString();

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
      const inMemoryKey = `assign_${sessionId}_${targetId || 'all'}`;
      const memAssignment: StoredWorkoutAssignment = {
        id: inMemoryKey,
        sessionId,
        clientId: targetId,
        isRecommended,
        assignedById: resolvedAdminId,
        assignedAt: now,
        active: true,
      };
      this.assignments.set(inMemoryKey, memAssignment);

      try {
        const existing = await prisma.workoutAssignment.findFirst({
          where: { sessionId, clientId: targetId },
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

  // --- Client Operations (Strictly Scoped) ---
  async getClientAuthorizedSessions(clientId: string): Promise<{
    recommended: (StoredWorkoutSession & { isRecommended: boolean }) | null;
    available: StoredWorkoutSession[];
  }> {
    await this.ensureDatabaseSeeded();
    const resolvedUserId = await this.resolveUserId(clientId);

    try {
      // 1. Query client-specific assignments first
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

      if (clientSpecificAssignments.length > 0) {
        const available: (StoredWorkoutSession & { isRecommended: boolean })[] = [];
        for (const a of clientSpecificAssignments) {
          if (a.session && a.session.isActive) {
            available.push({
              ...mapPrismaSessionToStored(a.session),
              isRecommended: a.isRecommended,
            });
          }
        }

        if (available.length > 0) {
          // If a session is marked recommended, use it; otherwise use the most recently assigned session
          const recItem = available.find((s) => s.isRecommended) || available[0];
          return this.applyActiveSetOverlays({
            recommended: recItem ? { ...recItem, isRecommended: true } : null,
            available,
          }, resolvedUserId);
        }
      }

      // 2. If NO client-specific assignments exist, check if there are explicit ALL assignments
      // but DO NOT set recommended unless explicitly designated
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

      if (allAssignments.length > 0) {
        const available: (StoredWorkoutSession & { isRecommended: boolean })[] = [];
        for (const a of allAssignments) {
          if (a.session && a.session.isActive) {
            available.push({
              ...mapPrismaSessionToStored(a.session),
              isRecommended: false,
            });
          }
        }
        // If client has NO assigned workout, recommended MUST be null so the empty state is shown
        return this.applyActiveSetOverlays({
          recommended: null,
          available,
        }, resolvedUserId);
      }

      return {
        recommended: null,
        available: [],
      };
    } catch (e: any) {
      console.warn('[WorkoutRepository] Failed to query client sessions from DB, falling back to cache:', e?.message);
    }

    // In-memory fallback: strictly prioritize client-specific assignments
    const activeSessions = Array.from(this.sessions.values()).filter((s) => s.isActive);
    const clientSpecificAssignments = Array.from(this.assignments.values())
      .filter((a) => a.active && (a.clientId === resolvedUserId || a.clientId === clientId))
      .sort((a, b) => {
        if (a.isRecommended && !b.isRecommended) return -1;
        if (!a.isRecommended && b.isRecommended) return 1;
        return b.assignedAt.localeCompare(a.assignedAt);
      });

    if (clientSpecificAssignments.length > 0) {
      const authorizedSessionIds = new Set(clientSpecificAssignments.map((a) => a.sessionId));
      const authorizedSessions = activeSessions
        .filter((s) => authorizedSessionIds.has(s.id))
        .map((s) => {
          const assign = clientSpecificAssignments.find((a) => a.sessionId === s.id);
          return {
            ...s,
            isRecommended: assign?.isRecommended ?? false,
          };
        });

      const recAssign = clientSpecificAssignments.find((a) => a.isRecommended) || clientSpecificAssignments[0];
      const recSession = authorizedSessions.find((s) => s.id === recAssign.sessionId);

      return this.applyActiveSetOverlays({
        recommended: recSession ? { ...recSession, isRecommended: true } : null,
        available: authorizedSessions,
      }, resolvedUserId);
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
    const id = `rec_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const now = new Date().toISOString();

    const memRecord: StoredWorkoutRecord = {
      ...data,
      id,
      clientId: resolvedUserId,
      createdAt: now,
      updatedAt: now,
    };
    this.records.set(id, memRecord);

    try {
      const created = await prisma.workoutRecord.create({
        data: {
          clientId: resolvedUserId,
          sessionId: data.sessionId || null,
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
        const candidateIds = this.resolveSessionCandidateIds(data.sessionId);
        try {
          await prisma.workoutRecord.deleteMany({
            where: {
              clientId: resolvedUserId,
              sessionId: { in: candidateIds },
              isCompleted: false,
            },
          });
        } catch (_) {}
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
      if (data.sessionId) {
        const candidateIds = this.resolveSessionCandidateIds(data.sessionId);
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

    // 1. In-memory update for instant availability and test support
    const completedAtStr = payload.isCompleted ? new Date().toISOString() : null;
    for (const sid of candidateIds) {
      const key = `${resolvedUserId}_${sid}_${payload.exerciseId}_${payload.setNumber}`;
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
    const sessionEx = session?.exercises.find((e) => e.id === payload.exerciseId || e.exerciseId === payload.exerciseId);
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
        // Find or create in-progress workout record
        let activeRecord = await prisma.workoutRecord.findFirst({
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

    // In-memory fallback
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

  private async applyActiveSetOverlays(
    result: { recommended: (StoredWorkoutSession & { isRecommended: boolean }) | null; available: StoredWorkoutSession[] },
    clientId: string
  ): Promise<{ recommended: (StoredWorkoutSession & { isRecommended: boolean }) | null; available: StoredWorkoutSession[] }> {
    const overlaidAvailable: StoredWorkoutSession[] = [];
    for (const s of result.available) {
      overlaidAvailable.push(await this.overlayActiveSetsOnSession(s, clientId));
    }
    let overlaidRec: (StoredWorkoutSession & { isRecommended: boolean }) | null = null;
    if (result.recommended) {
      const baseRec = await this.overlayActiveSetsOnSession(result.recommended, clientId);
      overlaidRec = { ...baseRec, isRecommended: result.recommended.isRecommended };
    }
    return {
      recommended: overlaidRec,
      available: overlaidAvailable,
    };
  }
}

export const workoutRepository = new WorkoutRepository();
