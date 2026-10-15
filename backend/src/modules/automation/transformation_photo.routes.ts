import { Router } from 'express';
import { transformationPhotoController } from './transformation_photo.controller';

const router = Router();

// 1. Stream binary image securely (with auth header or ?token=)
router.get('/:milestoneId/:angle', (req, res) => transformationPhotoController.streamTransformationPhoto(req, res));
router.get('/:id', (req, res) => transformationPhotoController.streamTransformationPhoto(req, res));

// 2. Direct upload route
router.post('/upload', (req, res) => transformationPhotoController.uploadTransformationPhoto(req, res));

export const transformationPhotoRoutes = router;
