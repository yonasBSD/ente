import 'dart:core';

import 'package:flutter/foundation.dart';
import "package:photos/core/configuration.dart";
import "package:photos/extensions/user_extension.dart";
import "package:photos/models/api/collection/public_url.dart";
import "package:photos/models/api/collection/user.dart";
import "package:photos/models/metadata/collection_magic.dart";
import "package:photos/models/metadata/common_keys.dart";

class Collection {
  final int id;
  final User owner;
  final String encryptedKey;
  final String? keyDecryptionNonce;
  @Deprecated("Use collectionName instead")
  String? name;

  // encryptedName & nameDecryptionNonce will be null for collections
  // created before we started encrypting collection name
  final String? encryptedName;
  final String? nameDecryptionNonce;
  final CollectionType type;
  final CollectionAttributes attributes;
  final List<User> sharees;
  final List<PublicURL> publicURLs;
  final int updationTime;
  final bool isDeleted;

  // In early days before public launch, we used to store collection name
  // un-encrypted. decryptName will be value either decrypted value for
  // encryptedName or name itself.
  String? decryptedName;

  // decryptedPath will be null for collections now owned by user, deleted
  // collections, && collections which don't have a path. The path is used
  // to map local on-device album on mobile to remote collection on ente.
  String? decryptedPath;
  String? mMdEncodedJson;
  String? mMdPubEncodedJson;
  String? sharedMmdJson;
  int mMdVersion = 0;
  int mMbPubVersion = 0;
  int sharedMmdVersion = 0;
  CollectionMagicMetadata? _mmd;
  CollectionPubMagicMetadata? _pubMmd;
  ShareeMagicMetadata? _sharedMmd;

  CollectionMagicMetadata get magicMetadata =>
      _mmd ?? CollectionMagicMetadata.fromEncodedJson(mMdEncodedJson ?? '{}');

  CollectionPubMagicMetadata get pubMagicMetadata =>
      _pubMmd ??
      CollectionPubMagicMetadata.fromEncodedJson(mMdPubEncodedJson ?? '{}');

  ShareeMagicMetadata get sharedMagicMetadata =>
      _sharedMmd ?? ShareeMagicMetadata.fromEncodedJson(sharedMmdJson ?? '{}');

  set magicMetadata(CollectionMagicMetadata? val) => _mmd = val;

  set pubMagicMetadata(CollectionPubMagicMetadata? val) => _pubMmd = val;

  set sharedMagicMetadata(ShareeMagicMetadata? val) => _sharedMmd = val;

  // ignore: deprecated_member_use_from_same_package
  String get displayName {
    if (!isDeleted &&
        type == CollectionType.favorites &&
        !isOwner(Configuration.instance.getUserID() ?? -1)) {
      return '${owner.nameOrEmail}\'s favorites';
    }
    return decryptedName ?? name ?? "Unnamed Album";
  }

  // set the value for both name and decryptedName till we finish migration
  void setName(String newName) {
    // ignore: deprecated_member_use_from_same_package
    name = newName;
    decryptedName = newName;
  }

  Collection(
    this.id,
    this.owner,
    this.encryptedKey,
    this.keyDecryptionNonce,
    this.name,
    this.encryptedName,
    this.nameDecryptionNonce,
    this.type,
    this.attributes,
    this.sharees,
    this.publicURLs,
    this.updationTime, {
    this.isDeleted = false,
  });

  bool isArchived() {
    return mMdVersion > 0 && magicMetadata.visibility == archiveVisibility;
  }

  bool hasShareeArchived() {
    return sharedMmdVersion > 0 &&
        sharedMagicMetadata.visibility == archiveVisibility;
  }

  // hasLink returns true if there's any link attached to the collection
  // including expired links
  bool get hasLink => publicURLs.isNotEmpty;

  bool get hasCover => (pubMagicMetadata.coverID ?? 0) > 0;

  // hasSharees returns true if the collection is shared with other ente users
  bool get hasSharees => sharees.isNotEmpty;

  bool get isPinned => (magicMetadata.order ?? 0) != 0;

  bool isHidden() {
    if (isDefaultHidden()) {
      return true;
    }
    return mMdVersion > 0 && (magicMetadata.visibility == hiddenVisibility);
  }

  bool isDefaultHidden() {
    return (magicMetadata.subType ?? 0) == subTypeDefaultHidden;
  }

  bool isQuickLinkCollection() {
    return (magicMetadata.subType ?? 0) == subTypeSharedFilesCollection &&
        !hasSharees;
  }

  List<User> getSharees() {
    return sharees;
  }

  bool isOwner(int userID) {
    return (owner.id ?? -100) == userID;
  }

  bool canAutoAdd(int userID) {
    final canEditCollection = isOwner(userID) ||
        getRole(userID) == CollectionParticipantRole.collaborator;
    final isFavoritesOrUncategorized = type == CollectionType.favorites ||
        type == CollectionType.uncategorized;
    return canEditCollection && !isDeleted && !isFavoritesOrUncategorized;
  }

  bool isDownloadEnabledForPublicLink() {
    if (publicURLs.isEmpty) {
      return false;
    }
    return publicURLs.first.enableDownload;
  }

  bool isCollectEnabledForPublicLink() {
    if (publicURLs.isEmpty) {
      return false;
    }
    return publicURLs.first.enableCollect;
  }

  bool get isJoinEnabled {
    if (publicURLs.isEmpty) {
      return false;
    }
    return publicURLs.first.enableJoin;
  }

