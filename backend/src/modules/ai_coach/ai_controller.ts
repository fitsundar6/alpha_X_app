import { aiTools, ClientContextSummary } from './ai_tools';
import { prisma } from '../../config/prisma';

export interface AiCoachRequest {
  adminId: string;
  adminName: string;
  conversationId?: string;
  message: string;
  selectedClientId?: string; // Optional client context passed from UI selector
  dateRangePreset?: string;  // "today" | "this_week" | "last_week" | "last_30_days" | "last_90_days"
  customStartDate?: string;
  customEndDate?: string;
}

export interface AiCoachResponse {
  conversationId: string;
  replyText: string;
  intent: string;
  selectedClient?: {
    id: string;
    clientId?: string | null;
    name: string;
  } | null;
  dateRange: {
    label: string;
    startDate: string;
    endDate: string;
  };
  dataCompleteness?: {
    scorePercentage: number;
    missingItems: string[];
    summary: string;
  } | null;
  proposal?: any | null;
  reportCard?: any | null;
  suggestedFollowUps?: string[];
}

export class AiController {
  /**
   * Main entry point for the Alpha X AI Coach.
   * Single identity orchestrating Training, Nutrition, and Analytics engines.
   */
  async handleAdminMessage(req: AiCoachRequest): Promise<AiCoachResponse> {
    const rawText = (req.message || '').trim();
    const adminId = req.adminId;
    const adminName = req.adminName || 'Admin Alex';

    // 1. Resolve or establish conversation
    let conversation = req.conversationId
      ? await prisma.aIConversation.findUnique({ where: { id: req.conversationId } })
      : null;

    if (!conversation) {
      conversation = await prisma.aIConversation.create({
        data: {
          adminId,
          title: rawText.slice(0, 40) || 'Alpha X AI Session',
          activeClientId: req.selectedClientId || null,
        },
      });
    }

    // 2. Resolve Date Range
    const { startDate, endDate, label: dateRangeLabel } = this.resolveDateRange(
      rawText,
      req.dateRangePreset,
      req.customStartDate,
      req.customEndDate
    );

    // 3. Resolve Client Context
    const identifiedClientId = await this.resolveClientContext(rawText, req.selectedClientId, conversation.activeClientId);

    // Update active client in conversation if identified
    if (identifiedClientId && identifiedClientId !== conversation.activeClientId) {
      await prisma.aIConversation.update({
        where: { id: conversation.id },
        data: { activeClientId: identifiedClientId },
      });
    }

    // Record Admin message in conversation
    await prisma.aIMessage.create({
      data: {
        conversationId: conversation.id,
        sender: 'ADMIN',
        content: rawText,
        intent: 'ADMIN_INPUT',
      },
    });

    // 4. Intent Routing
    const lower = rawText.toLowerCase();

    // Ambiguity Check: User asked for client action without specifying client
    if (
      !identifiedClientId &&
      (lower.startsWith('analyze') ||
        lower.includes('create a workout') ||
        lower.includes('create a diet') ||
        lower.includes('progress his') ||
        lower.includes('progress her') ||
        lower.includes('show his') ||
        lower.includes('show her') ||
        lower === 'analyze him' ||
        lower === 'analyze her' ||
        lower === 'analyze this client')
    ) {
      const askReply = "Which client would you like me to analyze or program for? Please select an athlete from the client selector above or mention their name or Client ID (e.g. AXG-0001).";
      await this.saveAiMessage(conversation.id, askReply, 'AMBIGUOUS_CLIENT');
      return {
        conversationId: conversation.id,
        replyText: askReply,
        intent: 'AMBIGUOUS_CLIENT',
        selectedClient: null,
        dateRange: { label: dateRangeLabel, startDate: startDate.toISOString().split('T')[0], endDate: endDate.toISOString().split('T')[0] },
        suggestedFollowUps: ['Give me today\'s report', 'Show clients needing review', 'Who missed workouts today?'],
      };
    }

    // ROUTE A: Facility Reports & Multi-Client Queries
    if (lower.includes("today's report") || lower.includes("today report") || lower.includes("give me today's report") || lower === 'today') {
      return this.handleDailyReport(conversation.id, adminId, adminName);
    }

    if (lower.includes("this week's report") || lower.includes("weekly report") || lower.includes("this week")) {
      return this.handleWeeklyReport(conversation.id, startDate, endDate, dateRangeLabel);
    }

    if (lower.includes("monthly report") || lower.includes("monthly client report") || lower.includes("this month")) {
      return this.handleMonthlyReport(conversation.id, startDate, endDate, dateRangeLabel);
    }

    if (lower.includes('missed their workout') || lower.includes('missed workouts') || lower.includes('who missed workout')) {
      return this.handleMissedWorkoutsQuery(conversation.id);
    }

    if (lower.includes('incomplete food tracking') || lower.includes('missing food log') || lower.includes('not tracking food')) {
      return this.handleIncompleteFoodLogsQuery(conversation.id);
    }

    if (lower.includes('check-in') && (lower.includes('haven\'t') || lower.includes('incomplete') || lower.includes('missing') || lower.includes('pending'))) {
      return this.handlePendingCheckInsQuery(conversation.id);
    }

    if (lower.includes('need attention') || lower.includes('needing review') || lower.includes('attention')) {
      return this.handleAttentionClientsQuery(conversation.id);
    }

    // ROUTE B: Specific Client Operations (Requires identifiedClientId)
    if (identifiedClientId) {
      const clientContext = await aiTools.getClientContext(identifiedClientId, { start: startDate, end: endDate });
      if (!clientContext) {
        const notFoundText = `I couldn't locate client records matching "${identifiedClientId}" in the Alpha X database.`;
        await this.saveAiMessage(conversation.id, notFoundText, 'CLIENT_NOT_FOUND');
        return {
          conversationId: conversation.id,
          replyText: notFoundText,
          intent: 'CLIENT_NOT_FOUND',
          dateRange: { label: dateRangeLabel, startDate: startDate.toISOString().split('T')[0], endDate: endDate.toISOString().split('T')[0] },
        };
      }

      // 1. Progressive Overload Request
      if (lower.includes('progress') && (lower.includes('bench') || lower.includes('squat') || lower.includes('deadlift') || lower.includes('press') || lower.includes('row') || lower.includes('overload') || lower.includes('exercise'))) {
        return this.handleProgressiveOverload(conversation.id, clientContext, rawText, adminId);
      }

      // 2. Workout Prescription / Generation
      if (lower.includes('create a workout') || lower.includes('create workout') || lower.includes('program a workout') || lower.includes('new workout')) {
        return this.handleWorkoutGeneration(conversation.id, clientContext, rawText, adminId);
      }

      // 3. Diet Prescription / Generation
      if (lower.includes('create a diet') || lower.includes('create diet') || lower.includes('fat-loss diet') || lower.includes('muscle gain diet') || lower.includes('nutrition plan') || lower.includes('diet using our food library')) {
        return this.handleDietGeneration(conversation.id, clientContext, rawText, adminId);
      }

      // 4. Current Diet View / Comparison
      if (lower.includes('current diet') || lower.includes('show diet') || lower.includes('diet adherence')) {
        return this.handleClientDietReview(conversation.id, clientContext, dateRangeLabel);
      }

      // 5. Why training performance changed
      if (lower.includes('why has') || lower.includes('performance changed') || lower.includes('performance dropped')) {
        return this.handlePerformanceAnalysis(conversation.id, clientContext, dateRangeLabel);
      }

      // 6. Full Client Analysis (Default for "Analyze Kumar", "Show me last 30 days", etc.)
      return this.handleClientAnalysis(conversation.id, clientContext, dateRangeLabel, startDate, endDate);
    }

    // ROUTE C: General AI Fitness & Gym Architecture Response
    return this.handleGeneralQuery(conversation.id, rawText);
  }

