import { Router } from 'express';
import { optionalAuth, requireAuth, requireAdmin } from '../../middlewares/auth';
import { exerciseController } from './exercise.controller';

const router = Router();

// ==========================================
// ADMIN EXERCISE MANAGEMENT ROUTES
// (Only ADMIN role can sync, create, edit, archive)
// ==========================================
const adminRouter = Router();
adminRouter.use(requireAuth, requireAdmin);

adminRouter.post('/', (req, res) => exerciseController.createCustomExercise(req, res));
adminRouter.put('/:id', (req, res) => exerciseController.updateExercise(req, res));
adminRouter.delete('/:id', (req, res) => exerciseController.archiveExercise(req, res));
adminRouter.patch('/:id/restore', (req, res) => exerciseController.restoreExercise(req, res));
adminRouter.post('/sync/trigger', (req, res) => exerciseController.syncExercises(req, res));
adminRouter.get('/sync/status', (req, res) => exerciseController.getSyncStatus(req, res));

router.use('/admin', adminRouter);

// ==========================================
// PUBLIC & ATHLETE EXERCISE ACCESS
// (Exercises can be browsed publicly or personalized when authenticated)
// ==========================================
router.post('/seed', requireAuth, requireAdmin, (req, res) => exerciseController.seedDatabase(req, res));
router.get('/', optionalAuth, (req, res) => exerciseController.searchExercises(req, res));
router.get('/attribution', (req, res) => exerciseController.getAttributionInfo(req, res));
router.get('/:id', optionalAuth, (req, res) => exerciseController.getExerciseById(req, res));
router.get('/:id/alternatives', optionalAuth, (req, res) => exerciseController.getAlternatives(req, res));

export const exerciseRoutes = router;
