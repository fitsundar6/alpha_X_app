import express, { Router } from 'express';
import { foodPhotoController } from './food.photo.controller';
import { requireAuth, requireAdmin } from '../../middlewares/auth';

const router = Router();

// 1. Client Live Camera Food Photo Recording (strictly live capture, no food log injection)
router.post('/live', requireAuth, express.json({ limit: '10mb' }), (req, res) => foodPhotoController.recordLiveFoodPhoto(req, res));
router.post('/', requireAuth, express.json({ limit: '10mb' }), (req, res) => foodPhotoController.recordLiveFoodPhoto(req, res));

// 2. Client Food Photo History
router.get('/my-photos', requireAuth, (req, res) => foodPhotoController.getClientFoodPhotos(req, res));
router.get('/client/history', requireAuth, (req, res) => foodPhotoController.getClientFoodPhotos(req, res));

// 3. Admin Food Photo Monitoring Dashboard
router.get('/admin/monitoring', requireAuth, requireAdmin, (req, res) => foodPhotoController.getAdminFoodPhotosMonitoring(req, res));
router.get('/monitoring', requireAuth, requireAdmin, (req, res) => foodPhotoController.getAdminFoodPhotosMonitoring(req, res));

// 4. Admin Verification (Verified / Needs Attention)
router.patch('/:id/verify', requireAuth, requireAdmin, (req, res) => foodPhotoController.adminVerifyFoodPhoto(req, res));
router.post('/:id/verify', requireAuth, requireAdmin, (req, res) => foodPhotoController.adminVerifyFoodPhoto(req, res));

// 5. Automatic 15-Day Storage Cleanup (Admin-triggered or health check)
router.post('/cleanup', requireAuth, requireAdmin, (req, res) => foodPhotoController.triggerCleanup(req, res));
router.get('/cleanup/stats', requireAuth, requireAdmin, (req, res) => foodPhotoController.getCleanupStats(req, res));

// 6. Endpoint for retrieving photo metadata (Auth required)
router.get('/:id', requireAuth, (req, res) => foodPhotoController.getMealPhotoMetadata(req, res));

// 7. Endpoint for streaming photo binary securely (Standard Authorization Bearer required)
router.get('/:id/image', requireAuth, (req, res) => foodPhotoController.streamMealPhotoImage(req, res));
router.get('/:id/file', requireAuth, (req, res) => foodPhotoController.streamMealPhotoImage(req, res));

// 8. Delete photo
router.delete('/:id', requireAuth, (req, res) => foodPhotoController.deleteMealPhoto(req, res));

export const foodPhotoRoutes = router;
