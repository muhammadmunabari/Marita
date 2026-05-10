const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const nodemailer = require("nodemailer");
const logger = require("firebase-functions/logger");

// Configure the SMTP transport
// TODO: Replace with your actual SMTP credentials (e.g., Gmail App Password, SendGrid, etc.)
// It's recommended to use Firebase Secret Manager to store the password
const transporter = nodemailer.createTransport({
  service: 'gmail', // Use your email provider
  auth: {
    user: 'muhammadmunabari23@gmail.com', // TODO: Change this
    pass: 'mwdu nfxl rulo rrix',    // TODO: Change this
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
    from: '"Marita App" <no-reply@marita.app>',
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