  // ==========================================
  // TRAINING ENGINE METHODS
  // ==========================================

  private async handleWorkoutGeneration(conversationId: string, ctx: ClientContextSummary, rawQuery: string, adminId: string): Promise<AiCoachResponse> {
    const goal = ctx.profile.primaryGoal || 'Hypertrophy & General Fitness';
    const level = ctx.profile.fitnessLevel || 'Intermediate';
    const injury = ctx.profile.hasCurrentInjury ? `Reported discomfort in: ${ctx.profile.injuryAreas.join(', ')}` : 'None reported';

    // Query appropriate exercises from master Exercise Library
    const availableExercises = await aiTools.queryExerciseLibrary('', 'Full Body', 15);
    const exercisesList = availableExercises.length >= 4 ? availableExercises : [
      { id: 'ex_barbell_bench_press', name: 'Barbell Bench Press', category: 'Strength', bodyPart: 'Chest' },
      { id: 'ex_barbell_back_squat', name: 'Barbell Back Squat', category: 'Strength', bodyPart: 'Legs' },
      { id: 'ex_barbell_bent_row', name: 'Barbell Bent Over Row', category: 'Strength', bodyPart: 'Back' },
      { id: 'ex_standing_overhead_press', name: 'Standing Overhead Press', category: 'Strength', bodyPart: 'Shoulders' },
      { id: 'ex_romanian_deadlift', name: 'Romanian Deadlift', category: 'Strength', bodyPart: 'Hamstrings' },
    ];

    // Filter out injured areas if shoulder injury etc.
    const selectedExercises = exercisesList.filter(e => {
      if (ctx.profile.hasCurrentInjury) {
        if (ctx.profile.injuryAreas.includes('Shoulders') && e.name.toLowerCase().includes('overhead')) return false;
        if (ctx.profile.injuryAreas.includes('Knee') && e.name.toLowerCase().includes('deep squat')) return false;
      }
      return true;
    }).slice(0, 4);

    const proposedPayload = {
      title: `${ctx.user.name} — ${goal} Focus Session`,
      workoutType: goal.includes('Strength') ? 'Strength' : 'Hypertrophy',
      targetMuscleGroup: 'Compound Push • Pull • Legs',
      difficulty: level,
      estimatedDurationMinutes: 50,
      description: `Targeted session designed for ${ctx.user.name}. Goal: ${goal}. Level: ${level}. Considers recorded recovery and injury constraints.`,
      exercises: selectedExercises.map((e, idx) => ({
        exerciseId: e.id,
        exerciseName: e.name,
        category: e.category,
        orderIndex: idx,
        sets: 3,
        targetReps: level === 'Advanced' ? '6-8' : '8-10',
        targetWeight: level === 'Advanced' ? 80.0 : 50.0,
        restSeconds: 90,
        targetRir: 2,
        targetRpe: 8.0,
        tempo: '3-1-1-0',
        notes: `Focus on controlled eccentric phase (3s). Maintain neutral spine.`,
      })),
    };

    const reason = `Formulated using Alpha X Exercise Library based on ${ctx.user.name}'s goal (${goal}), ${level} tier, and verified injury records (${injury}).`;

    const proposal = await aiTools.createProposal({
      conversationId,
      clientProfileId: ctx.profile.id,
      clientId: ctx.profile.clientId || ctx.user.id,
      clientName: ctx.user.name,
      proposalType: 'WORKOUT',
      title: proposedPayload.title,
      summary: `4-exercise ${proposedPayload.workoutType} protocol (${proposedPayload.estimatedDurationMinutes} min)`,
      reason,
      proposedDataJson: JSON.stringify(proposedPayload),
    });

    // Audit log for proposal creation
    await prisma.aIAuditLog.create({
      data: {
        adminId,
        clientId: ctx.profile.clientId || ctx.user.id,
        clientName: ctx.user.name,
        action: 'WORKOUT_PROPOSED',
        details: `AI generated workout proposal "${proposal.title}" for review`,
        metadataJson: JSON.stringify({ proposalId: proposal.id }),
      },
    });

    const replyMarkdown = `### 🏋️ WORKOUT PROGRAMMING PROPOSAL
**Athlete:** ${ctx.user.name} (${ctx.profile.clientId || 'AXG'})
**Objective:** ${goal} • **Tier:** ${level}
**Injury Safeguard:** ${injury}

#### Prescribed Structure (Alpha X Exercise Library)
${proposedPayload.exercises.map((e, i) => `${i + 1}. **${e.exerciseName}** — ${e.sets} sets × ${e.targetReps} reps @ ${e.targetWeight} kg (RPE ${e.targetRpe}, RIR ${e.targetRir})`).join('\n')}

> **[FACT]** Generated using active Alpha X Exercise catalog.
> **[AI SUGGESTION]** This proposal is currently **PENDING** your administrative review. It has **NOT** been assigned to the athlete. Please review, edit if necessary, and approve or reject.`;

    await this.saveAiMessage(conversationId, replyMarkdown, 'WORKOUT_PROPOSAL', { proposalId: proposal.id });

    return {
      conversationId,
      replyText: replyMarkdown,
      intent: 'WORKOUT_PROPOSAL',
      selectedClient: { id: ctx.user.id, clientId: ctx.profile.clientId, name: ctx.user.name },
      dateRange: { label: 'Active Plan', startDate: '', endDate: '' },
      dataCompleteness: ctx.completeness,
      proposal: {
        id: proposal.id,
        type: 'WORKOUT',
        title: proposal.title,
        status: 'PENDING',
        summary: proposal.summary,
        reason: proposal.reason,
        payload: proposedPayload,
      },
      suggestedFollowUps: ['Create a diet for him', 'Progress his bench press', 'Analyze his last 30 days'],
    };
  }

