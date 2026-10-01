import { Router } from 'express';
import { foodPhotoController } from './food.photo.controller';

const router = Router();

// Endpoint for retrieving photo metadata (Auth required)
router.get('/:id', (req, res) => foodPhotoController.getMealPhotoMetadata(req, res));

// Endpoint for streaming photo binary securely (Auth via header or ?token=)
router.get('/:id/image', (req, res) => foodPhotoController.streamMealPhotoImage(req, res));
router.get('/:id/file', (req, res) => foodPhotoController.streamMealPhotoImage(req, res));

export const foodPhotoRoutes = router;
