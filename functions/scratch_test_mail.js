const nodemailer = require("nodemailer");

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'your-email@gmail.com',
    pass: 'your-app-password',
  },
});

const mailOptions = {
  from: '"Marita App" <no-reply@marita.app>',
  to: 'your-email@gmail.com',
  subject: "SMTP Connection Test",
  text: "Hello, this is a test of SMTP connection.",
};

console.log("Attempting to send test email...");
transporter.sendMail(mailOptions)
  .then(info => {
    console.log("Email sent successfully!");
    console.log("Response:", info.response);
  })
  .catch(err => {
    console.error("Error sending email:", err);
  });
