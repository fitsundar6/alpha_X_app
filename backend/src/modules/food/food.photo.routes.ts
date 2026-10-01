import { Router } from 'express';
import { foodPhotoController } from './food.photo.controller';

const router = Router();

// 1. Client Live Camera Food Photo Recording (strictly live capture, no food log injection)
router.post('/live', (req, res) => foodPhotoController.recordLiveFoodPhoto(req, res));
router.post('/', (req, res) => foodPhotoController.recordLiveFoodPhoto(req, res));

// 2. Client Food Photo History
router.get('/my-photos', (req, res) => foodPhotoController.getClientFoodPhotos(req, res));
router.get('/client/history', (req, res) => foodPhotoController.getClientFoodPhotos(req, res));

// 3. Admin Food Photo Monitoring Dashboard
router.get('/admin/monitoring', (req, res) => foodPhotoController.getAdminFoodPhotosMonitoring(req, res));
router.get('/monitoring', (req, res) => foodPhotoController.getAdminFoodPhotosMonitoring(req, res));

// 4. Admin Verification (Verified / Needs Attention)
router.patch('/:id/verify', (req, res) => foodPhotoController.adminVerifyFoodPhoto(req, res));
router.post('/:id/verify', (req, res) => foodPhotoController.adminVerifyFoodPhoto(req, res));

// 5. Endpoint for retrieving photo metadata (Auth required)
router.get('/:id', (req, res) => foodPhotoController.getMealPhotoMetadata(req, res));

// 6. Endpoint for streaming photo binary securely (Auth via header or ?token=)
router.get('/:id/image', (req, res) => foodPhotoController.streamMealPhotoImage(req, res));
router.get('/:id/file', (req, res) => foodPhotoController.streamMealPhotoImage(req, res));

// 7. Delete photo
router.delete('/:id', (req, res) => foodPhotoController.deleteMealPhoto(req, res));

export const foodPhotoRoutes = router;
