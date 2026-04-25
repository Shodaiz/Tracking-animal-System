const express = require('express');
const router  = express.Router();
const db      = require('../Config/Db');
const { authMiddleware, requireRole } = require('../middleware/Auth');

router.use(authMiddleware, requireRole('Inspector'));


/**
 * @swagger
 * tags:
 *   name: Inspection
 *   description: Endpoints réservés aux inspecteurs et administrateurs
 */
 
/**
 * @swagger
 * /api/inspection/declare:
 *   post:
 *     summary: Créer une nouvelle inspection
 *     tags: [Inspection]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/InspectionRequest'
 *     responses:
 *       200:
 *         description: Inspection déclarée avec succès
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:      { type: string }
 *                 inspectionId: { type: integer }
 *       400:
 *         description: Description manquante
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
// ─── POST /api/inspection/declare ────────────────────────────────────────────
router.post('/declare', async (req, res) => {
  const { description, constatType, result, animalId } = req.body;
  const username = req.user.username;

  if (!description || description.trim() === '')
    return res.status(400).json({ message: 'La description est obligatoire' });

  try {
    const [users] = await db.query('SELECT id FROM users WHERE username = ?', [username]);
    const inspector = users[0];

    const [ins] = await db.query(
      `INSERT INTO inspections
         (inspector_id, animal_id, description, constat_type, result, status, inspection_date)
       VALUES (?, ?, ?, ?, ?, 'Pending', NOW())`,
      [
        inspector.id,
        animalId || null,
        description,
        constatType || 'General',
        result || 'Pending',
      ]
    );

    return res.json({
      message:      'Inspection déclarée avec succès',
      inspectionId: ins.insertId,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Erreur serveur' });
  }
});


/**
 * @swagger
 * /api/inspection/list:
 *   get:
 *     summary: Lister toutes les inspections
 *     tags: [Inspection]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Liste des inspections
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 type: object
 *                 properties:
 *                   id:              { type: integer }
 *                   description:     { type: string }
 *                   constat_type:    { type: string }
 *                   result:          { type: string }
 *                   status:          { type: string }
 *                   inspection_date: { type: string, format: date-time }
 *                   first_name:      { type: string }
 *                   last_name:       { type: string }
 */
// ─── GET /api/inspection/list ─────────────────────────────────────────────────
router.get('/list', async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT i.*, u.first_name, u.last_name
       FROM inspections i
       JOIN users u ON u.id = i.inspector_id
       ORDER BY i.created_at DESC`
    );
    return res.json(rows);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Erreur serveur' });
  }
});


/**
 * @swagger
 * /api/inspection/my:
 *   get:
 *     summary: Lister mes inspections (inspecteur connecté)
 *     tags: [Inspection]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Liste des inspections de l'inspecteur connecté
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 type: object
 *                 properties:
 *                   id:              { type: integer }
 *                   description:     { type: string }
 *                   result:          { type: string }
 *                   status:          { type: string }
 *                   inspection_date: { type: string, format: date-time }
 */
// ─── GET /api/inspection/my ───────────────────────────────────────────────────
router.get('/my', async (req, res) => {
  const username = req.user.username;
  try {
    const [users] = await db.query('SELECT id FROM users WHERE username = ?', [username]);
    const [rows]  = await db.query(
      'SELECT * FROM inspections WHERE inspector_id = ? ORDER BY created_at DESC',
      [users[0].id]
    );
    return res.json(rows);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Erreur serveur' });
  }
});

// ─── POST /api/inspection/verify-scan ────────────────────────────────────────
router.post('/verify-scan', async (req, res) => {
  const { farmId, scannedTags } = req.body;

  if (!farmId || !Array.isArray(scannedTags))
    return res.status(400).json({ message: 'farmId et scannedTags (array) requis' });

  try {
    const [farms] = await db.query('SELECT * FROM farms WHERE id = ?', [farmId]);
    if (farms.length === 0)
      return res.status(404).json({ message: 'Ferme non trouvée' });

    const farm = farms[0];

    // Tags enregistrés dans la BD pour cette ferme
    const [animals] = await db.query(
      `SELECT r.rfid_code
       FROM animals a
       JOIN rfid_tags r ON r.id = a.rfid_tag_id
       WHERE a.farm_id = ?`,
      [farmId]
    );
    const registeredCodes = animals.map(a => a.rfid_code);

    const unknownTags = scannedTags.filter(t => !registeredCodes.includes(t));
    const missingTags = registeredCodes.filter(t => !scannedTags.includes(t));

    return res.json({
      farmName:        farm.name,
      registeredCount: registeredCodes.length,
      scannedCount:    scannedTags.length,
      difference:      registeredCodes.length - scannedTags.length,
      unknownTags,
      missingTags,
      isConsistent:    unknownTags.length === 0 && missingTags.length === 0,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Erreur serveur' });
  }
});

module.exports = router;