import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/db/folder_db.dart';
import 'package:photos/db/file_db.dart';
import 'package:photos/events/remote_sync_event.dart';
import 'package:photos/events/user_authenticated_event.dart';
import 'package:photos/models/folder.dart';
import 'package:photos/models/file.dart';

import 'core/event_bus.dart';

class FolderSharingService {
  final _logger = Logger("FolderSharingService");
  final _dio = Dio();
  static final _diffLimit = 100;

  bool _isSyncInProgress = false;

  FolderSharingService._privateConstructor() {
    Bus.instance.on<UserAuthenticatedEvent>().listen((event) {
      sync();
    });
  }

  static final FolderSharingService instance =
      FolderSharingService._privateConstructor();

  Future<void> sync() {
    _logger.info("Syncing...");
    if (_isSyncInProgress || !Configuration.instance.hasConfiguredAccount()) {
      return Future.value();
    }
    _isSyncInProgress = true;
    return getFolders().then((f) async {
      var folders = f.toSet();
      var currentFolders = await FolderDB.instance.getFolders();
      for (final currentFolder in currentFolders) {
        if (!folders.contains(currentFolder)) {
          _logger.info("Folder deleted: " + currentFolder.toString());
          await FileDB.instance.deleteFilesInRemoteFolder(currentFolder.id);
          await FolderDB.instance.deleteFolder(currentFolder);
        }
      }
      for (final folder in folders) {
        if (folder.owner != Configuration.instance.getUsername()) {
          await syncDiff(folder);
          await FolderDB.instance.putFolder(folder);
        }
      }
      Bus.instance.fire(RemoteSyncEvent(true));
      _isSyncInProgress = false;
      return Future.value();
    });
  }

  Future<void> syncDiff(Folder folder) async {
    int lastSyncTimestamp = 0;
    try {
      File file =
          await FileDB.instance.getLastSyncedFileInRemoteFolder(folder.id);
      lastSyncTimestamp = file.updationTime;
    } catch (e) {
      // Folder has never been synced
    }
    var diff = await getDiff(folder.id, lastSyncTimestamp, _diffLimit);
    for (File file in diff) {
      try {
        var existingPhoto =
            await FileDB.instance.getMatchingRemoteFile(file.uploadedFileId);
        await FileDB.instance.update(
            existingPhoto.generatedId,
            file.uploadedFileId,
            file.remotePath,
            file.updationTime,
            file.previewURL);
      } catch (e) {
        await FileDB.instance.insert(file);
      }
    }
    if (diff.length == _diffLimit) {
      await syncDiff(folder);
    }
  }

  Future<List<File>> getDiff(
      int folderId, int sinceTimestamp, int limit) async {
    Response response = await _dio.get(
      Configuration.instance.getHttpEndpoint() +
          "/folders/diff/" +
          folderId.toString(),
      options:
          Options(headers: {"X-Auth-Token": Configuration.instance.getToken()}),
      queryParameters: {
        "sinceTimestamp": sinceTimestamp,
        "limit": limit,
      },
    ).catchError((e) => _logger.severe(e));
    if (response != null) {
      return (response.data["diff"] as List).map((p) {
        File file = new File.fromJson(p);
        file.localId = null;
        file.remoteFolderId = folderId;
        return file;
      }).toList();
    } else {
      return List<File>();
    }
  }

  Future<List<Folder>> getFolders() async {
    return _dio
        .get(
      Configuration.instance.getHttpEndpoint() + "/folders/",
      options:
          Options(headers: {"X-Auth-Token": Configuration.instance.getToken()}),
    )
        .then((foldersResponse) {
      return (foldersResponse.data as List)
          .map((f) => Folder.fromMap(f))
          .toList();
    });
  }

  Future<Folder> getFolder(String deviceFolder) async {
    return _dio
        .get(
      Configuration.instance.getHttpEndpoint() + "/folders/folder/",
      queryParameters: {
        "deviceFolder": deviceFolder,
      },
      options:
          Options(headers: {"X-Auth-Token": Configuration.instance.getToken()}),
    )
        .then((response) {
      return Folder.fromMap(response.data);
    }).catchError((e) {
      return Folder(
        null,
        Configuration.instance.getUsername() + "s " + deviceFolder,
        Configuration.instance.getUsername(),
        deviceFolder,
        Set<String>(),
        null,
      );
    });
  }

  Future<Map<String, bool>> getSharingStatus(Folder folder) async {
    return _dio
        .get(
      Configuration.instance.getHttpEndpoint() + "/users",
      options:
          Options(headers: {"X-Auth-Token": Configuration.instance.getToken()}),
    )
        .then((response) {
      final users = (response.data["users"] as List).toList();
      final result = Map<String, bool>();
      for (final user in users) {
        if (user != Configuration.instance.getUsername()) {
          result[user] = folder.sharedWith.contains(user);
        }
      }
      return result;
    });
  }

  Future<void> updateFolder(Folder folder) {
    log("Updating folder: " + folder.toString());
    return _dio
        .put(Configuration.instance.getHttpEndpoint() + "/folders/",
            options: Options(
                headers: {"X-Auth-Token": Configuration.instance.getToken()}),
            data: folder.toMap())
        .then((response) => log(response.toString()))
        .catchError((error) => log(error.toString()));
  }
}
