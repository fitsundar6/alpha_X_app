import express, { Router } from 'express';
import { transformationPhotoController } from './transformation_photo.controller';
import { requireAuth } from '../../middlewares/auth';

const router = Router();

// 1. Stream binary image securely (Standard Authorization Bearer required)
router.get('/:milestoneId/:angle', requireAuth, (req, res) => transformationPhotoController.streamTransformationPhoto(req, res));
router.get('/:id', requireAuth, (req, res) => transformationPhotoController.streamTransformationPhoto(req, res));

// 2. Direct upload route
router.post('/upload', requireAuth, express.json({ limit: '10mb' }), (req, res) => transformationPhotoController.uploadTransformationPhoto(req, res));

export const transformationPhotoRoutes = router;
