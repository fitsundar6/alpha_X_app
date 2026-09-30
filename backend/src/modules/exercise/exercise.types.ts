export interface ExerciseDto {
  id: string;
  externalId?: string | null;
  name: string;
  normalizedName: string;
  aliases: string[];
  description: string;
  instructions: string[];
  coachingCues: string[];
  commonMistakes: string[];
  primaryMuscles: string[];
  secondaryMuscles: string[];
  bodyPart: string;
  category: string;
  subcategory?: string | null;
  equipment: string;
  movementPattern: string;
  exerciseType: string;
  difficulty: string;
  mechanics: string;
  forceType: string;
  planeOfMotion: string;
  laterality: string;
  isCompound: boolean;
  isIsolation: boolean;
  isUnilateral: boolean;
  imageUrl: string;
  videoUrl: string;
  thumbnailUrl: string;
  gifUrl?: string;
  variations: string[];
  progressions: string[];
  regressions: string[];
  alternativeExercises: string[];
  source: string;
  sourceUrl: string;
  license: string;
  licenseAuthor: string;
  isImported: boolean;
  isCustom: boolean;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface ExerciseSearchParams {
  query?: string;
  category?: string;
  muscle?: string;
  equipment?: string;
  difficulty?: string;
  exerciseType?: string;
  isCompound?: boolean;
  isIsolation?: boolean;
  isUnilateral?: boolean;
  includeArchived?: boolean;
  page?: number;
  limit?: number;
  sort?: 'nameAsc' | 'nameDesc' | 'categoryAsc' | 'updatedAtDesc' | 'relevance';
}

export interface SyncResult {
  source: string;
  totalFound: number;
  importedCount: number;
  updatedCount: number;
  failedCount: number;
  status: 'SUCCESS' | 'PARTIAL' | 'FAILED';
  errorMessage?: string | null;
  lastSync: string;
}

export interface CreateCustomExerciseInput {
  name: string;
  category: string;
  primaryMuscles: string[];
  secondaryMuscles?: string[];
  equipment?: string;
  movementPattern?: string;
  exerciseType?: string;
  difficulty?: string;
  bodyPart?: string;
  description?: string;
  instructions?: string[];
  coachingCues?: string[];
  commonMistakes?: string[];
  aliases?: string[];
  imageUrl?: string;
  videoUrl?: string;
  gifUrl?: string;
  tags?: string[];
}
