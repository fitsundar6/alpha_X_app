import express, { Router } from 'express';
import { transformationPhotoController } from './transformation_photo.controller';
import { requireAuth } from '../../middlewares/auth';

const router = Router();

// 1. Stream binary image securely (with auth header or ?token=)
router.get('/:milestoneId/:angle', (req, res) => transformationPhotoController.streamTransformationPhoto(req, res));
router.get('/:id', (req, res) => transformationPhotoController.streamTransformationPhoto(req, res));

// 2. Direct upload route
router.post('/upload', requireAuth, express.json({ limit: '10mb' }), (req, res) => transformationPhotoController.uploadTransformationPhoto(req, res));

export const transformationPhotoRoutes = router;
