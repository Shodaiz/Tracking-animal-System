require('dotenv').config();
const express      = require('express');
const cors         = require('cors');
const path         = require('path');
const swaggerUi    = require('swagger-ui-express');
const swaggerSpec  = require('./Config/Swagger');

const app = express();

// ─── Middlewares globaux ──────────────────────────────────────────────────────
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Servir les fichiers uploadés statiquement
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// ─── Swagger UI ───────────────────────────────────────────────────────────────
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec, {
  customSiteTitle: 'DZCheptel API Docs',
}));

// ─── Routes ──────────────────────────────────────────────────────────────────
app.use('/api/auth',       require('./Routes/AuthController'));
app.use('/api/farmer',     require('./Routes/FarmerController'));
app.use('/api/vet',        require('./Routes/VetController'));
app.use('/api/inspection', require('./Routes/InspectionController'));
app.use('/api/inspection/:inspectionId/images', require('./Routes/InspectionImageController'));

// ─── Health check ─────────────────────────────────────────────────────────────
app.get('/health', (req, res) => res.json({ status: 'ok', timestamp: new Date() }));

// ─── 404 ──────────────────────────────────────────────────────────────────────
app.use((req, res) => res.status(404).json({ message: `Route non trouvée : ${req.path}` }));

// ─── Erreurs globales ─────────────────────────────────────────────────────────
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ message: err.message || 'Erreur interne du serveur' });
});

// ─── Démarrage ────────────────────────────────────────────────────────────────
const PORT = 8080;
app.listen(PORT, () => {
  console.log(`✅ Serveur démarré sur http://localhost:${PORT}`);
  console.log(`📚 Swagger UI   → http://localhost:${PORT}/api-docs`);
});