const express = require('express');
const router  = express.Router({ mergeParams: true }); // pour accéder à :inspectionId
const multer  = require('multer');
const path    = require('path');
const fs      = require('fs');
const db      = require('../Config/Db');
const { authMiddleware, requireRole } = require('../middleware/Auth');

router.use(authMiddleware, requireRole('Inspector'));

/**
 * @swagger
 * tags:
 *   name: InspectionImages
 *   description: Gestion des images d'inspection
 */
 
const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const MAX_IMAGES    = 5;
const MIN_IMAGES    = 2;

// Configuration Multer (stockage sur disque)
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const dir = path.join(process.env.UPLOAD_DIR || 'uploads/inspections', req.params.inspectionId);
    fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
    cb(null, `${Date.now()}-${Math.random().toString(36).slice(2)}${ext}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
  fileFilter: (req, file, cb) => {
    if (ALLOWED_TYPES.includes(file.mimetype)) cb(null, true);
    else cb(new Error(`Type non autorisé : ${file.mimetype}. Formats acceptés : jpeg, png, webp.`));
  },
});


/**
 * @swagger
 * /api/inspection/{inspectionId}/images:
 *   post:
 *     summary: Uploader 2 à 5 images pour une inspection
 *     tags: [InspectionImages]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: inspectionId
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID de l'inspection
 *       - in: query
 *         name: imageType
 *         schema:
 *           type: string
 *           enum: [Photo, Screenshot, Document]
 *           default: Photo
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               files:
 *                 type: array
 *                 items:
 *                   type: string
 *                   format: binary
 *                 description: Entre 2 et 5 fichiers (jpeg, png, webp, max 5MB chacun)
 *     responses:
 *       200:
 *         description: Images uploadées avec succès
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:  { type: string }
 *                 count:    { type: integer }
 *                 images:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:        { type: integer }
 *                       imageUrl:  { type: string }
 *                       imageType: { type: string }
 *       400:
 *         description: Nombre d'images invalide ou type non autorisé
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       404:
 *         description: Inspection non trouvée
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
// ─── POST /api/inspection/:inspectionId/images ────────────────────────────────
router.post('/', upload.array('files', MAX_IMAGES), async (req, res) => {
  const { inspectionId } = req.params;
  const files            = req.files;
  const imageType        = req.query.imageType || 'Photo';

  if (!files || files.length < MIN_IMAGES || files.length > MAX_IMAGES) {
    // Supprimer les fichiers uploadés si validation échoue
    files?.forEach(f => fs.unlinkSync(f.path));
    return res.status(400).json({
      message: `Envoyez entre ${MIN_IMAGES} et ${MAX_IMAGES} images.`,
    });
  }

  try {
    // Vérifier que l'inspection existe
    const [inspections] = await db.query(
      'SELECT id FROM inspections WHERE id = ?', [inspectionId]
    );
    if (inspections.length === 0) {
      files.forEach(f => fs.unlinkSync(f.path));
      return res.status(404).json({ message: `Inspection introuvable : ${inspectionId}` });
    }

    // Vérifier le total d'images
    const [countRows] = await db.query(
      'SELECT COUNT(*) AS cnt FROM inspection_images WHERE inspection_id = ?', [inspectionId]
    );
    const existing = countRows[0].cnt;
    if (existing + files.length > MAX_IMAGES) {
      files.forEach(f => fs.unlinkSync(f.path));
      return res.status(400).json({
        message: `Cette inspection a déjà ${existing} image(s). Maximum autorisé : ${MAX_IMAGES}.`,
      });
    }

    const baseUrl = process.env.BASE_URL || 'http://localhost:8080';
    const saved   = [];

    for (const file of files) {
      const imageUrl = `${baseUrl}/uploads/inspections/${inspectionId}/${file.filename}`;
      const [result] = await db.query(
        `INSERT INTO inspection_images (inspection_id, image_url, image_type) VALUES (?, ?, ?)`,
        [inspectionId, imageUrl, imageType]
      );
      saved.push({ id: result.insertId, imageUrl, imageType });
    }

    return res.json({
      message: 'Images uploadées avec succès',
      count:   saved.length,
      images:  saved,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Erreur lors du stockage des fichiers.' });
  }
});


/**
 * @swagger
 * /api/inspection/{inspectionId}/images:
 *   get:
 *     summary: Récupérer toutes les images d'une inspection
 *     tags: [InspectionImages]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: inspectionId
 *         required: true
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Liste des images
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 type: object
 *                 properties:
 *                   id:            { type: integer }
 *                   inspection_id: { type: integer }
 *                   image_url:     { type: string }
 *                   image_type:    { type: string }
 *                   created_at:    { type: string, format: date-time }
 *       404:
 *         description: Inspection non trouvée
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */

// ─── GET /api/inspection/:inspectionId/images ─────────────────────────────────
router.get('/', async (req, res) => {
  const { inspectionId } = req.params;
  try {
    const [inspections] = await db.query(
      'SELECT id FROM inspections WHERE id = ?', [inspectionId]
    );
    if (inspections.length === 0)
      return res.status(404).json({ message: `Inspection introuvable : ${inspectionId}` });

    const [images] = await db.query(
      'SELECT * FROM inspection_images WHERE inspection_id = ? ORDER BY created_at ASC',
      [inspectionId]
    );
    return res.json(images);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Erreur serveur' });
  }
});


/**
 * @swagger
 * /api/inspection/{inspectionId}/images/{imageId}:
 *   delete:
 *     summary: Supprimer une image d'inspection
 *     tags: [InspectionImages]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: inspectionId
 *         required: true
 *         schema:
 *           type: integer
 *       - in: path
 *         name: imageId
 *         required: true
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Image supprimée avec succès
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message: { type: string }
 *       404:
 *         description: Image non trouvée
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
// ─── DELETE /api/inspection/:inspectionId/images/:imageId ─────────────────────
router.delete('/:imageId', async (req, res) => {
  const { imageId } = req.params;
  try {
    const [rows] = await db.query(
      'SELECT * FROM inspection_images WHERE id = ?', [imageId]
    );
    if (rows.length === 0)
      return res.status(404).json({ message: `Image introuvable : ${imageId}` });

    const image    = rows[0];
    const filename = image.image_url.split('/').pop();
    const filePath = path.join(
      process.env.UPLOAD_DIR || 'uploads/inspections',
      String(image.inspection_id),
      filename
    );
    try { fs.unlinkSync(filePath); } catch (_) {}

    await db.query('DELETE FROM inspection_images WHERE id = ?', [imageId]);
    return res.json({ message: 'Image supprimée avec succès' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Erreur serveur' });
  }
});

module.exports = router;