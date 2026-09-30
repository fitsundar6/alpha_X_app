import { Router } from 'express';
import { requireAuth, requireRoles } from '../../middlewares/auth';
import { UserRole } from '../../constants/roles';
import { exerciseController } from './exercise.controller';

const router = Router();

// ==========================================
// PUBLIC / AUTHENTICATED EXERCISE ACCESS
// (Both ADMIN and CLIENT can search and view exercises)
// ==========================================
router.use(requireAuth);

// ==========================================
// ADMIN EXERCISE MANAGEMENT ROUTES
// (Only ADMIN role can sync, create, edit, archive)
// ==========================================
const adminRouter = Router();
adminRouter.use(requireRoles([UserRole.ADMIN]));

adminRouter.post('/', (req, res) => exerciseController.createCustomExercise(req, res));
adminRouter.put('/:id', (req, res) => exerciseController.updateExercise(req, res));
adminRouter.delete('/:id', (req, res) => exerciseController.archiveExercise(req, res));
adminRouter.patch('/:id/restore', (req, res) => exerciseController.restoreExercise(req, res));
adminRouter.post('/sync/trigger', (req, res) => exerciseController.syncExercises(req, res));
adminRouter.get('/sync/status', (req, res) => exerciseController.getSyncStatus(req, res));

router.use('/admin', adminRouter);

// ==========================================
// PUBLIC / AUTHENTICATED EXERCISE ACCESS
// (Both ADMIN and CLIENT can search and view exercises)
// ==========================================
router.post('/seed', (req, res) => exerciseController.seedDatabase(req, res));
router.get('/', (req, res) => exerciseController.searchExercises(req, res));
router.get('/attribution', (req, res) => exerciseController.getAttributionInfo(req, res));
router.get('/:id', (req, res) => exerciseController.getExerciseById(req, res));
router.get('/:id/alternatives', (req, res) => exerciseController.getAlternatives(req, res));

export const exerciseRoutes = router;