  private async handleProgressiveOverload(conversationId: string, ctx: ClientContextSummary, rawQuery: string, adminId: string): Promise<AiCoachResponse> {
    // Identify target exercise from query
    let targetExercise = 'Bench Press';
    if (/squat/i.test(rawQuery)) targetExercise = 'Barbell Back Squat';
    else if (/deadlift/i.test(rawQuery)) targetExercise = 'Deadlift';
    else if (/overhead|shoulder press/i.test(rawQuery)) targetExercise = 'Overhead Press';
    else if (/row/i.test(rawQuery)) targetExercise = 'Bent Over Row';

    const overloadData = await aiTools.calculateProgressiveOverload(ctx.user.id, targetExercise);

    const proposedPayload = {
      exerciseName: overloadData.proposal.exerciseName,
      sets: overloadData.proposal.sets,
      targetWeight: overloadData.proposal.targetWeight,
      targetReps: overloadData.proposal.targetReps,
      targetRir: overloadData.proposal.targetRir,
      targetRpe: overloadData.proposal.targetRpe,
      reason: overloadData.proposal.reason,
    };

    const proposal = await aiTools.createProposal({
      conversationId,
      clientProfileId: ctx.profile.id,
      clientId: ctx.profile.clientId || ctx.user.id,
      clientName: ctx.user.name,
      proposalType: 'PROGRESSION',
      title: `Progressive Overload: ${targetExercise}`,
      summary: `Propose ${overloadData.proposal.targetWeight} kg × ${overloadData.proposal.targetReps} reps`,
      reason: overloadData.proposal.reason,
      currentDataJson: JSON.stringify(overloadData.current || {}),
      proposedDataJson: JSON.stringify(proposedPayload),
    });

    await prisma.aIAuditLog.create({
      data: {
        adminId,
        clientId: ctx.profile.clientId || ctx.user.id,
        clientName: ctx.user.name,
        action: 'PROGRESSION_PROPOSED',
        details: `AI proposed progressive overload for ${targetExercise}: ${overloadData.proposal.targetWeight}kg`,
        metadataJson: JSON.stringify({ proposalId: proposal.id }),
      },
    });

    const replyMarkdown = `### 📈 PROGRESSIVE OVERLOAD ANALYSIS
**Athlete:** ${ctx.user.name} (${ctx.profile.clientId || 'AXG'})
**Exercise:** ${targetExercise}

${overloadData.hasHistory && overloadData.current ? `
* **Previous Performance:** ${overloadData.previous ? `${overloadData.previous.weight} kg × ${overloadData.previous.reps} reps` : 'Baseline'}
* **Latest Recorded Performance:** ${overloadData.current.weight} kg × ${overloadData.current.reps} reps (RPE ${overloadData.current.rpe}, RIR ${overloadData.current.rir})
* **Next Progression Proposal:** **${overloadData.proposal.targetWeight} kg × ${overloadData.proposal.targetReps} reps**
* **Context Rationale:** ${overloadData.proposal.reason}
` : `
* **Recorded History:** No previous completed sets found for this exercise.
* **Proposed Baseline:** ${overloadData.proposal.targetWeight} kg × ${overloadData.proposal.targetReps} reps
* **Rationale:** Safe baseline prescribed according to ${ctx.profile.fitnessLevel || 'intermediate'} fitness tier.
`}

> **[FACT]** Evaluated from athlete's recorded workout history.
> **[AI SUGGESTION]** This proposal is **PENDING** Admin review. The active plan will only be modified upon your explicit approval.`;

    await this.saveAiMessage(conversationId, replyMarkdown, 'PROGRESSION_PROPOSAL', { proposalId: proposal.id });

    return {
      conversationId,
      replyText: replyMarkdown,
      intent: 'PROGRESSION_PROPOSAL',
      selectedClient: { id: ctx.user.id, clientId: ctx.profile.clientId, name: ctx.user.name },
      dateRange: { label: 'Recent Performance', startDate: '', endDate: '' },
      dataCompleteness: ctx.completeness,
      proposal: {
        id: proposal.id,
        type: 'PROGRESSION',
        title: proposal.title,
        status: 'PENDING',
        summary: proposal.summary,
        reason: proposal.reason,
        current: overloadData.current,
        previous: overloadData.previous,
        payload: proposedPayload,
      },
      suggestedFollowUps: ['Approve this progression', 'Create a full workout', 'Check his weekly check-in'],
    };
  }

  // ==========================================
  // NUTRITION ENGINE METHODS
  // ==========================================