  CollectionParticipantRole getRole(int userID) {
    if (isOwner(userID)) {
      return CollectionParticipantRole.owner;
    }
    if (sharees.isEmpty) {
      return CollectionParticipantRole.unknown;
    }
    for (final User u in sharees) {
      if (u.id == userID) {
        if (u.isViewer) {
          return CollectionParticipantRole.viewer;
        } else if (u.isCollaborator) {
          return CollectionParticipantRole.collaborator;
        }
      }
    }
    return CollectionParticipantRole.unknown;
  }

  // canLinkToDevicePath returns true if the collection can be linked to local
  // device album based on path. The path is nothing but the name of the device
  // album.
  bool canLinkToDevicePath(int userID) {
    return isOwner(userID) && !isDeleted && attributes.encryptedPath != null;
  }

  void updateSharees(List<User> newSharees) {
    sharees.clear();
    sharees.addAll(newSharees);
  }

  Collection copyWith({
    int? id,
    User? owner,
    String? encryptedKey,
    String? keyDecryptionNonce,
    String? name,
    String? encryptedName,
    String? nameDecryptionNonce,
    CollectionType? type,
    CollectionAttributes? attributes,
    List<User>? sharees,
    List<PublicURL>? publicURLs,
    int? updationTime,
    bool? isDeleted,
    String? mMdEncodedJson,
    int? mMdVersion,
    String? decryptedName,
    String? decryptedPath,
  }) {
    final Collection result = Collection(
      id ?? this.id,
      owner ?? this.owner,
      encryptedKey ?? this.encryptedKey,
      keyDecryptionNonce ?? this.keyDecryptionNonce,
      // ignore: deprecated_member_use_from_same_package
      name ?? this.name,
      encryptedName ?? this.encryptedName,
      nameDecryptionNonce ?? this.nameDecryptionNonce,
      type ?? this.type,
      attributes ?? this.attributes,
      sharees ?? this.sharees,
      publicURLs ?? this.publicURLs,
      updationTime ?? this.updationTime,
      isDeleted: isDeleted ?? this.isDeleted,
    );
    result.mMdVersion = mMdVersion ?? this.mMdVersion;
    result.mMdEncodedJson = mMdEncodedJson ?? this.mMdEncodedJson;
    result.decryptedName = decryptedName ?? this.decryptedName;
    result.decryptedPath = decryptedPath ?? this.decryptedPath;
    result.mMbPubVersion = mMbPubVersion;
    result.mMdPubEncodedJson = mMdPubEncodedJson;
    result.sharedMmdVersion = sharedMmdVersion;
    result.sharedMmdJson = sharedMmdJson;
    return result;
  }

  static fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final sharees = (map['sharees'] == null || map['sharees'].length == 0)
        ? <User>[]
        : List<User>.from(map['sharees'].map((x) => User.fromMap(x)));
    final publicURLs =
        (map['publicURLs'] == null || map['publicURLs'].length == 0)
            ? <PublicURL>[]
            : List<PublicURL>.from(
                map['publicURLs'].map((x) => PublicURL.fromMap(x)),
              );
    return Collection(
      map['id'],
      User.fromMap(map['owner']),
      map['encryptedKey'],
      map['keyDecryptionNonce'],
      map['name'],
      map['encryptedName'],
      map['nameDecryptionNonce'],
      typeFromString(map['type']),
      CollectionAttributes.fromMap(map['attributes']),
      sharees,
      publicURLs,
      map['updationTime'],
      isDeleted: map['isDeleted'] ?? false,
    );
  }
}

enum CollectionType {
  folder,
  favorites,
  uncategorized,
  album,
  unknown,
}

CollectionType typeFromString(String type) {
  switch (type) {
    case "folder":
      return CollectionType.folder;
    case "favorites":
      return CollectionType.favorites;
    case "uncategorized":
      return CollectionType.uncategorized;
    case "album":
      return CollectionType.album;
    case "unknown":
      return CollectionType.unknown;
  }
  debugPrint("unexpected collection type $type");
  return CollectionType.unknown;
}

String typeToString(CollectionType type) {
  switch (type) {
    case CollectionType.folder:
      return "folder";
    case CollectionType.favorites:
      return "favorites";
    case CollectionType.album:
      return "album";
    case CollectionType.uncategorized:
      return "uncategorized";
    case CollectionType.unknown:
      return "unknown";
  }
}

extension CollectionTypeExtn on CollectionType {
  bool get canDelete =>
      this != CollectionType.favorites && this != CollectionType.uncategorized;
}

enum CollectionParticipantRole {
  unknown,
  viewer,
  collaborator,
  owner,
}

extension CollectionParticipantRoleExtn on CollectionParticipantRole {
  static CollectionParticipantRole fromString(String? val) {
    if ((val ?? '') == '') {
      return CollectionParticipantRole.viewer;
    }
    for (var x in CollectionParticipantRole.values) {
      if (x.name.toUpperCase() == val!.toUpperCase()) {
        return x;
      }
    }
    return CollectionParticipantRole.unknown;
  }

  String toStringVal() {
    return name.toUpperCase();
  }
}

class CollectionAttributes {
  final String? encryptedPath;
  final String? pathDecryptionNonce;
  final int? version;

  CollectionAttributes({
    this.encryptedPath,
    this.pathDecryptionNonce,
    this.version,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (encryptedPath != null) {
      map['encryptedPath'] = encryptedPath;
    }
    if (pathDecryptionNonce != null) {
      map['pathDecryptionNonce'] = pathDecryptionNonce;
    }
    map['version'] = version ?? 0;
    return map;
  }

  static fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;

    return CollectionAttributes(
      encryptedPath: map['encryptedPath'],
      pathDecryptionNonce: map['pathDecryptionNonce'],
      version: map['version'] ?? 0,
    );
  }
}
