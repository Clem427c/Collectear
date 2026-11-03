import 'dart:io';

import 'package:collectear/core/about.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('À propos', () {
    test('libellé de version avec ou sans numéro de build', () {
      expect(versionLabel(version: '1.2.3', build: ''), '1.2.3');
      expect(versionLabel(version: '1.2.3', build: '57'), '1.2.3 (build 57)');
      expect(versionLabel(version: '1.2.3', build: ' 57 '), '1.2.3 (build 57)');
      expect(versionLabel(version: '1.2.3', build: 'abc'), '1.2.3');
      expect(versionLabel(version: '1.2.3', build: '0'), '1.2.3');
      expect(versionLabel(version: '1.2.3', build: '-4'), '1.2.3');
    });

    test('la version du jeu est celle de pubspec.yaml', () {
      final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
      final pubspecVersion = line.substring('version:'.length).trim().split('+').first;
      expect(kGameVersion, pubspecVersion);
    });

    test('la version du jeu est la dernière du journal', () {
      final first = File('CHANGELOG.md').readAsLinesSync().firstWhere((l) => l.startsWith('## '));
      expect(first.startsWith('## $kGameVersion '), isTrue, reason: first);
    });

    test('liens : https, pages publiées par la CI', () {
      expect(kAboutLinks, isNotEmpty);
      for (final l in kAboutLinks) {
        expect(isSafeLink(l.url), isTrue, reason: l.url);
        expect(l.url.startsWith(kWebGameUrl), isTrue, reason: l.url);
      }
      expect(kAboutLinks.map((l) => l.url), containsAll([kPrivacyUrl, kAccountDeletionUrl]));
      // Les pages existent bien dans le site publié.
      expect(File('docs/site/confidentialite.html').existsSync(), isTrue);
      expect(File('docs/site/suppression-compte.html').existsSync(), isTrue);
    });

    test('liens refusés', () {
      expect(isSafeLink('http://exemple.fr'), isFalse);
      expect(isSafeLink('javascript:alert(1)'), isFalse);
      expect(isSafeLink('https://'), isFalse);
      expect(isSafeLink(''), isFalse);
    });
  });
}
