import { Router } from 'express';
import { requireAuth, requireRoles } from '../../middlewares/auth';
import { UserRole } from '../../constants/roles';
import { workoutController } from './workout.controller';

const router = Router();

// ==========================================
// ADMIN WORKOUT SYSTEM ROUTES (Role: ADMIN only)
// ==========================================
const adminRouter = Router();
adminRouter.use(requireAuth, requireRoles([UserRole.ADMIN]));

// Workout Session Management
adminRouter.get('/sessions', (req, res) => workoutController.getAllAdminSessions(req, res));
adminRouter.post('/sessions', (req, res) => workoutController.createSession(req, res));
adminRouter.get('/sessions/:id', (req, res) => workoutController.getAdminSessionById(req, res));
adminRouter.put('/sessions/:id', (req, res) => workoutController.updateSession(req, res));
adminRouter.post('/sessions/:id/duplicate', (req, res) => workoutController.duplicateSession(req, res));
adminRouter.patch('/sessions/:id/toggle-active', (req, res) => workoutController.toggleActive(req, res));
adminRouter.delete('/sessions/:id', (req, res) => workoutController.deleteSession(req, res));

// Assignment Management
adminRouter.post('/sessions/:id/assign', (req, res) => workoutController.assignSession(req, res));
adminRouter.delete('/assignments/:assignmentId', (req, res) => workoutController.unassign(req, res));

// Client Workout Results Review
adminRouter.get('/clients', (req, res) => workoutController.getClientsList(req, res));
adminRouter.get('/clients/:clientId/workout-history', (req, res) => workoutController.getClientWorkoutResults(req, res));

router.use('/admin', adminRouter);

// ==========================================
// CLIENT WORKOUT SYSTEM ROUTES (Role: CLIENT only)
// ==========================================
const clientRouter = Router();
clientRouter.use(requireAuth, requireRoles([UserRole.CLIENT]));

// Client Session Discovery & Overview
clientRouter.get('/sessions', (req, res) => workoutController.getClientSessions(req, res));
clientRouter.get('/sessions/:id', (req, res) => workoutController.getClientSessionById(req, res));

// Performance Tracking & Recording
clientRouter.get('/previous-performance', (req, res) => workoutController.getPreviousPerformance(req, res));
clientRouter.post('/records', (req, res) => workoutController.recordWorkout(req, res));
clientRouter.get('/history', (req, res) => workoutController.getClientHistory(req, res));
clientRouter.get('/history/:id', (req, res) => workoutController.getWorkoutRecordById(req, res));

router.use('/client', clientRouter);

export const workoutRoutes = router;