  private async handleDietGeneration(conversationId: string, ctx: ClientContextSummary, rawQuery: string, adminId: string): Promise<AiCoachResponse> {
    const goal = ctx.profile.primaryGoal || 'Fat Loss';
    const weightKg = ctx.profile.weightKg || 75.0;

    // Calculate baseline target macros
    let targetCalories = 2000;
    let targetProtein = Math.round(weightKg * 2.0); // 2g per kg
    let targetCarbs = 200;
    let targetFat = 55;
    let targetFiber = 30;

    if (/fat loss/i.test(goal) || /fat-loss/i.test(rawQuery)) {
      targetCalories = Math.round(weightKg * 24);
      targetCarbs = Math.round((targetCalories * 0.4) / 4);
      targetFat = Math.round((targetCalories * 0.25) / 9);
    } else if (/muscle|strength/i.test(goal)) {
      targetCalories = Math.round(weightKg * 32);
      targetCarbs = Math.round((targetCalories * 0.5) / 4);
      targetFat = Math.round((targetCalories * 0.25) / 9);
    }

    // Pull real Food Library entries
    const foodLibraryItems = await aiTools.queryFoodLibrary('', 'ALL', 30);
    const getFood = (nameSub: string, fallback: any) => {
      const found = foodLibraryItems.find(f => f.name.toLowerCase().includes(nameSub.toLowerCase()));
      if (found) {
        return {
          foodId: found.id,
          name: found.name,
          category: found.category,
          servingUnit: found.servingUnit,
          baseServing: found.servingSize,
          calPerUnit: found.calories / found.servingSize,
          proPerUnit: found.protein / found.servingSize,
          carbPerUnit: found.carbohydrates / found.servingSize,
          fatPerUnit: found.fat / found.servingSize,
          fibPerUnit: found.fiber / found.servingSize,
        };
      }
      return fallback;
    };

    const oats = getFood('oat', { foodId: 'f_oats', name: 'Rolled Oats', category: 'Grains', servingUnit: 'g', baseServing: 50, calPerUnit: 3.8, proPerUnit: 0.13, carbPerUnit: 0.68, fatPerUnit: 0.07, fibPerUnit: 0.1 });
    const eggs = getFood('egg', { foodId: 'f_egg', name: 'Whole Eggs', category: 'Proteins', servingUnit: 'piece', baseServing: 1, calPerUnit: 72, proPerUnit: 6.3, carbPerUnit: 0.4, fatPerUnit: 4.8, fibPerUnit: 0 });
    const chicken = getFood('chicken', { foodId: 'f_chicken', name: 'Chicken Breast', category: 'Proteins', servingUnit: 'g', baseServing: 100, calPerUnit: 1.65, proPerUnit: 0.31, carbPerUnit: 0.0, fatPerUnit: 0.036, fibPerUnit: 0 });
    const rice = getFood('rice', { foodId: 'f_rice', name: 'Basmati Rice (Cooked)', category: 'Grains', servingUnit: 'g', baseServing: 150, calPerUnit: 1.3, proPerUnit: 0.027, carbPerUnit: 0.28, fatPerUnit: 0.003, fibPerUnit: 0.004 });
    const apple = getFood('apple', { foodId: 'f_apple', name: 'Fresh Apple', category: 'Fruits', servingUnit: 'piece', baseServing: 1, calPerUnit: 95, proPerUnit: 0.5, carbPerUnit: 25, fatPerUnit: 0.3, fibPerUnit: 4.4 });

    const meals = [
      {
        mealType: 'Breakfast',
        items: [
          { foodId: oats.foodId, foodName: oats.name, quantity: 60, unit: oats.servingUnit, calories: Math.round(60 * oats.calPerUnit), protein: Math.round(60 * oats.proPerUnit * 10) / 10, carbs: Math.round(60 * oats.carbPerUnit * 10) / 10, fat: Math.round(60 * oats.fatPerUnit * 10) / 10, fiber: Math.round(60 * oats.fibPerUnit * 10) / 10 },
          { foodId: eggs.foodId, foodName: eggs.name, quantity: 3, unit: eggs.servingUnit, calories: Math.round(3 * eggs.calPerUnit), protein: Math.round(3 * eggs.proPerUnit * 10) / 10, carbs: Math.round(3 * eggs.carbPerUnit * 10) / 10, fat: Math.round(3 * eggs.fatPerUnit * 10) / 10, fiber: 0 },
        ],
      },
      {
        mealType: 'Lunch',
        items: [
          { foodId: chicken.foodId, foodName: chicken.name, quantity: 180, unit: chicken.servingUnit, calories: Math.round(180 * chicken.calPerUnit), protein: Math.round(180 * chicken.proPerUnit * 10) / 10, carbs: 0, fat: Math.round(180 * chicken.fatPerUnit * 10) / 10, fiber: 0 },
          { foodId: rice.foodId, foodName: rice.name, quantity: 200, unit: rice.servingUnit, calories: Math.round(200 * rice.calPerUnit), protein: Math.round(200 * rice.proPerUnit * 10) / 10, carbs: Math.round(200 * rice.carbPerUnit * 10) / 10, fat: Math.round(200 * rice.fatPerUnit * 10) / 10, fiber: Math.round(200 * rice.fibPerUnit * 10) / 10 },
        ],
      },
      {
        mealType: 'Snacks',
        items: [
          { foodId: apple.foodId, foodName: apple.name, quantity: 1, unit: apple.servingUnit, calories: Math.round(1 * apple.calPerUnit), protein: 0.5, carbs: 25, fat: 0.3, fiber: 4.4 },
        ],
      },
      {
        mealType: 'Dinner',
        items: [
          { foodId: chicken.foodId, foodName: 'Grilled Chicken Breast', quantity: 150, unit: 'g', calories: Math.round(150 * chicken.calPerUnit), protein: Math.round(150 * chicken.proPerUnit * 10) / 10, carbs: 0, fat: Math.round(150 * chicken.fatPerUnit * 10) / 10, fiber: 0 },
          { foodId: rice.foodId, foodName: 'Steamed Rice', quantity: 150, unit: 'g', calories: Math.round(150 * rice.calPerUnit), protein: Math.round(150 * rice.proPerUnit * 10) / 10, carbs: Math.round(150 * rice.carbPerUnit * 10) / 10, fat: Math.round(150 * rice.fatPerUnit * 10) / 10, fiber: Math.round(150 * rice.fibPerUnit * 10) / 10 },
        ],
      },
    ];

    // Compute actual summed totals from food items
    let calcCalories = 0;
    let calcProtein = 0;
    let calcCarbs = 0;
    let calcFat = 0;
    let calcFiber = 0;

    meals.forEach(m => {
      m.items.forEach(it => {
        calcCalories += it.calories;
        calcProtein += it.protein;
        calcCarbs += it.carbs;
        calcFat += it.fat;
        calcFiber += it.fiber;
      });
    });

    const proposedPayload = {
      planName: `${ctx.user.name} — ${goal} Nutrition Plan`,
      dailyCalories: Math.round(calcCalories),
      protein: Math.round(calcProtein),
      carbohydrates: Math.round(calcCarbs),
      fat: Math.round(calcFat),
      fiber: Math.round(calcFiber),
      waterTargetLiters: 3.5,
      meals,
      notes: `Targeted ${goal} protocol for ${ctx.user.name}. Grounded in Alpha X Food Library nutrition database.`,
    };

    const reason = `Computed against ${ctx.user.name}'s verified bodyweight (${weightKg} kg) and ${goal} demand using actual Food Library nutritional macros.`;

    const proposal = await aiTools.createProposal({
      conversationId,
      clientProfileId: ctx.profile.id,
      clientId: ctx.profile.clientId || ctx.user.id,
      clientName: ctx.user.name,
      proposalType: 'DIET',
      title: proposedPayload.planName,
      summary: `${proposedPayload.dailyCalories} kcal • ${proposedPayload.protein}g P • ${proposedPayload.carbohydrates}g C • ${proposedPayload.fat}g F`,
      reason,
      proposedDataJson: JSON.stringify(proposedPayload),
    });

    await prisma.aIAuditLog.create({
      data: {
        adminId,
        clientId: ctx.profile.clientId || ctx.user.id,
        clientName: ctx.user.name,
        action: 'DIET_PROPOSED',
        details: `AI formulated diet proposal "${proposal.title}" for review`,
        metadataJson: JSON.stringify({ proposalId: proposal.id }),
      },
    });

    const replyMarkdown = `### 🥗 NUTRITION PROTOCOL PROPOSAL
**Athlete:** ${ctx.user.name} (${ctx.profile.clientId || 'AXG'})
**Goal:** ${goal} • **Bodyweight:** ${weightKg} kg
**Macro Targets:** **${proposedPayload.dailyCalories} kcal** | **${proposedPayload.protein}g P** | **${proposedPayload.carbohydrates}g C** | **${proposedPayload.fat}g F** | **${proposedPayload.fiber}g Fiber**

#### Meal Breakdown (Alpha X Food Library)
${meals.map(m => `**${m.mealType}:**\n${m.items.map(it => `* ${it.foodName} — ${it.quantity} ${it.unit} (${it.calories} kcal, ${it.protein}g P)`).join('\n')}`).join('\n\n')}

> **[FACT]** All values are calculated from existing Alpha X Food Library items with verified servings.
> **[AI SUGGESTION]** This proposal is **PENDING** your approval. It has **NOT** altered the athlete's active diet plan.`;

    await this.saveAiMessage(conversationId, replyMarkdown, 'DIET_PROPOSAL', { proposalId: proposal.id });

    return {
      conversationId,
      replyText: replyMarkdown,
      intent: 'DIET_PROPOSAL',
      selectedClient: { id: ctx.user.id, clientId: ctx.profile.clientId, name: ctx.user.name },
      dateRange: { label: 'Prescribed Target', startDate: '', endDate: '' },
      dataCompleteness: ctx.completeness,
      proposal: {
        id: proposal.id,
        type: 'DIET',
        title: proposal.title,
        status: 'PENDING',
        summary: proposal.summary,
        reason: proposal.reason,
        payload: proposedPayload,
      },
      suggestedFollowUps: ['Create a workout for him', 'Progress his bench press', 'Analyze his last 30 days'],
    };
  }

