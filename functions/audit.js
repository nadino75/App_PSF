const { FieldValue } = require('firebase-admin/firestore');

const AuditAction = {
  SIGN_IN: 'signIn',
  REGISTER: 'register',
  UPDATE_PROFILE: 'updateProfile',
  SUBMIT_REQUEST: 'submitRequest',
  WITHDRAW_REQUEST: 'withdrawRequest',
  RESOLVE_REQUEST: 'resolveRequest',
  EDITORIAL_CATEGORY: 'editorialCategory',
  EDITORIAL_BULLETIN: 'editorialBulletin',
  EDITORIAL_BUSINESS: 'editorialBusiness',
  EDITORIAL_AD: 'editorialAd',
  TOGGLE_FAVORITE: 'toggleFavorite',
  UPLOAD_IMAGE: 'uploadImage',
};

const AuditResult = {
  SUCCESS: 'success',
  DENIED: 'denied',
  ERROR: 'error',
};

async function logAudit(db, userId, action, targetId = null, targetType = null, changes = null, result = AuditResult.SUCCESS, reason = null) {
  const auditLog = {
    userId,
    action,
    targetId,
    targetType,
    changes,
    result,
    reason,
    creado: FieldValue.serverTimestamp(),
  };

  try {
    await db.collection('auditoria').add(auditLog);
  } catch (error) {
    console.error('Error logging audit:', error);
    // No lanzar error; auditoría fallida no debe romper la operación
  }
}

module.exports = { logAudit, AuditAction, AuditResult };
