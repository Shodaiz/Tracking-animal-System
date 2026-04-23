const express = require('express');
const router  = express.Router();
const db      = require('../Config/Db');
const { authMiddleware, requireRole } = require('../middleware/Auth');

// Toutes les routes farmer nécessitent auth + rôle Farmer
router.use(authMiddleware, requireRole('Farmer'));


/**
 * @swagger
 * tags:
 *   name: Farmer
 *   description: Endpoints réservés aux agriculteurs
 */
 
/**
 * @swagger
 * /api/farmer/scan/{rfidCode}:
 *   get:
 *     summary: Scanner un animal via son tag RFID
 *     tags: [Farmer]
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
 *         description: Informations de l'animal
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/AnimalScan'
 *       403:
 *         description: Cet animal ne vous appartient pas
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
// ─── GET /api/farmer/scan/:rfidCode ──────────────────────────────────────────
router.get('/scan/:rfidCode', async (req, res) => {
  const { rfidCode } = req.params;
  const username = req.user.username;

  try {
    // Récupérer le farmer connecté
    const [farmers] = await db.query(
      'SELECT * FROM users WHERE username = ?', [username]
    );
    const farmer = farmers[0];
    if (!farmer) return res.status(401).json({ message: 'Non authentifié' });

    // Trouver l'animal via son tag RFID
    const [animals] = await db.query(
      `SELECT a.*, r.rfid_code, f.name AS farm_name, f.location AS farm_location
       FROM animals a
       JOIN rfid_tags r ON r.id = a.rfid_tag_id
       JOIN farms f     ON f.id = a.farm_id
       WHERE r.rfid_code = ?`,
      [rfidCode]
    );
    const animal = animals[0];

    if (!animal)
      return res.status(404).json({ message: `Animal non trouvé avec le tag : ${rfidCode}` });

    // Vérifier que l'animal appartient à ce farmer
    if (animal.owner_id !== farmer.id)
      return res.status(403).json({ message: "Accès refusé : cet animal ne vous appartient pas" });

    return res.json({
      id:           animal.id,
      rfidCode:     animal.rfid_code,
      species:      animal.species,
      breed:        animal.breed,
      gender:       animal.gender,
      lifeStatus:   animal.life_status,
      healthStatus: animal.health_status,
      farmName:     animal.farm_name,
      farmLocation: animal.farm_location,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Erreur serveur' });
  }
});


/**
 * @swagger
 * /api/farmer/animals:
 *   get:
 *     summary: Liste tous les animaux du farmer connecté
 *     tags: [Farmer]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Liste des animaux
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: '#/components/schemas/AnimalScan'
 */
// ─── GET /api/farmer/animals ──────────────────────────────────────────────────
router.get('/animals', async (req, res) => {
  const username = req.user.username;
  try {
    const [users] = await db.query('SELECT id FROM users WHERE username = ?', [username]);
    const farmer  = users[0];

    const [animals] = await db.query(
      `SELECT a.*, r.rfid_code, f.name AS farm_name
       FROM animals a
       LEFT JOIN rfid_tags r ON r.id = a.rfid_tag_id
       LEFT JOIN farms f     ON f.id = a.farm_id
       WHERE a.owner_id = ?`,
      [farmer.id]
    );
    return res.json(animals);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Erreur serveur' });
  }
});


/**
 * @swagger
 * /api/farmer/farms:
 *   get:
 *     summary: Liste les fermes du farmer connecté
 *     tags: [Farmer]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Liste des fermes
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 type: object
 *                 properties:
 *                   id:       { type: integer }
 *                   name:     { type: string }
 *                   location: { type: string }
 *                   status:   { type: string }
 */
// ─── GET /api/farmer/farms ────────────────────────────────────────────────────
router.get('/farms', async (req, res) => {
  const username = req.user.username;
  try {
    const [users] = await db.query('SELECT id FROM users WHERE username = ?', [username]);
    const farmer  = users[0];

    const [farms] = await db.query(
      'SELECT * FROM farms WHERE owner_id = ?', [farmer.id]
    );
    return res.json(farms);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Erreur serveur' });
  }
});

module.exports = router;