import 'package:mockito/annotations.dart';
import 'package:autodoc/features/auth/data/services/auth_service.dart';
import 'package:autodoc/features/admin/data/services/admin_auth_service.dart';
import 'package:autodoc/features/dashboard/data/services/vehicle_service.dart';
import 'package:autodoc/core/services/vehicle_image_service.dart';
import 'package:autodoc/features/profile/data/services/user_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';

@GenerateMocks([
  AuthService,
  AdminAuthService,
  VehicleService,
  VehicleImageService,
  UserService,
  FirebaseFirestore,
  FirebaseStorage,
  FirebaseMessaging,
  FirebaseAuth,
  User,
  CollectionReference,
  DocumentReference,
  Query,
  QuerySnapshot,
  QueryDocumentSnapshot,
  WriteBatch,
])
void main() {}
