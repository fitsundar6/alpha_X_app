import { activityRepository, StoredActivityRecord } from './activity.repository';
import { SyncActivityInput } from './activity.validation';
import { AppError } from '../../middlewares/errorHandler';
import { HttpStatus } from '../../constants/httpStatus';

export class ActivityService {
  /**
   * Synchronize activity records for an authenticated client.
   * SECURITY: Strictly enforces that records are bound to the authenticated `clientId`.
   * Client-supplied clientIds in payloads are disregarded.
   */
  async syncClientActivity(
    authenticatedClientId: string,
    input: SyncActivityInput
  ): Promise<{ syncedCount: number; records: StoredActivityRecord[] }> {
    if (!authenticatedClientId) {
      throw new AppError('Authentication required to sync activity', HttpStatus.UNAUTHORIZED);
    }

    const records = await activityRepository.upsertRecords(authenticatedClientId, input.records);
    return {
      syncedCount: records.length,
      records,
    };
  }

  /**
   * Get today's activity record and current goal for an authenticated client.
   */
  async getTodayActivity(clientId: string): Promise<{
    date: string;
    stepGoal: number;
    record: StoredActivityRecord | null;
  }> {
    const today = new Date().toISOString().split('T')[0];
    const stepGoal = await activityRepository.getClientStepGoal(clientId);
    const record = await activityRepository.getRecordByDate(clientId, today);

    return {
      date: today,
      stepGoal,
      record,
    };
  }

  /**
   * Get activity history for an authenticated client.
   */
  async getClientHistory(clientId: string, limit: number = 30): Promise<StoredActivityRecord[]> {
    return activityRepository.getRecords(clientId, limit);
  }

  /**
   * Admin: Inspect assigned client's activity and history.
   */
  async inspectClientActivityAsAdmin(
    _adminId: string,
    targetClientId: string
  ): Promise<{
    clientId: string;
    dailyStepGoal: number;
    todayRecord: StoredActivityRecord | null;
    history: StoredActivityRecord[];
  }> {
    const today = new Date().toISOString().split('T')[0];
    const dailyStepGoal = await activityRepository.getClientStepGoal(targetClientId);
    const todayRecord = await activityRepository.getRecordByDate(targetClientId, today);
    const history = await activityRepository.getRecords(targetClientId, 30);

    return {
      clientId: targetClientId,
      dailyStepGoal,
      todayRecord,
      history,
    };
  }

  /**
   * Admin: Update an individual client's daily step goal.
   * Guarantees that historical step records are preserved and not overwritten.
   */
  async updateClientStepGoal(
    _adminId: string,
    targetClientId: string,
    newGoal: number
  ): Promise<{ clientId: string; dailyStepGoal: number; effectiveDate: string }> {
    if (newGoal < 1000 || newGoal > 50000) {
      throw new AppError('Step goal must be between 1,000 and 50,000', HttpStatus.BAD_REQUEST);
    }

    const updatedGoal = await activityRepository.updateClientStepGoal(targetClientId, newGoal);

    // If today's record exists, update its goal target so today's achievement reflects it
    const today = new Date().toISOString().split('T')[0];
    const todayRecord = await activityRepository.getRecordByDate(targetClientId, today);
    if (todayRecord) {
      await activityRepository.upsertRecords(targetClientId, [
        {
          date: today,
          steps: todayRecord.steps,
          stepGoal: updatedGoal,
          cardioMinutes: todayRecord.cardioMinutes,
          caloriesBurned: todayRecord.caloriesBurned,
          distanceMeters: todayRecord.distanceMeters,
          isGoalAchieved: todayRecord.steps >= updatedGoal,
        },
      ]);
    }

    return {
      clientId: targetClientId,
      dailyStepGoal: updatedGoal,
      effectiveDate: new Date().toISOString(),
    };
  }
}

export const activityService = new ActivityService();
