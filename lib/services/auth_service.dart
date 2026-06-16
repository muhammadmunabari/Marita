import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _firestore;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ---------------------------------------------------------------------------
  // 1. Sign Up (Email/Password + Phone)
  // ---------------------------------------------------------------------------
  Future<UserCredential> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    String? phoneNumber,
  }) async {
    // 1. Create User in Firebase Auth
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // 2. Save User Data to Firestore
    final Map<String, dynamic> userData = {
      'name': name.trim(),
      'email': email.trim(),
      'hasBusinessAccount': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (phoneNumber != null) {
      userData['phoneNumber'] = phoneNumber.trim();
    }

    await _firestore
        .collection('users')
        .doc(userCredential.user!.uid)
        .set(userData);

    return userCredential;
  }

  // ---------------------------------------------------------------------------
  // 2. Send Phone Verification SMS
  // ---------------------------------------------------------------------------
  Future<void> sendPhoneVerification({
    required String phoneNumber,
    required Function(String verificationId) codeSent,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(PhoneAuthCredential) verificationCompleted,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber.trim(),
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: (String verificationId, int? resendToken) {
        codeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Verify Phone OTP
  // ---------------------------------------------------------------------------
  Future<bool> verifyPhoneCode({
    required String uid,
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return await verifyWithCredential(uid: uid, credential: credential);
    } catch (e) {
      // Handle error appropriately
      return false;
    }
  }

  Future<bool> verifyWithCredential({
    required String uid,
    required PhoneAuthCredential credential,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        try {
          await user.linkWithCredential(credential);
        } catch (e) {
          // Ignore if already linked
        }
      }

      await _firestore.collection('users').doc(uid).update({
        'isPhoneVerified': true,
      });
      return true;
    } catch (e) {
      // Handle error appropriately
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // 3. Login (Email & Password)
  // ---------------------------------------------------------------------------
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // Optional Check: You can check if email is verified in Firestore here
    // and throw a custom error if not verified yet.

    return userCredential;
  }

  // ---------------------------------------------------------------------------
  // 4. Login (Google)
  // ---------------------------------------------------------------------------
  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
    // In v7+, authenticate() might throw if cancelled or return a non-null object.

    final GoogleSignInAuthentication googleAuth = googleUser.authentication;
    final authorizedUser = await googleUser.authorizationClient.authorizeScopes(
      [],
    );

    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: authorizedUser.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);

    // Save/Merge to Firestore to ensure we have the user document
    await _firestore.collection('users').doc(userCredential.user!.uid).set({
      'email': userCredential.user!.email,
      'isPhoneVerified':
          true, // Assume Google login means no phone verification required, or handle separately
    }, SetOptions(merge: true));

    return userCredential;
  }

  // ---------------------------------------------------------------------------
  // 5. Forgot Password (Email)
  // ---------------------------------------------------------------------------
  Future<void> sendPasswordResetEmail({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ---------------------------------------------------------------------------
  // 6. Forgot Password (Phone)
  // ---------------------------------------------------------------------------

  /// Step A: Trigger SMS OTP to the phone number
  Future<void> verifyPhoneForPasswordReset({
    required String phoneNumber,
    required Function(String verificationId) codeSent,
    required Function(FirebaseAuthException) verificationFailed,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber.trim(),
      verificationCompleted:
          (PhoneAuthCredential credential) {}, // Auto-resolution
      verificationFailed: verificationFailed,
      codeSent: (String verificationId, int? resendToken) {
        codeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  /// Step B: Verify SMS OTP and Update Password
  Future<void> resetPasswordWithPhoneOTP({
    required String verificationId,
    required String smsCode,
    required String newPassword,
  }) async {
    // 1. Create a Phone Auth Credential
    final PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    // 2. Sign-in temporarily to allow password update
    final UserCredential userCredential = await _auth.signInWithCredential(
      credential,
    );

    // 3. Update the password
    await userCredential.user!.updatePassword(newPassword);
  }

  // ---------------------------------------------------------------------------
  // 7. Business Account Creation
  // ---------------------------------------------------------------------------
  Future<void> createBusinessAccount({
    required String companyName,
    required String currency,
    required String role,
    String? address,
    String? taxId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found.');

    await _firestore.collection('users').doc(user.uid).set({
      'hasBusinessAccount': true,
      'business': {
        'companyName': companyName.trim(),
        'currency': currency,
        'role': role,
        'address': address?.trim(),
        'taxId': taxId?.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // 8. Sign Out
  // ---------------------------------------------------------------------------
  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }
}
