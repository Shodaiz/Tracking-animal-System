const swaggerJsdoc = require('swagger-jsdoc');

const options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'DZCheptel API',
      version: '1.0.0',
      description: 'API de traçabilité animale — DZCheptel',
    },
    servers: [
      { url: 'http://localhost:8080', description: 'Serveur local' },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
      },
      schemas: {
        // ── Auth ──────────────────────────────────────────
        LoginRequest: {
          type: 'object',
          required: ['username', 'password'],
          properties: {
            username: { type: 'string', example: 'fermier1' },
            password: { type: 'string', example: 'password123' },
          },
        },
        LoginResponse: {
          type: 'object',
          properties: {
            token:    { type: 'string' },
            role:     { type: 'string', example: 'Farmer' },
            username: { type: 'string' },
            userId:   { type: 'integer' },
            fullName: { type: 'string' },
          },
        },
        RegisterRequest: {
          type: 'object',
          required: ['username', 'password', 'email', 'firstName', 'lastName'],
          properties: {
            username:  { type: 'string', example: 'ahmed123' },
            password:  { type: 'string', example: 'monMotDePasse' },
            email:     { type: 'string', example: 'ahmed@email.com' },
            firstName: { type: 'string', example: 'Ahmed' },
            lastName:  { type: 'string', example: 'Benali' },
            role:      { type: 'string', enum: ['Farmer', 'Veterinarian', 'Inspector', 'Administrator'], example: 'Farmer' },
            phone:     { type: 'string', example: '0555000000' },
          },
        },
        ForgotPasswordRequest: {
          type: 'object',
          required: ['identifier'],
          properties: {
            identifier: { type: 'string', example: 'ahmed123 ou ahmed@email.com' },
          },
        },
        ResetPasswordRequest: {
          type: 'object',
          required: ['identifier', 'newPassword'],
          properties: {
            identifier:  { type: 'string' },
            newPassword: { type: 'string', minLength: 6 },
          },
        },
        // ── Animal ────────────────────────────────────────
        AnimalScan: {
          type: 'object',
          properties: {
            id:           { type: 'integer' },
            rfidCode:     { type: 'string' },
            species:      { type: 'string' },
            breed:        { type: 'string' },
            gender:       { type: 'string' },
            lifeStatus:   { type: 'string' },
            healthStatus: { type: 'string' },
            farmName:     { type: 'string' },
            farmLocation: { type: 'string' },
          },
        },
        // ── Health Record ─────────────────────────────────
        HealthRecordRequest: {
          type: 'object',
          required: ['rfidCode', 'recordType'],
          properties: {
            rfidCode:      { type: 'string', example: 'DZ-0007' },
            recordType:    { type: 'string', example: 'Vaccination' },
            diagnosis:     { type: 'string' },
            treatmentPlan: { type: 'string' },
          },
        },
        // ── Inspection ────────────────────────────────────
        InspectionRequest: {
          type: 'object',
          required: ['description'],
          properties: {
            description: { type: 'string' },
            constatType: { type: 'string', example: 'General' },
            result:      { type: 'string', example: 'Pending' },
            animalId:    { type: 'integer' },
          },
        },
        VerifyScanRequest: {
          type: 'object',
          required: ['farmId', 'scannedTags'],
          properties: {
            farmId:      { type: 'integer', example: 1 },
            scannedTags: { type: 'array', items: { type: 'string' }, example: ['DZ-0007', 'DZ-0008'] },
          },
        },
        VerifyScanResponse: {
          type: 'object',
          properties: {
            farmName:        { type: 'string' },
            registeredCount: { type: 'integer' },
            scannedCount:    { type: 'integer' },
            difference:      { type: 'integer' },
            unknownTags:     { type: 'array', items: { type: 'string' } },
            missingTags:     { type: 'array', items: { type: 'string' } },
            isConsistent:    { type: 'boolean' },
          },
        },
        // ── Error ─────────────────────────────────────────
        Error: {
          type: 'object',
          properties: {
            message: { type: 'string' },
          },
        },
      },
    },
    security: [{ bearerAuth: [] }],
  },
  // Fichiers à scanner pour les annotations @swagger
  apis: ['./Routes/*.js'],
};

const swaggerSpec = swaggerJsdoc(options);
module.exports = swaggerSpec;