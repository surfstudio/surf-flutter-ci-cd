import 'dart:io';

import 'package:args/args.dart';
import 'package:surf_flutter_ci_cd/src/deployer.dart';
import 'package:surf_flutter_ci_cd/src/util/printer.dart';
import 'package:surf_flutter_ci_cd/surf_flutter_ci_cd.dart';
import 'package:yaml/yaml.dart';

/// Типы возможных таргетов для сборки проекта.
enum TargetType { android, ios }

/// Типы возможных таргетов для деплоя проекта.


class FlagsName {
  static const environment = 'env';
  static const project = 'proj';
  static const target = 'target';
  static const deploy = 'deploy-to';
}

class MessageShow {
  static Never exitWithShowUsage(ArgParser parser) {
    print(_usage);
    print(parser.usage);
    exit(1);
  }

  static const _usage =
      'Usage: flutter pub run surf_flutter_ci_cd [build|deploy|full] --env=<environment> --proj=<project> --target=<target platform>';
}

void main(List<String> arguments) {
  var parser = ArgParser();
  parser.addOption(FlagsName.environment, abbr: 'e', help: 'Environment name');
  parser.addOption(FlagsName.project, abbr: 'p', help: 'Project name');
  parser.addOption(FlagsName.target, abbr: 't', help: 'Target platform');
  parser.addOption(FlagsName.deploy, abbr: 'd', help: 'Deploy to platform');

  final String? env;
  final String? proj;
  final String? target;
  final String? deployTo;
  final ArgResults results;

  try {
    results = parser.parse(arguments);
    env = results[FlagsName.environment];
    proj = results[FlagsName.project];
    target = results[FlagsName.target];
    deployTo = results[FlagsName.deploy];
  } on Object catch (e) {
    Printer.printError(e.toString());
    exit(1);
  }

  if (arguments.isEmpty ||
      arguments.contains('-h') ||
      arguments.contains('--help')) {
    MessageShow.exitWithShowUsage(parser);
  }

  if (env == null || proj == null || target == null) {
    print('Missing arguments.');
    MessageShow.exitWithShowUsage(parser);
  }

  switch (results.rest.isNotEmpty ? results.rest[0] : '') {
    case 'build':
      Printer.printNormal('Building $proj for $target in $env environment');
      _build(proj, env, target);
      break;
    case 'deploy':
      if (deployTo == null) {
        Printer.printError('Please specify the flag deploy.');
        MessageShow.exitWithShowUsage(parser);
      }
      Printer.printNormal('Deploying $proj for $target in $env environment.');
      _deploy(proj, env, target, deployTo);
      break;
    case 'full':
      if (deployTo == null) {
        Printer.printError('Please specify the flag deploy.');
        MessageShow.exitWithShowUsage(parser);
      }
      _buildAndDeploy(proj, env, target, deployTo);
      break;
    default:
      Printer.printError('Invalid command.');
      MessageShow.exitWithShowUsage(parser);
  }
}

Future<void> _buildAndDeploy(
  String proj,
  String env,
  String target,
  String deployTo,
) async {
  Printer.printNormal('Building $proj for $target in $env environment');
  await _build(proj, env, target);
  Printer.printNormal('Deploying $proj for $target in $env environment');
  await _deploy(proj, env, target, deployTo);
}

Future<void> _build(
  String proj,
  String env,
  String target,
) async {
  final yamlContent = await File('cd.yaml').readAsString();
  final config = loadYaml(yamlContent) as Map;
  final flavor = config[proj][env][target]['build']['flavor'] as String;
  final entryPointPath = config[proj][env]['file_path'] as String;
  final flags = config[proj][env][target]['build']['flags'] as String;
  final extension = config[proj][env][target]['build']['extension'] as String;

  switch (target) {
    case 'android':
      Printer.printWarning('Android build started');
      await buildAndroidOutput(
        flavor: flavor,
        buildType: env,
        entryPointPath: entryPointPath,
        projectName: proj,
        format: PublishingFormat.fromString(extension) ?? PublishingFormat.apk,
        flags: flags,
      );
      break;
    case 'ios':
      Printer.printWarning('Ios build started');
      await buildIosOutput(
        flavor: flavor,
        buildType: env,
        entryPointPath: entryPointPath,
        flags: flags,
      );
      break;
    default:
      Printer.printError(
          'Invalid command. Use [build|deploy] --env=<environment> --proj=<project> --target=<target platform> --deploy-to=<deploy platform>');
      exit(1);
  }
}

Future<void> _deploy(
  String proj,
  String env,
  String target,
  String deployTo,
) async {
  final yamlContent = await File('cd.yaml').readAsString();
  final config = loadYaml(yamlContent) as Map;

  final secretsYaml = File('secrets.yaml');
  final Map<dynamic, dynamic> secretsMap = {};
  final String? token;
  final String? testflightKeyId;
  final String? testflightIssuerId;
  if (secretsYaml.existsSync()) {
    secretsMap.addAll(
        loadYaml(await secretsYaml.readAsString()) as Map<dynamic, dynamic>);
    token = secretsMap['firebase_token'] as String;
    testflightKeyId = secretsMap['testflight_key_id'] as String;
    testflightIssuerId = secretsMap['testflight_issuer_id'] as String;
    Printer.printWarning('''Local deploy with secrets:
    firebase_token: $token
    testflight_key_id: $testflightKeyId
    testflight_issuer_id: $testflightIssuerId
''');
  } else {
    token = null;
    testflightKeyId = null;
    testflightIssuerId = null;
    Printer.printWarning('Remote deploy');
  }

  switch (target) {
    case 'android':
      switch (deployTo) {
        // Firebase
        case 'fb':
          final appId = config[proj][env][target]['deploy']['firebase']
              ['firebase_app_id'] as String;
          final groups = config[proj][env][target]['deploy']['firebase']
              ['groups'] as String;
          final flavor = config[proj][env][target]['build']['flavor'] as String;

          await deployAndroidToFirebase(
            appId: appId,
            groups: groups,
            flavor: flavor,
            token: token,
          );
          break;
        case 'gp':
          final flavor = config[proj][env][target]['build']['flavor'] as String;
          final packageName = config[proj][env][target]['deploy']['google_play']
              ['package_name'] as String;

          await deployAndroidToGPC(
            packageName: packageName,
            flavor: flavor,
          );
          break;
        default:
          Printer.printError(
              'Wrong deployTo param for android. Current value: $deployTo');
          exit(1);
      }
      break;
    case 'ios':
      switch (deployTo) {
        // TestFlight
        case 'tf':
          await deployIosToTestFlight(
              keyId: testflightKeyId, issuerId: testflightIssuerId);
          break;
        case 'fb':
          final appId = config[proj][env][target]['deploy']['firebase']
              ['firebase_app_id'] as String;
          final groups = config[proj][env][target]['deploy']['firebase']
              ['groups'] as String;
          deployIosToFirebase(appId: appId, groups: groups, token: token);

          break;
        default:
          Printer.printError(
              'Wrong deployTo param for ios. Current value: $deployTo');
          exit(1);
      }
      break;
    default:
      Printer.printError('Wrong target param. Current value: $target');
      exit(1);
  }
}
