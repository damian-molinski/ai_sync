import 'dart:io';

/// Deletes all entries in [dirPath].
///
/// When [preserveSymlinks] is true, any entry where
/// `FileSystemEntity.isLinkSync()` returns true is skipped — this is used to
/// preserve instruction symlinks (e.g. `GEMINI.md`) during a rules clean.
///
/// Does nothing if the directory does not exist.
void cleanDirectory(String dirPath, {bool preserveSymlinks = false}) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) return;
  for (final entity in dir.listSync()) {
    if (preserveSymlinks && FileSystemEntity.isLinkSync(entity.path)) continue;
    entity.deleteSync(recursive: true);
  }
}

/// Creates [dirPath] and all intermediate parents if they do not exist.
void ensureDirectory(String dirPath) {
  Directory(dirPath).createSync(recursive: true);
}

/// Creates a symbolic link at [linkPath] pointing to [targetPath].
///
/// Removes any existing file, directory, or symlink at [linkPath] first.
/// Creates parent directories of [linkPath] if missing.
void createSymlink(String targetPath, String linkPath) {
  ensureDirectory(File(linkPath).parent.path);
  final link = Link(linkPath);
  if (link.existsSync() || File(linkPath).existsSync() || Directory(linkPath).existsSync()) {
    FileSystemEntity.isLinkSync(linkPath)
        ? link.deleteSync()
        : FileSystemEntity.typeSync(linkPath) == FileSystemEntityType.directory
        ? Directory(linkPath).deleteSync(recursive: true)
        : File(linkPath).deleteSync();
  }
  link.createSync(targetPath);
}

/// Writes [content] to [filePath], creating parent directories as needed.
void writeFileString(String filePath, String content) {
  ensureDirectory(File(filePath).parent.path);
  File(filePath).writeAsStringSync(content);
}

/// Deletes the file, directory, or symlink at [path] if it exists.
///
/// For directories, deletes recursively. For symlinks, deletes the link itself
/// without following it.
void deleteIfExists(String path) {
  if (FileSystemEntity.isLinkSync(path)) {
    Link(path).deleteSync();
  } else if (File(path).existsSync()) {
    File(path).deleteSync();
  } else if (Directory(path).existsSync()) {
    Directory(path).deleteSync(recursive: true);
  }
}

/// Deletes [dirPath] if it exists and is empty.
///
/// Does nothing if the directory does not exist or still has entries.
void removeIfEmptyDirectory(String dirPath) {
  final dir = Directory(dirPath);
  if (dir.existsSync() && dir.listSync().isEmpty) {
    dir.deleteSync();
  }
}
