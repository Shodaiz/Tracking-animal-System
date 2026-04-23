const express = require('express');
const router  = express.Router();
const bcrypt  = require('bcryptjs');
const jwt     = require('jsonwebtoken');
const db      = require('../Config/Db');

/**
 * @swagger
 * tags:
 *   name: Auth
 *   description: Authentification et gestion des comptes
 */
 
/**
 * @swagger
 * /api/auth/login:
 *   post:
 *     summary: Connexion utilisateur
 *     tags: [Auth]
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/LoginRequest'
 *     responses:
 *       200:
 *         description: Connexion réussie
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/LoginResponse'
 *       400:
 *         description: Champs manquants
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       401:
 *         description: Identifiant ou mot de passe incorrect
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       403:
 *         description: Compte désactivé
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
// ─── POST /api/auth/login ────────────────────────────────────────────────────
router.post('/login', async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password)
    return res.status(400).json({ message: 'Username et password requis' });

  try {
    const [rows] = await db.query(
      'SELECT * FROM users WHERE username = ?', [username]
    );
    const user = rows[0];

    if (!user || !(await bcrypt.compare(password, user.password)))
      return res.status(401).json({ message: 'Identifiant ou mot de passe incorrect' });

    if (!user.is_active)
      return res.status(403).json({ message: 'Compte désactivé' });

    const token = jwt.sign(
      { username: user.username, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '24h' }
    );

    return res.json({
      token,
      role:     user.role,
      username: user.username,
      userId:   user.id,
      fullName: `${user.first_name} ${user.last_name}`,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Erreur serveur' });
  }
});

/**
 * @swagger
 * /api/auth/register:
 *   post:
 *     summary: Inscription d'un nouvel utilisateur
 *     tags: [Auth]
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/RegisterRequest'
 *     responses:
 *       200:
 *         description: Compte créé avec succès
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:  { type: string }
 *                 username: { type: string }
 *                 role:     { type: string }
 *       400:
 *         description: Champs manquants ou username/email déjà pris
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
// ─── POST /api/auth/register ─────────────────────────────────────────────────
router.post('/register', async (req, res) => {
  const { username, password, email, firstName, lastName, role, phone } = req.body;

  if (!username || !password || !email || !firstName || !lastName)
    return res.status(400).json({ message: 'Champs obligatoires manquants' });

  const validRoles = ['Farmer', 'Veterinarian', 'Inspector', 'Administrator'];
  const userRole   = validRoles.includes(role) ? role : 'Farmer';

  try {
    // Vérif username unique
    const [existUser] = await db.query(
      'SELECT id FROM users WHERE username = ?', [username]
    );
    if (existUser.length > 0)
      return res.status(400).json({ message: "Ce nom d'utilisateur est déjà pris" });

    // Vérif email unique
    const [existEmail] = await db.query(
      'SELECT id FROM users WHERE email = ?', [email]
    );
    if (existEmail.length > 0)
      return res.status(400).json({ message: 'Cet email est déjà utilisé' });

    const hashedPwd = await bcrypt.hash(password, 10);

    const [result] = await db.query(
      `INSERT INTO users (username, email, password, first_name, last_name, role, phone, is_active)
       VALUES (?, ?, ?, ?, ?, ?, ?, 1)`,
      [username, email, hashedPwd, firstName, lastName, userRole, phone || null]
    );
    const userId = result.insertId;

    // Si Farmer → créer une ferme automatiquement
    if (userRole === 'Farmer') {
      await db.query(
        `INSERT INTO farms (owner_id, name, location, status) VALUES (?, ?, ?, 'Active')`,
        [userId, `Ferme de ${firstName} ${lastName}`, 'À définir']
      );
    }

    return res.json({ message: 'Compte créé avec succès', username, role: userRole });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Erreur serveur' });
  }
});

/**
 * @swagger
 * /api/auth/forgot-password:
 *   post:
 *     summary: Vérifier si un compte existe (username ou email)
 *     tags: [Auth]
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/ForgotPasswordRequest'
 *     responses:
 *       200:
 *         description: Compte trouvé
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:  { type: string }
 *                 username: { type: string }
 *                 email:    { type: string }
 *       400:
 *         description: Identifiant manquant
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       404:
 *         description: Aucun compte trouvé
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
// ─── POST /api/auth/forgot-password ──────────────────────────────────────────
router.post('/forgot-password', async (req, res) => {
  const { identifier } = req.body;
  if (!identifier || identifier.trim() === '')
    return res.status(400).json({ message: 'Veuillez fournir un identifiant ou email' });

  try {
    const [rows] = await db.query(
      'SELECT * FROM users WHERE username = ? OR email = ?',
      [identifier, identifier]
    );
    if (rows.length === 0)
      return res.status(404).json({ message: 'Aucun compte trouvé' });

    const user = rows[0];
    const maskedEmail = maskEmail(user.email);

    return res.json({
      message:  'Compte trouvé. Vous pouvez réinitialiser votre mot de passe.',
      username: user.username,
      email:    maskedEmail,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Erreur serveur' });
  }
});

/**
 * @swagger
 * /api/auth/reset-password:
 *   post:
 *     summary: Réinitialiser le mot de passe
 *     tags: [Auth]
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/ResetPasswordRequest'
 *     responses:
 *       200:
 *         description: Mot de passe réinitialisé avec succès
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message: { type: string }
 *       400:
 *         description: Mot de passe trop court
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       404:
 *         description: Utilisateur non trouvé
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
// ─── POST /api/auth/reset-password ───────────────────────────────────────────
router.post('/reset-password', async (req, res) => {
  const { identifier, newPassword } = req.body;

  if (!newPassword || newPassword.length < 6)
    return res.status(400).json({ message: 'Le mot de passe doit contenir au moins 6 caractères' });

  try {
    const [rows] = await db.query(
      'SELECT * FROM users WHERE username = ? OR email = ?',
      [identifier, identifier]
    );
    if (rows.length === 0)
      return res.status(404).json({ message: 'Utilisateur non trouvé' });

    const hashed = await bcrypt.hash(newPassword, 10);
    await db.query('UPDATE users SET password = ? WHERE id = ?', [hashed, rows[0].id]);

    return res.json({ message: 'Mot de passe réinitialisé avec succès' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Erreur serveur' });
  }
});

// Helper
function maskEmail(email) {
  if (!email || !email.includes('@')) return '***';
  const [local, domain] = email.split('@');
  return (local.length <= 2 ? '***' : local[0] + '***') + '@' + domain;
}

module.exports = router;