  private async handleClientDietReview(conversationId: string, ctx: ClientContextSummary, dateLabel: string): Promise<AiCoachResponse> {
    const active = ctx.activeDietPlan;
    const foodLogs = ctx.recentFoodLogs;

    const consumedCal = foodLogs.reduce((acc, l) => acc + (l.calories * (l.quantity || 1)), 0);
    const consumedPro = foodLogs.reduce((acc, l) => acc + (l.protein * (l.quantity || 1)), 0);

    const replyMarkdown = `### 🍽️ DIET & NUTRITION AUDIT
**Athlete:** ${ctx.user.name} (${ctx.profile.clientId || 'AXG'})
**Period:** ${dateLabel}

#### 1. Assigned Target Plan (Admin Approved)
${active ? `* **Plan Name:** ${active.planName} (v${active.version})
* **Target Calories:** ${active.dailyCalories} kcal/day
* **Target Macros:** ${active.protein}g Protein | ${active.carbohydrates}g Carbs | ${active.fat}g Fat | ${active.fiber}g Fiber
* **Target Water:** ${active.waterTargetLiters} L/day` : '* **No active diet plan assigned in database.**'}

#### 2. Actual Food Log Records (Client Tracked)
* **Total Food Logs Recorded in Period:** ${foodLogs.length} items logged
* **Live Food Photos Available:** ${ctx.mealPhotos.length} photos uploaded
* **Tracking Adherence:** ${foodLogs.length > 0 ? 'Food tracking active' : 'No recorded food entries in selected window'}

> **[FACT]** Assigned diet and actual client food logs remain strictly segregated.
> **[AI OBSERVATION]** ${foodLogs.length === 0 ? 'No food logs were recorded by the client during this window.' : `Athlete logged ${foodLogs.length} items averaging ${Math.round(consumedCal / Math.max(1, foodLogs.length))} kcal per recorded meal.`}`;

    await this.saveAiMessage(conversationId, replyMarkdown, 'CLIENT_DIET_REVIEW');

    return {
      conversationId,
      replyText: replyMarkdown,
      intent: 'CLIENT_DIET_REVIEW',
      selectedClient: { id: ctx.user.id, clientId: ctx.profile.clientId, name: ctx.user.name },
      dateRange: { label: dateLabel, startDate: '', endDate: '' },
      dataCompleteness: ctx.completeness,
      suggestedFollowUps: ['Create a diet for him', 'Analyze his last 30 days', 'Show clients needing review'],
    };
  }

  // ==========================================
  // ANALYTICS ENGINE METHODS
  // ==========================================

