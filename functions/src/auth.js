const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const nodemailer = require("nodemailer");
const logger = require("firebase-functions/logger");
const { getApps, initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

// Initialize Firebase Admin SDK if not already initialized
if (getApps().length === 0) {
  initializeApp();
}
const db = getFirestore();

// Configure the SMTP transport using environment variables or fallbacks
const smtpUser = process.env.SMTP_USER || 'your-email@gmail.com';
const smtpPass = process.env.SMTP_PASS || 'your-app-password';

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: smtpUser,
    pass: smtpPass,
  },
});

exports.sendVerificationEmail = onDocumentCreated("users/{uid}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    return;
  }

  const userData = snapshot.data();
  const email = userData.email;
  const verificationCode = userData.verificationCode;

  if (!email || !verificationCode || userData.isEmailVerified) {
    return; // Do nothing if there's no email, no code, or already verified
  }

  const mailOptions = {
    from: `"Marita App" <${smtpUser}>`,
    to: email,
    subject: "Your Marita Verification Code",
    html: `
      <div style="font-family: sans-serif; text-align: center; padding: 20px;">
        <h2>Welcome to Marita!</h2>
        <p>Thank you for signing up. Please use the following 6-digit code to verify your email address:</p>
        <h1 style="color: #4A90E2; letter-spacing: 5px;">${verificationCode}</h1>
        <p>If you did not request this, please ignore this email.</p>
      </div>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    logger.info(`Verification email sent to ${email}`);
  } catch (error) {
    logger.error("Error sending verification email", error);
  }
});

exports.sendWorkspaceInvitationEmail = onDocumentCreated("invitations/{invitationId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    return;
  }

  const invitationData = snapshot.data();
  const email = invitationData.email;
  const access = invitationData.access || "can view";
  const invitedBy = invitationData.invitedBy;
  const companyId = invitationData.companyId;

  if (!email) {
    return;
  }

  let companyName = "Workspace";
  let inviterName = "A team member";

  try {
    const companyDoc = await db.collection("companies").doc(companyId).get();
    if (companyDoc.exists) {
      companyName = companyDoc.data().name || companyName;
    }

    if (invitedBy) {
      const inviterDoc = await db.collection("users").doc(invitedBy).get();
      if (inviterDoc.exists) {
        inviterName = inviterDoc.data().name || inviterDoc.data().email || inviterName;
      }
    }
  } catch (error) {
    logger.error("Error fetching company or inviter info:", error);
  }

  const mailOptions = {
    from: `"Marita App" <${smtpUser}>`,
    to: email,
    subject: `Invitation to join ${companyName} on Marita App`,
    html: `
      <div style="font-family: sans-serif; padding: 20px; color: #333333; max-width: 600px; margin: 0 auto; border: 1px solid #e0e0e0; border-radius: 8px;">
        <h2 style="color: #4A90E2; text-align: center;">Workspace Invitation</h2>
        <p>Hi,</p>
        <p><strong>${inviterName}</strong> has invited you to join their workspace <strong>${companyName}</strong> on the Marita App with <strong>${access}</strong> access.</p>
        <p>To accept the invitation, simply download/open the Marita App and sign in or sign up using your email: <strong>${email}</strong>.</p>
        <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 20px 0;" />
        <p style="font-size: 12px; color: #777777; text-align: center;">This is an automated notification from Marita App.</p>
      </div>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    logger.info(`Workspace invitation email sent to ${email} for company ${companyName}`);
  } catch (error) {
    logger.error("Error sending workspace invitation email", error);
  }
});

exports.onWorkspaceInvitationUpdated = onDocumentUpdated("invitations/{invitationId}", async (event) => {
  const change = event.data;
  if (!change) {
    return;
  }

  const beforeData = change.before.data();
  const afterData = change.after.data();

  // If status is updated to 'accepted'
  if (beforeData.status !== "accepted" && afterData.status === "accepted") {
    const companyId = afterData.companyId;
    const email = afterData.email;
    const acceptedByUid = afterData.acceptedByUid;
    const acceptedByName = afterData.acceptedByName || "User";
    const access = afterData.access || "can view";

    logger.info(`Processing acceptance of invitation for ${email} to company ${companyId}`);

    if (!acceptedByUid) {
      logger.error("acceptedByUid is missing in accepted invitation");
      return;
    }

    try {
      // 1. Fetch company document
      const companyRef = db.collection("companies").doc(companyId);
      const companyDoc = await companyRef.get();
      if (!companyDoc.exists) {
        logger.error(`Company ${companyId} does not exist`);
        return;
      }

      const companyData = companyDoc.data();
      const companyName = companyData.name || "Workspace";

      // 2. Prepare member detail map
      const memberDetail = {
        uid: acceptedByUid,
        email: email,
        name: acceptedByName,
        role: "employee", // Default joined role
        access: access,   // e.g. "can view", "can edit", etc.
        joinedAt: new Date().toISOString(),
      };

      const batch = db.batch();

      // 3. Update company members list and memberDetails map
      batch.update(companyRef, {
        members: FieldValue.arrayUnion(acceptedByUid),
        [`memberDetails.${acceptedByUid}`]: memberDetail,
      });

      // 4. Update user profile to set hasBusinessAccount and business information
      const userRef = db.collection("users").doc(acceptedByUid);
      batch.set(userRef, {
        hasBusinessAccount: true,
        business: {
          companyName: companyName,
          role: "employee",
          updatedAt: new Date().toISOString(),
        }
      }, { merge: true });

      // 5. Delete the invitation document
      const invitationRef = change.after.ref;
      batch.delete(invitationRef);

      await batch.commit();
      logger.info(`Successfully added ${email} (${acceptedByUid}) to company ${companyId} and deleted invitation`);
    } catch (error) {
      logger.error(`Error processing invitation acceptance for ${email} in company ${companyId}:`, error);
    }
  }
});

