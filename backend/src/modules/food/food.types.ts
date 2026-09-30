export interface FoodDto {
  id: string;
  name: string;
  normalizedName: string;
  category: string;
  servingSize: number;
  servingUnit: string;
  calories: number;
  protein: number;
  carbohydrates: number;
  fat: number;
  fiber: number;
  sugar?: number;
  sodium?: number;
  source: string; // 'SYSTEM' | 'USDA' | 'USER'
  sourceId?: string | null;
  isCustom: boolean;
  createdBy?: string | null;
  createdByName?: string | null;
  isPublic: boolean;
  isVerified: boolean;
  status: 'APPROVED' | 'PENDING' | 'REJECTED';
  createdAt: string;
  updatedAt: string;
}

export interface CreateCustomFoodInput {
  name: string;
  category?: string;
  servingSize?: number;
  servingUnit?: string;
  calories?: number;
  protein: number;
  carbohydrates: number;
  fat: number;
  fiber?: number;
  sugar?: number;
  sodium?: number;
  isPublic?: boolean;
}

export interface FoodSearchParams {
  query?: string;
  category?: string;
  source?: string;
  isCustom?: boolean;
  isPublic?: boolean;
  page?: number;
  limit?: number;
}