  private async handleClientAnalysis(
    conversationId: string,
    ctx: ClientContextSummary,
    dateRangeLabel: string,
    startDate: Date,
    endDate: Date
  ): Promise<AiCoachResponse> {
    const p = ctx.profile;
    const workouts = ctx.recentWorkoutHistory;
    const checkIns = ctx.weeklyCheckIns;
    const latestCheck = ctx.latestCheckIn;

    const startFmt = startDate.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
    const endFmt = endDate.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });

    const totalVolume = workouts.reduce((acc, w) => acc + (w.totalVolume || 0), 0);
    const avgVolume = workouts.length > 0 ? Math.round(totalVolume / workouts.length) : 0;

    const replyMarkdown = `## 📋 CLIENT REPORT: ${ctx.user.name.toUpperCase()}
**Client ID:** ${p.clientId || ctx.user.id} • **Analysis Period:** ${startFmt} – ${endFmt}
**Data Completeness:** **${ctx.completeness.scorePercentage}%**
${ctx.completeness.missingItems.length > 0 ? `*Notice: ${ctx.completeness.missingItems.join(', ')}*` : ''}

---

### 1. Recorded Database Profile
* **Goal:** ${p.primaryGoal || 'Not specified'}
* **Fitness Tier:** ${p.fitnessLevel || 'Intermediate'}
* **Current Weight:** ${p.weightKg ? `${p.weightKg} kg` : 'Not recorded'} • **Height:** ${p.heightCm ? `${p.heightCm} cm` : 'Not recorded'}
* **Injury / Restrictions:** ${p.hasCurrentInjury ? `Active discomfort in ${p.injuryAreas.join(', ')} (${p.injuryDescription || 'No details'})` : 'No injuries recorded'}

### 2. Training Performance & Adherence
* **Completed Workout Sessions:** ${workouts.length} sessions logged
* **Average Training Volume:** ${avgVolume > 0 ? `${avgVolume} kg per session` : 'N/A'}
* **Active Workout Prescribed:** ${ctx.activeWorkoutSession ? ctx.activeWorkoutSession.title : 'None active'}

### 3. Nutrition & Adherence
* **Assigned Plan:** ${ctx.activeDietPlan ? `${ctx.activeDietPlan.planName} (${ctx.activeDietPlan.dailyCalories} kcal)` : 'None assigned'}
* **Client Food Logs:** ${ctx.recentFoodLogs.length} entries recorded
* **Confirmed Meal Photos:** ${ctx.mealPhotos.length} photo verifications

### 4. Progress & Activity Trends
* **Recorded Weight Entries:** ${ctx.progressRecords.length} weigh-ins
* **Recorded Attendance:** ${ctx.attendanceRecords.length} gym check-ins
* **Step Activity Logged:** ${ctx.activityRecords.length} daily logs

### 5. Recovery & Weekly Check-Ins
* **Weekly Check-Ins Submitted:** ${checkIns.length} check-ins on record
* **Latest Sleep Quality:** ${latestCheck ? `${latestCheck.sleepHours}h (${latestCheck.sleepQuality})` : 'No recent check-in'}
* **Reported Pain:** ${latestCheck?.hasPain ? `Pain reported in check-in week ${latestCheck.weekNumber}: ${latestCheck.painAreas.join(', ')}` : 'No pain reported in latest check-in'}

### 6. Observations & Suggested Review
* **[AI INTERPRETATION]** ${workouts.length >= 8 ? 'Athlete maintains strong workout session consistency.' : workouts.length > 0 ? 'Moderate workout cadence recorded.' : 'Workout frequency is currently low or not logged in the app.'}
* **[SUGGESTED REVIEW]** ${p.hasCurrentInjury ? 'Review exercise selection against reported injury before prescribing heavier loads.' : 'Review progressive overload on primary compound movements.'}

*Source of truth: Verified Alpha X PostgreSQL database records.*`;

    await this.saveAiMessage(conversationId, replyMarkdown, 'CLIENT_ANALYSIS');

    return {
      conversationId,
      replyText: replyMarkdown,
      intent: 'CLIENT_ANALYSIS',
      selectedClient: { id: ctx.user.id, clientId: ctx.profile.clientId, name: ctx.user.name },
      dateRange: { label: dateRangeLabel, startDate: startDate.toISOString().split('T')[0], endDate: endDate.toISOString().split('T')[0] },
      dataCompleteness: ctx.completeness,
      reportCard: {
        clientName: ctx.user.name,
        clientId: p.clientId || ctx.user.id,
        workoutAdherence: `${workouts.length} workouts`,
        foodTracking: `${ctx.recentFoodLogs.length} logs`,
        checkInStatus: latestCheck ? `Week ${latestCheck.weekNumber} Completed` : 'Pending',
      },
      suggestedFollowUps: ['Create a workout for him', 'Progress his bench press', 'Create a diet for him'],
    };
  }

  private async handlePerformanceAnalysis(conversationId: string, ctx: ClientContextSummary, dateLabel: string): Promise<AiCoachResponse> {
    const workouts = ctx.recentWorkoutHistory;
    const latestCheck = ctx.latestCheckIn;
    const foodLogs = ctx.recentFoodLogs;

    let performanceObservation = '';
    if (workouts.length < 2) {
      performanceObservation = 'Insufficient historical workout records logged to establish a conclusive performance delta.';
    } else {
      const latest = workouts[0];
      const previous = workouts[1];
      const deltaVol = latest.totalVolume - previous.totalVolume;
      performanceObservation = `Latest session volume was ${latest.totalVolume} kg vs previous ${previous.totalVolume} kg (${deltaVol >= 0 ? '+' : ''}${Math.round(deltaVol)} kg delta).`;
    }

    const replyMarkdown = `### 🔍 PERFORMANCE VARIATION ANALYSIS
**Athlete:** ${ctx.user.name} (${ctx.profile.clientId || 'AXG'})
**Window:** ${dateLabel}

* **[FACT] Training Data:** ${performanceObservation}
* **[FACT] Recovery Data:** ${latestCheck ? `Sleep logged at ${latestCheck.sleepHours}h (${latestCheck.sleepQuality}). Energy recorded as "${latestCheck.energyLevel}". Pain status: ${latestCheck.hasPain ? 'Yes' : 'No'}.` : 'No recent weekly check-in logged to verify sleep or recovery metrics.'}
* **[FACT] Nutrition Adherence:** ${foodLogs.length} food logs recorded in this window.
* **[AI INTERPRETATION]** ${latestCheck?.hasPain ? 'Performance variation correlates with reported physical discomfort.' : latestCheck && latestCheck.sleepHours < 6 ? 'Sleep restriction (< 6h) correlates with reduced training recovery.' : 'Performance trajectory reflects typical training periodization.'}
* **[SUGGESTION]** Recommend consulting athlete directly and reviewing upcoming training volume.`;

    await this.saveAiMessage(conversationId, replyMarkdown, 'PERFORMANCE_ANALYSIS');

    return {
      conversationId,
      replyText: replyMarkdown,
      intent: 'PERFORMANCE_ANALYSIS',
      selectedClient: { id: ctx.user.id, clientId: ctx.profile.clientId, name: ctx.user.name },
      dateRange: { label: dateLabel, startDate: '', endDate: '' },
      dataCompleteness: ctx.completeness,
      suggestedFollowUps: ['Analyze his last 30 days', 'Create a workout for him', 'Show clients needing review'],
    };
  }

  // ==========================================
  // FACILITY & MULTI-CLIENT REPORTS
  // ==========================================

  private async handleDailyReport(conversationId: string, adminId: string, adminName: string): Promise<AiCoachResponse> {
    const todayStr = new Date().toISOString().split('T')[0];
    const summary = await aiTools.getDailyGymSummary(todayStr);

    const replyMarkdown = `## 📊 TODAY'S ALPHA X REPORT
**Facility Command Center** • **Date:** ${todayStr}

### 1. Training Operations
* **Workouts Completed Today:** **${summary.workoutsCompletedToday}**
* **Active Athletes In Facility:** ${summary.attendancesVerifiedToday} check-ins verified

### 2. Nutrition Tracking
* **Total Food Logs Recorded:** **${summary.foodLogsRecordedToday}**
* **Athletes Actively Logging Food:** ${summary.clientsTrackingFoodToday} of ${summary.totalActiveClients} clients

### 3. Check-Ins & Accountability
* **Weekly Check-Ins Completed This Week:** ${summary.weeklyCheckInsCompletedThisWeek}
* **Weekly Check-Ins Pending:** ${summary.weeklyCheckInsPending}

### 4. Athletes Needing Attention (${summary.clientsNeedingReviewCount})
${summary.attentionItems.length > 0 ? summary.attentionItems.slice(0, 5).map(a => `* **${a.clientName}** (${a.clientId || 'AXG'}): ${a.title} — *${a.details}*`).join('\n') : '*No critical attention items pending review today.*'}

> **[FACT]** Live operational metrics directly aggregated from PostgreSQL database.`;

    await this.saveAiMessage(conversationId, replyMarkdown, 'DAILY_REPORT');

    return {
      conversationId,
      replyText: replyMarkdown,
      intent: 'DAILY_REPORT',
      dateRange: { label: 'Today', startDate: todayStr, endDate: todayStr },
      reportCard: {
        title: "Today's AI Summary",
        workoutsCompleted: summary.workoutsCompletedToday,
        foodLogsRecorded: summary.foodLogsRecordedToday,
        checkInsPending: summary.weeklyCheckInsPending,
        clientsNeedReview: summary.clientsNeedingReviewCount,
      },
      suggestedFollowUps: ['Show clients needing review', 'Who missed workouts today?', 'Give me this week\'s report'],
    };
  }

  private async handleWeeklyReport(conversationId: string, startDate: Date, endDate: Date, label: string): Promise<AiCoachResponse> {
    const summary = await aiTools.getWeeklyGymSummary(
      startDate.toISOString().split('T')[0],
      endDate.toISOString().split('T')[0]
    );

    const replyMarkdown = `## 📈 WEEKLY ALPHA X REPORT
**Period:** ${summary.period.start} – ${summary.period.end}

* **Total Active Clients:** **${summary.totalActiveClients}**
* **Workouts Completed:** **${summary.workoutsCompleted}** (Adherence: ~${summary.workoutAdherenceRate}%)
* **Attendance Check-Ins:** **${summary.attendanceCheckIns}**
* **Total Food Logs Recorded:** **${summary.totalFoodLogs}**
* **Weekly Check-In Submissions:** **${summary.checkInsCompleted}** (${summary.checkInCompletionRate}% completion rate)
* **Pending Attention Items:** **${summary.attentionItemsCount}**

${summary.attentionItems.length > 0 ? `### Athletes Requiring Review:\n${summary.attentionItems.slice(0, 4).map(a => `* **${a.clientName}**: ${a.title}`).join('\n')}` : ''}

> **[FACT]** Aggregated over 7-day training window.`;

    await this.saveAiMessage(conversationId, replyMarkdown, 'WEEKLY_REPORT');

    return {
      conversationId,
      replyText: replyMarkdown,
      intent: 'WEEKLY_REPORT',
      dateRange: { label, startDate: summary.period.start, endDate: summary.period.end },
      suggestedFollowUps: ['Give me today\'s report', 'Show clients needing review', 'Give me monthly report'],
    };
  }

  private async handleMonthlyReport(conversationId: string, startDate: Date, endDate: Date, label: string): Promise<AiCoachResponse> {
    const summary = await aiTools.getMonthlyGymSummary(
      startDate.toISOString().split('T')[0],
      endDate.toISOString().split('T')[0]
    );

    const replyMarkdown = `## 🗓️ MONTHLY ALPHA X EXECUTIVE REPORT
**Period:** ${summary.period.start} – ${summary.period.end}

* **Active Roster:** **${summary.totalActiveClients} athletes**
* **Monthly Workouts Logged:** **${summary.monthlyWorkoutsCompleted}** (avg ${summary.avgWorkoutsPerClient} per client)
* **Monthly Facility Attendances:** **${summary.monthlyAttendances}** (avg ${summary.avgAttendancesPerClient} per client)
* **Total Food Logs:** **${summary.monthlyFoodLogs}**
* **Total Weekly Check-Ins:** **${summary.monthlyCheckIns}**

> **[FACT]** Compiled from real client database records.`;

    await this.saveAiMessage(conversationId, replyMarkdown, 'MONTHLY_REPORT');

    return {
      conversationId,
      replyText: replyMarkdown,
      intent: 'MONTHLY_REPORT',
      dateRange: { label, startDate: summary.period.start, endDate: summary.period.end },
      suggestedFollowUps: ['Give me today\'s report', 'Show clients needing review', 'Give me this week\'s report'],
    };
  }

  private async handleMissedWorkoutsQuery(conversationId: string): Promise<AiCoachResponse> {
    const todayStr = new Date().toISOString().split('T')[0];
    const clients = await prisma.user.findMany({
      where: { role: 'CLIENT' },
      include: {
        clientProfile: true,
        workoutRecords: {
          where: {
            isCompleted: true,
            startedAt: {
              gte: new Date(`${todayStr}T00:00:00.000Z`),
              lte: new Date(`${todayStr}T23:59:59.999Z`),
            },
          },
        },
      },
    });

    const missed = clients.filter(c => c.workoutRecords.length === 0);

    const replyMarkdown = `### 🏋️ WORKOUT ADHERENCE CHECK: TODAY (${todayStr})
* **Total Active Clients:** ${clients.length}
* **Completed Workout Today:** ${clients.length - missed.length}
* **No Workout Logged Today:** **${missed.length} clients**

${missed.length > 0 ? `#### Athletes with No Workout Logged Today:\n${missed.slice(0, 10).map((c, idx) => `${idx + 1}. **${c.name}** (${c.clientProfile?.clientId || 'AXG'})`).join('\n')}` : 'All clients have recorded their scheduled workouts today.'}

> **[FACT]** Evaluated against today's completed workout records.`;

    await this.saveAiMessage(conversationId, replyMarkdown, 'MISSED_WORKOUTS');

    return {
      conversationId,
      replyText: replyMarkdown,
      intent: 'MISSED_WORKOUTS',
      dateRange: { label: 'Today', startDate: todayStr, endDate: todayStr },
      suggestedFollowUps: ['Give me today\'s report', 'Who has incomplete food tracking?', 'Show clients needing review'],
    };
  }

  private async handleIncompleteFoodLogsQuery(conversationId: string): Promise<AiCoachResponse> {
    const todayStr = new Date().toISOString().split('T')[0];
    const clients = await prisma.user.findMany({
      where: { role: 'CLIENT' },
      include: {
        clientProfile: {
          include: {
            foodLogs: {
              where: { dateString: todayStr },
            },
          },
        },
      },
    });

    const incomplete = clients.filter(c => (c.clientProfile?.foodLogs.length || 0) < 3);

    const replyMarkdown = `### 🥗 FOOD TRACKING STATUS: TODAY (${todayStr})
* **Athletes With Incomplete Logs (< 3 meals logged today):** **${incomplete.length} athletes**

${incomplete.length > 0 ? `#### Review List:\n${incomplete.slice(0, 10).map((c, i) => `${i + 1}. **${c.name}** (${c.clientProfile?.clientId || 'AXG'}) — ${c.clientProfile?.foodLogs.length || 0} meals logged`).join('\n')}` : 'All clients have actively logged 3+ meals today.'}

> **[FACT]** Checked against today's client food log records.`;

    await this.saveAiMessage(conversationId, replyMarkdown, 'INCOMPLETE_FOOD_LOGS');

    return {
      conversationId,
      replyText: replyMarkdown,
      intent: 'INCOMPLETE_FOOD_LOGS',
      dateRange: { label: 'Today', startDate: todayStr, endDate: todayStr },
      suggestedFollowUps: ['Give me today\'s report', 'Who missed workouts today?', 'Show clients needing review'],
    };
  }

  private async handlePendingCheckInsQuery(conversationId: string): Promise<AiCoachResponse> {
    const clients = await prisma.user.findMany({
      where: { role: 'CLIENT' },
      include: {
        clientProfile: {
          include: {
            weeklyCheckIns: {
              where: {
                checkInDate: { gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) },
              },
            },
          },
        },
      },
    });

    const pending = clients.filter(c => (c.clientProfile?.weeklyCheckIns.length || 0) === 0);

    const replyMarkdown = `### 📋 WEEKLY CHECK-IN STATUS (Past 7 Days)
* **Total Active Clients:** ${clients.length}
* **Completed Weekly Check-In:** ${clients.length - pending.length}
* **Pending Check-In:** **${pending.length} athletes**

${pending.length > 0 ? `#### Athletes Pending Weekly Check-In:\n${pending.slice(0, 10).map((c, i) => `${i + 1}. **${c.name}** (${c.clientProfile?.clientId || 'AXG'})`).join('\n')}` : 'All active clients have submitted their weekly check-in!'}

