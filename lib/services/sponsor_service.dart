import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/auth_user.dart';
import '../models/link_requests.dart';
import '../models/sponsor_profile.dart';
import '../models/sponsor_request.dart';
import 'storage_service.dart';

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

  CollectionReference<Map<String, dynamic>> get _requestsCollectionRef =>
      _firestore.collection('meta').doc('sponsor').collection('unlock_requests');

  CollectionReference<Map<String, dynamic>> get _mailCollectionRef =>
      _firestore.collection('mail');

  String? get _uid => _auth.currentUser?.uid;

  bool get isSignedIn => _uid != null;

  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid);
  }

  String _linkRequestId(String requesterUid, String targetUid) =>
      '${requesterUid}_${targetUid}_sponsor';

  String _unlockRequestId(String requesterUid, String requestType) =>
      '${requesterUid}_${requestType}';
  DocumentReference<Map<String, dynamic>> _linkRequestRefForPair(
      String requesterUid,
      String targetUid,
      ) {
    return _linkRequestsRef.doc(_linkRequestId(requesterUid, targetUid));
  }

  Future<void> ensureCurrentUserInitialized([AuthUser? user]) async {
    final doc = _userDoc;
    if (doc == null) return;

    final current = await doc.get();
    final currentData = current.data() ?? <String, dynamic>{};
    if ((currentData['sponsorCode'] as String?)?.isNotEmpty == true) {
      if (user != null) {
        await doc.set({
          'profile': user.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      return;
    }

    final code = await _generateUniqueCode();

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(doc);
      final data = snap.data() ?? <String, dynamic>{};

      if ((data['sponsorCode'] as String?)?.isNotEmpty == true) {
        if (user != null) {
          tx.set(doc, {
            'profile': user.toMap(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        return;
      }

      tx.set(
        doc,
        {
          'sponsorCode': code,
          'profile': user?.toMap() ?? data['profile'],
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Stream<List<LinkRequest>> outgoingLinkRequests() {
    final uid = _uid;
    if (uid == null) {
      return const Stream.empty();
    }

    return _linkRequestsRef
        .where('requesterUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
      final items = snap.docs.map(LinkRequest.fromDocument).toList();
      items.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return items;
    });
  }
  Future<void> approveDirectRequest(String requestId) async {
    final uid = _uid;
    if (uid == null) {
      throw SponsorException('Sign in first.');
    }

    final ref = _requestsCollectionRef.doc(requestId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();

      if (data == null) {
        throw SponsorException('Request not found.');
      }

      final request = SponsorRequest.fromDoc(snap.id, data);

      if (request.sponsorUid != uid) {
        throw SponsorException('That request does not belong to you.');
      }

      if (request.requestType != 'zone_override' &&
          request.requestType != 'settings_unlock' &&
          request.requestType != 'shield_pause') {
        throw SponsorException(
          'This request type still requires the manual code flow.',
        );
      }

      if (!request.isPending) {
        throw SponsorException('This request is no longer pending.');
      }

      final requesterRef =
      _firestore.collection('users').doc(request.requesterUid);

      final until =
      DateTime.now().add(Duration(minutes: request.durationMinutes));

      String field;
      switch (request.requestType) {
        case 'settings_unlock':
          field = 'settingsUnlockUntil';
          break;
        case 'zone_override':
          field = 'zoneOverrideUntil';
          break;
        case 'shield_pause':
          field = 'shieldPauseUntil';
          break;
        default:
          throw SponsorException('Unsupported request type.');
      }

      tx.set(
        requesterRef,
        {
          field: Timestamp.fromDate(until),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      tx.set(
        ref,
        {
          'status': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
          'appliedAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(until),
          'updatedAt': FieldValue.serverTimestamp(),
          'code': FieldValue.delete(),
          'consumedAt': FieldValue.delete(),
        },
        SetOptions(merge: true),
      );
    });
    await StorageService().incrementPauseApproved();
  }

  Future<void> rejectRequest(String requestId) async {
    final uid = _uid;
    if (uid == null) {
      throw SponsorException('Sign in first.');
    }

    final ref = _requestsCollectionRef.doc(requestId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();

      if (data == null) {
        throw SponsorException('Request not found.');
      }

      final request = SponsorRequest.fromDoc(snap.id, data);

      if (request.sponsorUid != uid) {
        throw SponsorException('That request does not belong to you.');
      }

      if (!request.isPending) {
        throw SponsorException('This request is no longer pending.');
      }

      tx.set(
        ref,
        {
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
    await StorageService().incrementPauseRejected();
  }



  Future<String> getMySponsorCode() async {
    await ensureCurrentUserInitialized();
    final doc = _userDoc;
    if (doc == null) {
      throw SponsorException('You need to sign in first.');
    }
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

    final requestId = _linkRequestId(uid, targetDoc.id);
    final requestRef = _linkRequestsRef.doc(requestId);

    await _firestore.runTransaction((tx) async {
      final freshMeSnap = await tx.get(meDoc);
      final freshMeData = freshMeSnap.data() ?? <String, dynamic>{};

      if ((freshMeData['sponsorUid'] as String?)?.isNotEmpty == true) {
        throw SponsorException('You already have a sponsor linked.');
      }

      final freshTargetSnap = await tx.get(targetDoc.reference);
      final freshTargetData = freshTargetSnap.data() ?? <String, dynamic>{};

      if ((freshTargetData['sponsorUid'] as String?)?.isNotEmpty == true) {
        throw SponsorException('That user already has a sponsor linked.');
      }

      final existingSnap = await tx.get(requestRef);
      final existingData = existingSnap.data();

      if (existingData != null) {
        final status = existingData['status'] as String?;
        final requesterStillLinked =
            (freshMeData['sponsorUid'] as String?) == targetDoc.id;
        final targetStillLinked =
            (freshTargetData['sponsorUid'] as String?) == uid;
        final stillLinkedTogether = requesterStillLinked && targetStillLinked;

        if (status == 'pending') {
          throw SponsorException('A pending request already exists.');
        }

        if (status == 'accepted' && stillLinkedTogether) {
          throw SponsorException('This sponsor request was already accepted.');
        }
      }

      final request = LinkRequest(
        id: requestId,
        requesterUid: uid,
        requesterName: freshMeData['profile']?['displayName'] ??
            _auth.currentUser?.displayName ??
            _auth.currentUser?.email ??
            'Detox user',
        targetUid: targetDoc.id,
        targetName: freshTargetData['profile']?['displayName'] ??
            freshTargetData['profile']?['email'] ??
            'User',
        status: 'pending',
        createdAt: null,
        type: 'sponsor',
      );

      tx.set(requestRef, {
        ...request.toMap(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'acceptedAt': FieldValue.delete(),
        'rejectedAt': FieldValue.delete(),
        'endedAt': FieldValue.delete(),
      }, SetOptions(merge: true));
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
        .map((snap) {
      return snap.docs.map(LinkRequest.fromDocument).toList();
    });
  }

  Future<void> rejectLinkRequest(String requestId) async {
    final uid = _uid;
    if (uid == null) {
      throw SponsorException('Sign in first.');
    }

    final reqRef = _linkRequestsRef.doc(requestId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(reqRef);
      final data = snap.data();

      if (data == null) {
        throw SponsorException('Request not found.');
      }

      if (data['targetUid'] != uid) {
        throw SponsorException('This request is not for you.');
      }

      final status = data['status'] as String?;
      if (status == 'rejected') {
        return;
      }
      if (status != 'pending') {
        throw SponsorException('This request is no longer pending.');
      }

      tx.set(
        reqRef,
        {
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
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

      final status = reqData['status'] as String?;
      if (status == 'accepted') {
        return;
      }
      if (status != 'pending') {
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
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> unlinkSponsor() async {
    final uid = _uid;
    final meDoc = _userDoc;

    if (uid == null || meDoc == null) {
      throw SponsorException('Sign in first.');
    }

    await _firestore.runTransaction((tx) async {
      final meSnap = await tx.get(meDoc);
      final meData = meSnap.data() ?? <String, dynamic>{};
      final sponsorUid = meData['sponsorUid'] as String?;

      if (sponsorUid == null || sponsorUid.isEmpty) {
        return;
      }

      final sponsorRef = _firestore.collection('users').doc(sponsorUid);
      final sponsorSnap = await tx.get(sponsorRef);
      final sponsorData = sponsorSnap.data() ?? <String, dynamic>{};

      tx.set(meDoc, {
        'sponsorUid': FieldValue.delete(),
        'sponsorLinkedAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (sponsorData['sponsorUid'] == uid) {
        tx.set(sponsorRef, {
          'sponsorUid': FieldValue.delete(),
          'sponsorLinkedAt': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      final forwardRef = _linkRequestRefForPair(uid, sponsorUid);
      final reverseRef = _linkRequestRefForPair(sponsorUid, uid);

      final forwardSnap = await tx.get(forwardRef);
      final reverseSnap = await tx.get(reverseRef);

      if (forwardSnap.exists) {
        tx.set(forwardRef, {
          'status': 'ended',
          'endedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (reverseSnap.exists) {
        tx.set(reverseRef, {
          'status': 'ended',
          'endedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }
  Future<void> requestUnlinkSponsorCode() async {
    await createUnlockRequest(
      requestType: 'unlink_sponsor',
      durationMinutes: 0,
    );
  }

  Future<void> requestEmailUnlinkCode() async {
    final uid = _uid;
    final meDoc = _userDoc;

    if (uid == null || meDoc == null) {
      throw SponsorException('Sign in first.');
    }

    final sponsorUid = await getSponsorUid();
    if (sponsorUid == null) {
      throw SponsorException('Link a sponsor first.');
    }

    final me = _auth.currentUser;
    final email = me?.email?.trim();
    if (email == null || email.isEmpty) {
      throw SponsorException('Add an email address to your account first.');
    }

    final code = _generateNumericCode();
    final expiresAt = DateTime.now().add(const Duration(minutes: 10));
    final requestId = _unlockRequestId(uid, 'unlink_email');
    final requestRef = _requestsCollectionRef.doc(requestId);

    await _firestore.runTransaction((tx) async {
      final requestSnap = await tx.get(requestRef);
      final requestData = requestSnap.data();

      if (requestData != null) {
        final existing = SponsorRequest.fromDoc(requestSnap.id, requestData);
        if (!existing.isConsumed &&
            (existing.isPending || (existing.isApproved && !existing.isExpired))) {
          throw SponsorException('You already have an active email unlink request.');
        }
      }

      tx.set(requestRef, {
        'requesterUid': uid,
        'requesterName': me?.displayName?.trim().isNotEmpty == true
            ? me!.displayName!.trim()
            : email,
        'sponsorUid': sponsorUid,
        'requestType': 'unlink_email',
        'status': 'emailed',
        'durationMinutes': 0,
        'code': code,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(meDoc, {
        'unlinkEmailCode': code,
        'unlinkEmailCodeExpiresAt': Timestamp.fromDate(expiresAt),
        'unlinkEmailRequestId': requestId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    await _mailCollectionRef.add({
      'to': [email],
      'message': {
        'subject': 'Detox unlink code',
        'text': 'Your Detox unlink code is $code. It expires in 10 minutes.',
        'html':
        '<p>Your Detox unlink code is <strong>$code</strong>.</p><p>It expires in 10 minutes.</p>',
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> consumeEmailUnlinkCode(String code) async {
    final uid = _uid;
    final userDoc = _userDoc;

    if (uid == null || userDoc == null) {
      throw SponsorException('Sign in first.');
    }

    final value = code.trim();
    if (value.isEmpty) {
      throw SponsorException('Enter the email code.');
    }

    await _firestore.runTransaction((tx) async {
      final userSnap = await tx.get(userDoc);
      final userData = userSnap.data() ?? <String, dynamic>{};

      final savedCode = userData['unlinkEmailCode'] as String?;
      final expires = (userData['unlinkEmailCodeExpiresAt'] as Timestamp?)?.toDate();
      final requestId = userData['unlinkEmailRequestId'] as String?;

      if (savedCode == null ||
          expires == null ||
          DateTime.now().isAfter(expires) ||
          savedCode != value) {
        throw SponsorException('That email code is invalid or expired.');
      }

      if (requestId != null && requestId.isNotEmpty) {
        tx.set(_requestsCollectionRef.doc(requestId), {
          'status': 'consumed',
          'consumedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      final sponsorUid = userData['sponsorUid'] as String?;
      if (sponsorUid != null && sponsorUid.isNotEmpty) {
        final sponsorRef = _firestore.collection('users').doc(sponsorUid);
        final sponsorSnap = await tx.get(sponsorRef);
        final sponsorData = sponsorSnap.data() ?? <String, dynamic>{};

        tx.set(userDoc, {
          'sponsorUid': FieldValue.delete(),
          'sponsorLinkedAt': FieldValue.delete(),
          'unlinkEmailCode': FieldValue.delete(),
          'unlinkEmailCodeExpiresAt': FieldValue.delete(),
          'unlinkEmailRequestId': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (sponsorData['sponsorUid'] == uid) {
          tx.set(sponsorRef, {
            'sponsorUid': FieldValue.delete(),
            'sponsorLinkedAt': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        final forwardRef = _linkRequestRefForPair(uid, sponsorUid);
        final reverseRef = _linkRequestRefForPair(sponsorUid, uid);

        final forwardSnap = await tx.get(forwardRef);
        final reverseSnap = await tx.get(reverseRef);

        if (forwardSnap.exists) {
          tx.set(forwardRef, {
            'status': 'ended',
            'endedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        if (reverseSnap.exists) {
          tx.set(reverseRef, {
            'status': 'ended',
            'endedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } else {
        tx.set(userDoc, {
          'unlinkEmailCode': FieldValue.delete(),
          'unlinkEmailCodeExpiresAt': FieldValue.delete(),
          'unlinkEmailRequestId': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }

  Future<void> createUnlockRequest({
    required String requestType,
    required int durationMinutes,
  }) async {
    final uid = _uid;
    if (uid == null) {
      throw SponsorException('Sign in first.');
    }

    final me = _auth.currentUser;
    final sponsorUid = await getSponsorUid();
    if (sponsorUid == null) {
      throw SponsorException('Link a sponsor first.');
    }

    final requestId = _unlockRequestId(uid, requestType);
    final requestRef = _requestsCollectionRef.doc(requestId);

    await _firestore.runTransaction((tx) async {
      final existingSnap = await tx.get(requestRef);
      final existingData = existingSnap.data();

      if (existingData != null) {
        final existing = SponsorRequest.fromDoc(existingSnap.id, existingData);

        final stillActive = !existing.isConsumed &&
            (existing.isPending || (existing.isApproved && !existing.isExpired));

        // If a pending request exists, silently succeed — the UI will show
        // the existing request state via the outgoing stream. Throwing here
        // confuses the user who just wants to re-send or check the status.
        if (stillActive && existing.isPending) return;

        // If it was approved and not yet expired, let it complete naturally.
        if (stillActive && existing.isApproved && !existing.isExpired) return;
      }

      tx.set(requestRef, {
        'requesterUid': uid,
        'requesterName': me?.displayName?.trim().isNotEmpty == true
            ? me!.displayName!.trim()
            : (me?.email ?? 'Detox user'),
        'sponsorUid': sponsorUid,
        'requestType': requestType,
        'status': 'pending',
        'durationMinutes': durationMinutes,
        'createdAt': FieldValue.serverTimestamp(),
        'code': FieldValue.delete(),
        'approvedAt': FieldValue.delete(),
        'consumedAt': FieldValue.delete(),
        'expiresAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
    await StorageService().incrementPauseRequests();
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

      items.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

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

      items.sort(
            (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );

      return items;
    });
  }

  Future<String> approveRequest(String requestId) async {
    final uid = _uid;
    if (uid == null) {
      throw SponsorException('Sign in first.');
    }

    final ref = _requestsCollectionRef.doc(requestId);

    return _firestore.runTransaction<String>((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();

      if (data == null) {
        throw SponsorException('Request not found.');
      }

      final request = SponsorRequest.fromDoc(snap.id, data);

      if (request.sponsorUid != uid) {
        throw SponsorException('That request does not belong to you.');
      }

      if (request.isApproved && !request.isExpired && request.code != null) {
        return request.code!;
      }

      if (!request.isPending) {
        throw SponsorException('This request can no longer be approved.');
      }

      final code = _generateNumericCode();

      tx.set(ref, {
        'status': 'approved',
        'code': code,
        'approvedAt': FieldValue.serverTimestamp(),
        'expiresAt':
        Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 3))),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return code;
    });
  }

  Future<int> consumeCode({
    required String code,
    required String requestType,
  }) async {
    final uid = _uid;
    final userDoc = _userDoc;

    if (uid == null || userDoc == null) {
      throw SponsorException('Sign in first.');
    }

    final normalized = code.trim();
    if (normalized.isEmpty) {
      throw SponsorException('Enter the sponsor code.');
    }

    final requestRef = _requestsCollectionRef.doc(_unlockRequestId(uid, requestType));

    return _firestore.runTransaction<int>((tx) async {
      final requestSnap = await tx.get(requestRef);
      final data = requestSnap.data();

      if (data == null) {
        throw SponsorException('That code is invalid or expired.');
      }

      final request = SponsorRequest.fromDoc(requestSnap.id, data);

      if (request.requesterUid != uid ||
          request.requestType != requestType ||
          request.code != normalized ||
          !request.isApproved ||
          request.isExpired) {
        throw SponsorException('That code is invalid or expired.');
      }

      if (request.isConsumed) {
        throw SponsorException('That code was already used.');
      }

      if (requestType == 'unlink_sponsor') {
        final userSnap = await tx.get(userDoc);
        final userData = userSnap.data() ?? <String, dynamic>{};
        final sponsorUid = userData['sponsorUid'] as String?;

        tx.set(requestRef, {
          'status': 'consumed',
          'consumedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        tx.set(userDoc, {
          'sponsorUid': FieldValue.delete(),
          'sponsorLinkedAt': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (sponsorUid != null && sponsorUid.isNotEmpty) {
          final sponsorRef = _firestore.collection('users').doc(sponsorUid);
          final sponsorSnap = await tx.get(sponsorRef);
          final sponsorData = sponsorSnap.data() ?? <String, dynamic>{};

          if (sponsorData['sponsorUid'] == uid) {
            tx.set(sponsorRef, {
              'sponsorUid': FieldValue.delete(),
              'sponsorLinkedAt': FieldValue.delete(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }

          final forwardRef = _linkRequestRefForPair(uid, sponsorUid);
          final reverseRef = _linkRequestRefForPair(sponsorUid, uid);

          final forwardSnap = await tx.get(forwardRef);
          final reverseSnap = await tx.get(reverseRef);

          if (forwardSnap.exists) {
            tx.set(forwardRef, {
              'status': 'ended',
              'endedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }

          if (reverseSnap.exists) {
            tx.set(reverseRef, {
              'status': 'ended',
              'endedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        }

        return 0;
      }

      final until = DateTime.now().add(Duration(minutes: request.durationMinutes));
      final field = requestType == 'settings_unlock'
          ? 'settingsUnlockUntil'
          : requestType == 'shield_pause'
          ? 'shieldPauseUntil'
          : 'zoneOverrideUntil';

      // For shield_pause consumed via code, clear the timestamp so the
      // FocusBlockerService Firestore listener stops treating it as active.
      final Map<String, dynamic> userUpdate = {
        field: requestType == 'shield_pause'
            ? FieldValue.delete()
            : Timestamp.fromDate(until),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      tx.set(userDoc, userUpdate, SetOptions(merge: true));

      tx.set(requestRef, {
        'status': 'consumed',
        'consumedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return request.durationMinutes;
    });
  }

  Future<bool> hasActiveSettingsUnlock() async =>
      _hasActiveTimestamp('settingsUnlockUntil');

  Future<bool> hasActiveZoneOverride() async =>
      _hasActiveTimestamp('zoneOverrideUntil');

  Future<DateTime?> getSettingsUnlockUntil() async =>
      _getTimestamp('settingsUnlockUntil');

  Future<DateTime?> getZoneOverrideUntil() async =>
      _getTimestamp('zoneOverrideUntil');

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

    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }

    return null;
  }

  Stream<List<SponsorRequest>> incomingHistory() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _requestsCollectionRef
        .where('sponsorUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs
        .map((doc) => SponsorRequest.fromDoc(doc.id, doc.data()))
        .toList());
  }

  Stream<List<SponsorRequest>> outgoingHistory() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _requestsCollectionRef
        .where('requesterUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(12)
        .snapshots()
        .map((snap) => snap.docs
        .map((doc) => SponsorRequest.fromDoc(doc.id, doc.data()))
        .toList());
  }

  String _generateNumericCode() =>
      (100000 + _random.nextInt(900000)).toString();

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

      if (query.docs.isEmpty) {
        return code;
      }
    }
  }
}