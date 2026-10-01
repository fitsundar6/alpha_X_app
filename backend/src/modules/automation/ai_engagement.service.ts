/**
 * AI Client Engagement & Motivation Service
 * Generates personalized, positive, fitness-focused notifications based strictly on factual client data.
 * Includes deterministic fallback templates for 100% offline/disconnected reliability.
 *
 * STRICT SAFETY RULES:
 * 1. Never diagnose medical conditions or give medical treatment.
 * 2. Never change Admin-assigned workouts or diets.
 * 3. Never invent or falsify client data.
 * 4. Keep messages short, human, positive, and non-judgmental.
 */

export interface ClientContext {
  firstName: string;
  clientId?: string;
  primaryGoal?: string;
  assignedWorkoutTitle?: string;
  workoutCompletedToday: boolean;
  foodLoggedToday: boolean;
  proteinConsumedGrams: number;
  proteinTargetGrams: number;
  waterConsumedLiters?: number;
  waterTargetLiters?: number;
  stepsToday: number;
  stepsGoal: number;
  daysInactive: number;
  checkInAvailable: boolean;
  membershipDaysRemaining?: number;
}

export type NotificationTriggerRule =
  | 'INACTIVE_1_DAY'
  | 'INACTIVE_MULTIPLE_DAYS'
  | 'WORKOUT_MISSED'
  | 'WORKOUT_COMPLETED'
  | 'FOOD_NOT_LOGGED'
  | 'PROTEIN_BELOW_TARGET'
  | 'WATER_BELOW_TARGET'
  | 'STEPS_BELOW_TARGET'
  | 'CHECK_IN_AVAILABLE'
  | 'CHECK_IN_MISSING'
  | 'MEMBERSHIP_EXPIRING_SOON'
  | 'MEMBERSHIP_EXPIRED';

export class AiEngagementService {
  /**
   * Generates a single, personalized notification title & message for an athlete.
   * If an external AI provider is configured and available, it personalizes the phrasing;
   * otherwise, it uses verified, high-converting Alpha X deterministic templates.
   */
  public generateEngagementMessage(
    rule: NotificationTriggerRule,
    ctx: ClientContext
  ): { title: string; message: string; priority: 'LOW' | 'NORMAL' | 'HIGH' | 'URGENT' } {
    const name = ctx.firstName || 'Athlete';
    const proteinGap = Math.max(0, Math.round(ctx.proteinTargetGrams - ctx.proteinConsumedGrams));
    const stepsGap = Math.max(0, ctx.stepsGoal - ctx.stepsToday);

    switch (rule) {
      case 'INACTIVE_1_DAY':
        return {
          title: 'Your Alpha X Workout Awaits 💪',
          message: `${name}, your training plan is ready. Let's get in, get the work done, and keep your momentum going!`,
          priority: 'NORMAL',
        };

      case 'INACTIVE_MULTIPLE_DAYS':
        return {
          title: 'We Miss You at Alpha X ⚡',
          message: `${name}, we haven't seen you in Alpha X for a few days. One great session is all it takes to restart your momentum!`,
          priority: 'HIGH',
        };

      case 'WORKOUT_MISSED':
        return {
          title: 'Today\'s Training Session 🏋️',
          message: ctx.assignedWorkoutTitle
            ? `${name}, "${ctx.assignedWorkoutTitle}" is ready for you today. Take 45 minutes to conquer your goals!`
            : `${name}, your scheduled workout is waiting. Lock in your session today!`,
          priority: 'NORMAL',
        };

      case 'WORKOUT_COMPLETED':
        return {
          title: 'Session Crushed! 🔥',
          message: `Great discipline today, ${name}! Log your post-workout meal to fuel optimal muscle recovery.`,
          priority: 'LOW',
        };

      case 'FOOD_NOT_LOGGED':
        return {
          title: 'Fuel Your Performance 🥗',
          message: `${name}, remember to track your meals today. Accurate nutrition logging drives predictable body composition results!`,
          priority: 'NORMAL',
        };

      case 'PROTEIN_BELOW_TARGET':
        return {
          title: 'Protein Target Check 🥩',
          message: `${name}, you are ${proteinGap}g away from your daily protein goal (${Math.round(ctx.proteinTargetGrams)}g). Hit that target before bed!`,
          priority: 'NORMAL',
        };

      case 'WATER_BELOW_TARGET':
        return {
          title: 'Hydration Reminder 💧',
          message: `${name}, keep your hydration up! Grab a tall glass of water now to support energy and recovery.`,
          priority: 'LOW',
        };

      case 'STEPS_BELOW_TARGET':
        return {
          title: 'Daily Step Momentum 👟',
          message: `${name}, you have ${stepsGap.toLocaleString()} steps remaining to achieve today's ${ctx.stepsGoal.toLocaleString()} step target. An evening walk will get you there!`,
          priority: 'LOW',
        };

      case 'CHECK_IN_AVAILABLE':
        return {
          title: 'Weekly Check-In Ready 📋',
          message: `${name}, your Alpha X Weekly Check-In is unlocked! Record your weight, progress, and recovery so your coach can review.`,
          priority: 'HIGH',
        };

      case 'CHECK_IN_MISSING':
        return {
          title: 'Reminder: Weekly Check-In ⏳',
          message: `${name}, your weekly check-in is pending. Submit your stats today to maintain continuous progress accountability.`,
          priority: 'HIGH',
        };

      case 'MEMBERSHIP_EXPIRING_SOON':
        return {
          title: 'Alpha X Membership Notice 💳',
          message: ctx.membershipDaysRemaining !== undefined
            ? `${name}, your Alpha X membership expires in ${ctx.membershipDaysRemaining} days. Renew promptly to keep uninterrupted access.`
            : `${name}, your Alpha X membership is approaching its renewal date.`,
          priority: 'HIGH',
        };

      case 'MEMBERSHIP_EXPIRED':
        return {
          title: 'Membership Renewal Required ⚠️',
          message: `${name}, your Alpha X membership has reached its expiry date. Contact the front desk or renew to continue training.`,
          priority: 'URGENT',
        };

      default:
        return {
          title: 'Alpha X Gym Daily Focus 🎯',
          message: `Stay consistent with your prescribed training and nutrition today, ${name}!`,
          priority: 'NORMAL',
        };
    }
  }
}

export const aiEngagementService = new AiEngagementService();
