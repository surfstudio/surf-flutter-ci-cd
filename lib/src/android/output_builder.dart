// ignore_for_file: avoid_print, one_member_abstracts

import 'dart:io';

import 'package:surf_flutter_ci_cd/src/enums/android/apk_prefix.dart';
import 'package:surf_flutter_ci_cd/src/output_builder/i_output_builder.dart';
import 'package:surf_flutter_ci_cd/src/util/printer.dart';

const _apkPath = 'build/app/outputs/flutter-apk/';

Future<void> _renameFile({
  required String filePath,
  required String newFilePath,
  required String currentName,
  required String newName,
}) async {
  final file = File(filePath + currentName);
  await file.rename(newFilePath + newName);

  Printer.printSuccess('$currentName renamed to $newName');
}

class ApkBuilder implements IOutputBuilder {
  @override
  Future<void> build({
    required String flavor,
    required String buildType,
  }) async {
    final jenkinsArchiveArtifactsLocation =
        'build/app/outputs/apk/$flavor/release/';

    await _buildApk(flavor: flavor, buildType: buildType);
    await _renameApk(
      buildType: buildType,
      jenkinsArchiveArtifactsLocation: jenkinsArchiveArtifactsLocation,
      flavor: flavor,
    );
  }

  Future<void> _buildApk({
    required String flavor,
    required String buildType,
  }) async {
    Printer.printWarning(
      'Build type: $buildType, Format: apk, Flavor: $flavor',
    );

    final result = await Process.run(
      'fvm',
      [
        'flutter',
        'build',
        'apk',
        '-t',
        'lib/main_$buildType.dart',
        '--flavor',
        flavor,
        '--split-per-abi',
      ],
    );
    stdout.write(result.stdout);
    stderr.write(result.stderr);
  }

  Future<void> _renameApk({
    required String buildType,
    required String jenkinsArchiveArtifactsLocation,
    required String flavor,
  }) async {
    final postfix = buildType;

    Printer.printWarning('\x1B[33mPostfix: $postfix\x1B[0m');
    Printer.printNormal('Making postfix ...');

    Printer.printNormal('Making subdirectory for $postfix');
    await Directory(jenkinsArchiveArtifactsLocation).create(recursive: true);

    const prefixes = [ApkPrefix.v7, ApkPrefix.x86, ApkPrefix.x64];

    for (final prefix in prefixes) {
      final currentName = 'app-$prefix-$flavor-release.apk';
      final newName = 'app-$postfix-$prefix.apk';
      await _renameFile(
        filePath: _apkPath,
        newFilePath: jenkinsArchiveArtifactsLocation,
        currentName: currentName,
        newName: newName,
      );
    }
  }
}

class AppBundleBuilder implements IOutputBuilder {
  @override
  Future<void> build({
    required String flavor,
    required String buildType,
  }) async {
    final jenkinsArchiveArtifactsLocation =
        'build/app/outputs/bundle/$flavor/release/';

    await _buildAppBundle(buildType: buildType, flavor: flavor);
    await _ranameAppBundle(
      buildType: buildType,
      jenkinsArchiveArtifactsLocation: jenkinsArchiveArtifactsLocation,
      flavor: flavor,
    );
  }

  Future<void> _buildAppBundle({
    required String buildType,
    required String flavor,
  }) async {
    Printer.printWarning(
      'Build type: $buildType, Format: appbundle, Flavor: $flavor',
    );

    final result = await Process.run(
      'fvm',
      [
        'flutter',
        'build',
        'appbundle',
        '-t',
        'lib/main_$buildType.dart',
        '--flavor',
        flavor,
      ],
    );
    stdout.write(result.stdout);
    stderr.write(result.stderr);
  }

  Future<void> _ranameAppBundle({
    required String buildType,
    required String jenkinsArchiveArtifactsLocation,
    required String flavor,
  }) async {
    final postfix = buildType;

    Printer.printWarning('Postfix: $postfix');
    Printer.printNormal('Making postfix ...');

    Printer.printNormal('Making subdirectory for $postfix');
    await Directory(jenkinsArchiveArtifactsLocation).create(recursive: true);
    final name = 'app-$flavor-release.aab';

    final newName = 'app-$postfix.aab';

    await _renameFile(
      filePath: _appBundlePath(flavor),
      newFilePath: jenkinsArchiveArtifactsLocation,
      currentName: name,
      newName: newName,
    );
  }

  String _appBundlePath(String flavor) =>
      'build/app/outputs/bundle/${flavor}Release/';
}