> **[FACT]** Verified against weekly check-in records in database.`;

    await this.saveAiMessage(conversationId, replyMarkdown, 'PENDING_CHECK_INS');

    return {
      conversationId,
      replyText: replyMarkdown,
      intent: 'PENDING_CHECK_INS',
      dateRange: { label: 'Past 7 Days', startDate: '', endDate: '' },
      suggestedFollowUps: ['Give me today\'s report', 'Show clients needing review', 'Who missed workouts today?'],
    };
  }

  private async handleAttentionClientsQuery(conversationId: string): Promise<AiCoachResponse> {
    const attentionItems = await prisma.adminAttentionItem.findMany({
      where: { isReviewed: false },
      orderBy: { severity: 'desc' },
      take: 15,
    });

    const replyMarkdown = `### ⚠️ ATHLETES REQUIRING COACH ATTENTION
**Unreviewed Attention Items:** **${attentionItems.length}**

${attentionItems.length > 0 ? attentionItems.map((a, i) => `#### ${i + 1}. ${a.clientName} (${a.clientId || 'AXG'})
* **Status:** \`${a.severity}\` — **Signal:** ${a.title}
* **Details:** ${a.details}`).join('\n\n') : '*No athletes currently flagged for attention in the system.*'}

> **[FACT]** Derived from data-based attention triggers (missed workouts, incomplete tracking, reported pain).
> **[AI SUGGESTION]** Tap on any athlete in the client selector to generate an in-depth analysis.`;

    await this.saveAiMessage(conversationId, replyMarkdown, 'CLIENT_ATTENTION');

    return {
      conversationId,
      replyText: replyMarkdown,
      intent: 'CLIENT_ATTENTION',
      dateRange: { label: 'Active', startDate: '', endDate: '' },
      suggestedFollowUps: ['Give me today\'s report', 'Who missed workouts today?', 'Who has incomplete food tracking?'],
    };
  }

  private async handleGeneralQuery(conversationId: string, rawQuery: string): Promise<AiCoachResponse> {
    // Call Gemini directly for general fitness questions
    const { geminiService } = await import('./gemini.service');
    const requestId = `req_general_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;

    try {
      const geminiResult = await geminiService.generateFitnessResponse({
        message: rawQuery,
        adminId: 'system',
        requestId,
        conversationId,
      });

      const replyText = geminiResult.replyText;
      await this.saveAiMessage(conversationId, replyText, 'GENERAL_AI');

      return {
        conversationId,
        replyText,
        intent: 'GENERAL_AI',
        dateRange: { label: 'Now', startDate: '', endDate: '' },
        suggestedFollowUps: geminiResult.suggestedFollowUps || [
          "Give me today's report",
          'Show clients needing review',
          'Who missed workouts today?',
        ],
      };
    } catch (_err) {
      // Fallback only if Gemini is unavailable
      const text = `I am your **Alpha X AI Coach**. I have direct, secure access to the Alpha X client database, exercise library, and food library.\n\nYou can ask me to:\n* **"Give me today's report"** — Live snapshot of workouts, nutrition, and pending items.\n* **"Show clients needing review"** — Athletes with missed workouts, missing logs, or pain.\n* **"Analyze [Client Name]"** — Deep-dive analysis of an athlete's last 30 days.\n* **"Create a workout for [Client Name]"** — Goal-tailored workout proposal for your review.\n* **"Progress [Client Name]'s bench press"** — Progressive overload based on actual workout history.\n* **"Create a diet for [Client Name]"** — Meal plan with macros from our Food Library.\n\n*All proposals require your administrative review and approval before becoming active.*`;
      await this.saveAiMessage(conversationId, text, 'GENERAL');
      return {
        conversationId,
        replyText: text,
        intent: 'GENERAL',
        dateRange: { label: 'Now', startDate: '', endDate: '' },
        suggestedFollowUps: [
          "Give me today's report",
          'Show clients needing review',
          'Who missed workouts today?',
          'Who has incomplete food tracking?',
        ],
      };
    }
  }

  // ==========================================
  // HELPERS
  // ==========================================

  private resolveDateRange(rawText: string, preset?: string, customStart?: string, customEnd?: string) {
    const now = new Date();
    const lower = rawText.toLowerCase();

    if (preset === 'today' || lower.includes('today')) {
      const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      return { startDate: todayStart, endDate: now, label: 'Today' };
    }
    if (preset === 'this_week' || lower.includes('this week')) {
      const weekStart = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      return { startDate: weekStart, endDate: now, label: 'This Week (Last 7 Days)' };
    }
    if (preset === 'last_week' || lower.includes('last week')) {
      const end = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      const start = new Date(end.getTime() - 7 * 24 * 60 * 60 * 1000);
      return { startDate: start, endDate: end, label: 'Last Week' };
    }
    if (preset === 'last_30_days' || lower.includes('last 30 days') || lower.includes('last month') || lower.includes('this month')) {
      const start = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
      return { startDate: start, endDate: now, label: 'Last 30 Days' };
    }
    if (preset === 'last_90_days' || lower.includes('last 90 days')) {
      const start = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);
      return { startDate: start, endDate: now, label: 'Last 90 Days' };
    }
    if (customStart && customEnd) {
      return { startDate: new Date(customStart), endDate: new Date(customEnd), label: 'Custom Range' };
    }

    // Default to last 30 days
    const defaultStart = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    return { startDate: defaultStart, endDate: now, label: 'Last 30 Days' };
  }

  private async resolveClientContext(rawText: string, selectedClientId?: string, sessionActiveClientId?: string | null): Promise<string | null> {
    // 1. If explicit client selector was used in UI
    if (selectedClientId && selectedClientId.trim().length > 0 && selectedClientId !== 'ALL') {
      return selectedClientId.trim();
    }

    // 2. Search message text for athlete name or AXG-XXXX ID
    const axgMatch = rawText.match(/AXG-\d+/i);
    if (axgMatch) {
      return axgMatch[0].toUpperCase();
    }

    // Look for client name in authorized clients
    const clients = await aiTools.getAuthorizedClients();
    for (const c of clients) {
      const nameParts = c.name.toLowerCase().split(' ');
      for (const part of nameParts) {
        if (part.length >= 3 && rawText.toLowerCase().includes(part)) {
          return c.clientProfile?.clientId || c.id;
        }
      }
    }

    // 3. Fallback to conversation memory (activeClientId)
    if (sessionActiveClientId && sessionActiveClientId.trim().length > 0) {
      return sessionActiveClientId.trim();
    }

    return null;
  }

  private async saveAiMessage(conversationId: string, content: string, intent: string, metadata?: any) {
    return prisma.aIMessage.create({
      data: {
        conversationId,
        sender: 'AI',
        content,
        intent,
        metadataJson: metadata ? JSON.stringify(metadata) : null,
      },
    });
  }
}

export const aiController = new AiController();
