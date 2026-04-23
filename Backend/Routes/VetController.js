const express = require('express');
const router  = express.Router();
const db      = require('../Config/Db');
const { authMiddleware, requireRole } = require('../middleware/Auth');

router.use(authMiddleware, requireRole('Veterinarian'));


/**
 * @swagger
 * tags:
 *   name: Veterinarian
 *   description: Endpoints réservés aux vétérinaires
 */
 
/**
 * @swagger
 * /api/vet/scan/{rfidCode}:
 *   get:
 *     summary: Scanner un animal et obtenir sa fiche santé complète
 *     tags: [Veterinarian]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: rfidCode
 *         required: true
 *         schema:
 *           type: string
 *         example: DZ-0007
 *         description: Code RFID de l'animal
 *     responses:
 *       200:
 *         description: Fiche santé de l'animal
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 rfidCode:      { type: string }
 *                 species:       { type: string }
 *                 breed:         { type: string }
 *                 gender:        { type: string }
 *                 lifeStatus:    { type: string }
 *                 healthStatus:  { type: string }
 *                 farmName:      { type: string }
 *                 healthRecords:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:            { type: integer }
 *                       record_type:   { type: string }
 *                       diagnosis:     { type: string }
 *                       treatment_plan: { type: string }
 *                       visit_date:    { type: string, format: date-time }
 *                       first_name:    { type: string }
 *                       last_name:     { type: string }
 *       404:
 *         description: Animal non trouvé
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
// ─── GET /api/vet/scan/:rfidCode ─────────────────────────────────────────────
router.get('/scan/:rfidCode', async (req, res) => {
  const { rfidCode } = req.params;
  try {
    const [animals] = await db.query(
      `SELECT a.*, r.rfid_code, f.name AS farm_name
       FROM animals a
       JOIN rfid_tags r ON r.id = a.rfid_tag_id
       JOIN farms f     ON f.id = a.farm_id
       WHERE r.rfid_code = ?`,
      [rfidCode]
    );
    const animal = animals[0];
    if (!animal)
      return res.status(404).json({ message: `Animal non trouvé avec le tag : ${rfidCode}` });

    const [healthRecords] = await db.query(
      `SELECT hr.*, u.first_name, u.last_name
       FROM health_records hr
       LEFT JOIN users u ON u.id = hr.veterinarian_id
       WHERE hr.animal_id = ?
       ORDER BY hr.visit_date DESC`,
      [animal.id]
    );

    return res.json({
      rfidCode:     animal.rfid_code,
      species:      animal.species,
      breed:        animal.breed,
      gender:       animal.gender,
      lifeStatus:   animal.life_status,
      healthStatus: animal.health_status,
      farmName:     animal.farm_name,
      healthRecords,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Erreur serveur' });
  }
});


/**
 * @swagger
 * /api/vet/health-record:
 *   post:
 *     summary: Ajouter un dossier médical à un animal
 *     tags: [Veterinarian]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/HealthRecordRequest'
 *     responses:
 *       200:
 *         description: Dossier médical ajouté avec succès
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message: { type: string }
 *       400:
 *         description: rfidCode ou recordType manquant
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       404:
 *         description: Animal non trouvé
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
// ─── POST /api/vet/health-record ─────────────────────────────────────────────
router.post('/health-record', async (req, res) => {
  const { rfidCode, recordType, diagnosis, treatmentPlan } = req.body;
  const username = req.user.username;

  if (!rfidCode || !recordType)
    return res.status(400).json({ message: 'rfidCode et recordType sont obligatoires' });

  try {
    // Trouver l'animal
    const [animals] = await db.query(
      `SELECT a.id FROM animals a
       JOIN rfid_tags r ON r.id = a.rfid_tag_id
       WHERE r.rfid_code = ?`,
      [rfidCode]
    );
    if (animals.length === 0)
      return res.status(404).json({ message: 'Animal non trouvé' });

    // Trouver le vétérinaire
    const [vets] = await db.query(
      'SELECT id FROM users WHERE username = ?', [username]
    );

    await db.query(
      `INSERT INTO health_records
         (animal_id, veterinarian_id, record_type, diagnosis, treatment_plan, visit_date)
       VALUES (?, ?, ?, ?, ?, NOW())`,
      [animals[0].id, vets[0].id, recordType, diagnosis || null, treatmentPlan || null]
    );

    return res.json({ message: 'Dossier médical ajouté avec succès' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Erreur serveur' });
  }
});

module.exports = router;