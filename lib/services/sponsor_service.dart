import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/auth_user.dart';
import '../models/sponsor_profile.dart';
import '../models/sponsor_request.dart';
import '../models/link_requests.dart';
class SponsorException implements Exception {
  SponsorException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SponsorService {
  SponsorService._();
  static final SponsorService instance = SponsorService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Random _random = Random();
  CollectionReference<Map<String, dynamic>> get _linkRequestsRef =>
      _firestore.collection('meta').doc('sponsor').collection('link_requests');
  String? get _uid => _auth.currentUser?.uid;
  bool get isSignedIn => _uid != null;

  CollectionReference<Map<String, dynamic>> get _requestsCollectionRef =>
      _firestore.collection('meta').doc('sponsor').collection('unlock_requests');

  CollectionReference<Map<String, dynamic>> get _mailCollectionRef =>
      _firestore.collection('mail');

  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid);
  }

  Future<void> ensureCurrentUserInitialized([AuthUser? user]) async {
    final doc = _userDoc;
    if (doc == null) return;
    final snap = await doc.get();
    final data = snap.data() ?? <String, dynamic>{};
    if ((data['sponsorCode'] as String?)?.isNotEmpty == true) return;
    final code = await _generateUniqueCode();
    await doc.set({
      'sponsorCode': code,
      'profile': user?.toMap() ?? data['profile'],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> getMySponsorCode() async {
    await ensureCurrentUserInitialized();
    final doc = _userDoc;
    if (doc == null) throw SponsorException('You need to sign in first.');
    final snap = await doc.get();
    return snap.data()?['sponsorCode'] as String? ?? '';
  }

  Future<String?> getSponsorUid() async {
    final doc = _userDoc;
    if (doc == null) return null;
    final snap = await doc.get();
    return snap.data()?['sponsorUid'] as String?;
  }

  Future<bool> hasSponsor() async => (await getSponsorUid()) != null;

  Future<SponsorProfile?> getCurrentSponsorProfile() async {
    final sponsorUid = await getSponsorUid();
    if (sponsorUid == null) return null;
    final snap = await _firestore.collection('users').doc(sponsorUid).get();
    final data = snap.data();
    if (data == null) return null;
    return SponsorProfile.fromUserDoc(sponsorUid, data);
  }
  Future<void> sendLinkRequestWithCode(String code) async {
    final uid = _uid;
    final meDoc = _userDoc;

    if (uid == null || meDoc == null) {
      throw SponsorException('Sign in first.');
    }

    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw SponsorException('Enter a valid sponsor code.');
    }

    await ensureCurrentUserInitialized();

    final meSnap = await meDoc.get();
    final meData = meSnap.data() ?? <String, dynamic>{};

    if ((meData['sponsorUid'] as String?)?.isNotEmpty == true) {
      throw SponsorException('You already have a sponsor linked.');
    }

    final targetQuery = await _firestore
        .collection('users')
        .where('sponsorCode', isEqualTo: normalized)
        .limit(1)
        .get();

    if (targetQuery.docs.isEmpty) {
      throw SponsorException('That sponsor code was not found.');
    }

    final targetDoc = targetQuery.docs.first;
    final targetData = targetDoc.data();

    if (targetDoc.id == uid) {
      throw SponsorException('You cannot use your own sponsor code.');
    }

    if ((targetData['sponsorUid'] as String?)?.isNotEmpty == true) {
      throw SponsorException('That user already has a sponsor linked.');
    }

    final duplicate = await _linkRequestsRef
        .where('requesterUid', isEqualTo: uid)
        .where('targetUid', isEqualTo: targetDoc.id)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (duplicate.docs.isNotEmpty) {
      throw SponsorException('A pending request already exists.');
    }

    final request = LinkRequest(
      id: '',
      requesterUid: uid,
      requesterName: meData['profile']?['displayName'] ??
          _auth.currentUser?.displayName ??
          _auth.currentUser?.email ??
          'Detox user',
      targetUid: targetDoc.id,
      targetName: targetData['profile']?['displayName'] ??
          targetData['profile']?['email'] ??
          'User',
      status: 'pending',
      createdAt: null,
      type: 'sponsor',
    );

    await _linkRequestsRef.add({
      ...request.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  Stream<List<LinkRequest>> incomingLinkRequests() {
    final uid = _uid;
    if (uid == null) {
      return const Stream.empty();
    }

    return _linkRequestsRef
        .where('targetUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snap) => snap.docs
          .map((doc) => LinkRequest.fromDocument(doc))
          .toList(),
    );
  }
  Future<void> rejectLinkRequest(String requestId) async {
    final uid = _uid;
    if (uid == null) {
      throw SponsorException('Sign in first.');
    }

    final reqRef = _linkRequestsRef.doc(requestId);
    final snap = await reqRef.get();
    final data = snap.data();

    if (data == null) {
      throw SponsorException('Request not found.');
    }

    if (data['targetUid'] != uid) {
      throw SponsorException('This request is not for you.');
    }

    await reqRef.set(
      {
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> acceptLinkRequest(String requestId) async {
    final uid = _uid;
    final meDoc = _userDoc;

    if (uid == null || meDoc == null) {
      throw SponsorException('Sign in first.');
    }

    final reqRef = _linkRequestsRef.doc(requestId);

    await _firestore.runTransaction((tx) async {
      final reqSnap = await tx.get(reqRef);
      final reqData = reqSnap.data();

      if (reqData == null) {
        throw SponsorException('Request not found.');
      }

      if (reqData['targetUid'] != uid) {
        throw SponsorException('This request is not for you.');
      }

      if (reqData['status'] != 'pending') {
        throw SponsorException('This request is no longer pending.');
      }

      final requesterUid = reqData['requesterUid'] as String;
      final requesterRef = _firestore.collection('users').doc(requesterUid);

      final mySnap = await tx.get(meDoc);
      final requesterSnap = await tx.get(requesterRef);

      final mySponsor = mySnap.data()?['sponsorUid'] as String?;
      final requesterSponsor = requesterSnap.data()?['sponsorUid'] as String?;

      if ((mySponsor ?? '').isNotEmpty || (requesterSponsor ?? '').isNotEmpty) {
        throw SponsorException('One of the users is already linked.');
      }

      tx.set(
        meDoc,
        {
          'sponsorUid': requesterUid,
          'sponsorLinkedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      tx.set(
        requesterRef,
        {
          'sponsorUid': uid,
          'sponsorLinkedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      tx.set(
        reqRef,
        {
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> unlinkSponsor() async {
    final uid = _uid;
    final meDoc = _userDoc;
    if (uid == null || meDoc == null) throw SponsorException('Sign in first.');
    final sponsorUid = await getSponsorUid();
    if (sponsorUid == null) return;
    final sponsorRef = _firestore.collection('users').doc(sponsorUid);
    final batch = _firestore.batch();
    batch.set(meDoc, {
      'sponsorUid': FieldValue.delete(),
      'sponsorLinkedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(sponsorRef, {
      'sponsorUid': FieldValue.delete(),
      'sponsorLinkedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> requestUnlinkSponsorCode() async {
    await createUnlockRequest(requestType: 'unlink_sponsor', durationMinutes: 0);
  }

  Future<void> requestEmailUnlinkCode() async {
    final uid = _uid;
    final meDoc = _userDoc;
    if (uid == null || meDoc == null) throw SponsorException('Sign in first.');
    final sponsorUid = await getSponsorUid();
    if (sponsorUid == null) throw SponsorException('Link a sponsor first.');
    final me = _auth.currentUser;
    final email = me?.email?.trim();
    if (email == null || email.isEmpty) {
      throw SponsorException('Add an email address to your account first.');
    }

    final code = _generateNumericCode();
    final expiresAt = DateTime.now().add(const Duration(minutes: 10));
    final requestRef = await _requestsCollectionRef.add({
      'requesterUid': uid,
      'requesterName': me?.displayName?.trim().isNotEmpty == true
          ? me!.displayName!.trim()
          : (email),
      'sponsorUid': sponsorUid,
      'requestType': 'unlink_email',
      'status': 'emailed',
      'durationMinutes': 0,
      'code': code,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
    });

    await meDoc.set({
      'unlinkEmailCode': code,
      'unlinkEmailCodeExpiresAt': Timestamp.fromDate(expiresAt),
      'unlinkEmailRequestId': requestRef.id,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _mailCollectionRef.add({
      'to': [email],
      'message': {
        'subject': 'Detox unlink code',
        'text': 'Your Detox unlink code is $code. It expires in 10 minutes.',
        'html': '<p>Your Detox unlink code is <strong>$code</strong>.</p><p>It expires in 10 minutes.</p>',
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> consumeEmailUnlinkCode(String code) async {
    final userDoc = _userDoc;
    if (userDoc == null) throw SponsorException('Sign in first.');
    final value = code.trim();
    if (value.isEmpty) throw SponsorException('Enter the email code.');

    final snap = await userDoc.get();
    final data = snap.data() ?? <String, dynamic>{};
    final savedCode = data['unlinkEmailCode'] as String?;
    final expires = (data['unlinkEmailCodeExpiresAt'] as Timestamp?)?.toDate();
    final requestId = data['unlinkEmailRequestId'] as String?;

    if (savedCode == null || expires == null || DateTime.now().isAfter(expires) || savedCode != value) {
      throw SponsorException('That email code is invalid or expired.');
    }

    if (requestId != null) {
      await _requestsCollectionRef.doc(requestId).set({
        'status': 'consumed',
        'consumedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await unlinkSponsor();
    await userDoc.set({
      'unlinkEmailCode': FieldValue.delete(),
      'unlinkEmailCodeExpiresAt': FieldValue.delete(),
      'unlinkEmailRequestId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> createUnlockRequest({
    required String requestType,
    required int durationMinutes,
  }) async {
    final uid = _uid;
    if (uid == null) throw SponsorException('Sign in first.');
    final me = _auth.currentUser;
    final sponsorUid = await getSponsorUid();
    if (sponsorUid == null) throw SponsorException('Link a sponsor first.');

    final existing = await _requestsCollectionRef
        .where('requesterUid', isEqualTo: uid)
        .limit(10)
        .get();
    final duplicate = existing.docs.map((e) => SponsorRequest.fromDoc(e.id, e.data())).any(
          (request) =>
              request.requestType == requestType &&
              !request.isConsumed &&
              (request.isPending || (request.isApproved && !request.isExpired)),
        );
    if (duplicate) {
      throw SponsorException('You already have an active ${requestType == 'zone_override' ? 'zone pause' : requestType == 'settings_unlock' ? 'settings' : requestType == 'unlink_sponsor' ? 'unlink' : 'email unlink'} request.');
    }

    await _requestsCollectionRef.add({
      'requesterUid': uid,
      'requesterName': me?.displayName?.trim().isNotEmpty == true
          ? me!.displayName!.trim()
          : (me?.email ?? 'Detox user'),
      'sponsorUid': sponsorUid,
      'requestType': requestType,
      'status': 'pending',
      'durationMinutes': durationMinutes,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<SponsorRequest>> incomingRequests() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _requestsCollectionRef
        .where('sponsorUid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
          final items = snap.docs
              .map((doc) => SponsorRequest.fromDoc(doc.id, doc.data()))
              .toList();
          items.sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
          return items;
        });
  }

  Stream<List<SponsorRequest>> outgoingRequests() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _requestsCollectionRef
        .where('requesterUid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
          final items = snap.docs
              .map((doc) => SponsorRequest.fromDoc(doc.id, doc.data()))
              .toList();
          items.sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
          return items;
        });
  }

  Future<String> approveRequest(String requestId) async {
    final uid = _uid;
    if (uid == null) throw SponsorException('Sign in first.');
    final ref = _requestsCollectionRef.doc(requestId);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null) throw SponsorException('Request not found.');
    final request = SponsorRequest.fromDoc(snap.id, data);
    if (request.sponsorUid != uid) {
      throw SponsorException('That request does not belong to you.');
    }
    final code = _generateNumericCode();
    await ref.set({
      'status': 'approved',
      'code': code,
      'approvedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 3))),
    }, SetOptions(merge: true));
    return code;
  }

  Future<int> consumeCode({
    required String code,
    required String requestType,
  }) async {
    final uid = _uid;
    if (uid == null) throw SponsorException('Sign in first.');
    final normalized = code.trim();
    if (normalized.isEmpty) throw SponsorException('Enter the sponsor code.');

    final query = await _requestsCollectionRef
        .where('requesterUid', isEqualTo: uid)
        .limit(30)
        .get();

    SponsorRequest? match;
    for (final doc in query.docs) {
      final request = SponsorRequest.fromDoc(doc.id, doc.data());
      if (request.requestType == requestType &&
          request.code == normalized &&
          request.isApproved &&
          !request.isExpired) {
        match = request;
        break;
      }
    }

    if (match == null) {
      throw SponsorException('That code is invalid or expired.');
    }

    final userDoc = _userDoc;
    if (userDoc == null) throw SponsorException('Sign in first.');

    if (requestType == 'unlink_sponsor') {
      await _requestsCollectionRef.doc(match.id).set({
        'status': 'consumed',
        'consumedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await unlinkSponsor();
      return 0;
    }

    final until = DateTime.now().add(Duration(minutes: match.durationMinutes));
    final field = requestType == 'settings_unlock' ? 'settingsUnlockUntil' : 'zoneOverrideUntil';

    final batch = _firestore.batch();
    batch.set(userDoc, {
      field: Timestamp.fromDate(until),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_requestsCollectionRef.doc(match.id), {
      'status': 'consumed',
      'consumedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
    return match.durationMinutes;
  }

  Future<bool> hasActiveSettingsUnlock() async => _hasActiveTimestamp('settingsUnlockUntil');
  Future<bool> hasActiveZoneOverride() async => _hasActiveTimestamp('zoneOverrideUntil');

  Future<DateTime?> getSettingsUnlockUntil() async => _getTimestamp('settingsUnlockUntil');
  Future<DateTime?> getZoneOverrideUntil() async => _getTimestamp('zoneOverrideUntil');

  Future<bool> _hasActiveTimestamp(String field) async {
    final value = await _getTimestamp(field);
    return value != null && DateTime.now().isBefore(value);
  }

  Future<DateTime?> _getTimestamp(String field) async {
    final doc = _userDoc;
    if (doc == null) return null;
    final snap = await doc.get();
    final data = snap.data();
    final timestamp = data?[field];
    if (timestamp is Timestamp) return timestamp.toDate();
    return null;
  }

  Stream<List<SponsorRequest>> incomingHistory() => incomingRequests().map((items) => items.take(20).toList());
  Stream<List<SponsorRequest>> outgoingHistory() => outgoingRequests().map((items) => items.take(20).toList());

  String _generateNumericCode() => (100000 + _random.nextInt(900000)).toString();

  Future<String> _generateUniqueCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    while (true) {
      final buffer = StringBuffer();
      for (var i = 0; i < 6; i++) {
        buffer.write(chars[_random.nextInt(chars.length)]);
      }
      final code = buffer.toString();
      final query = await _firestore
          .collection('users')
          .where('sponsorCode', isEqualTo: code)
          .limit(1)
          .get();
      if (query.docs.isEmpty) return code;
    }
  }
}
