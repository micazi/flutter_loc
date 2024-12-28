import 'package:darted_cli/io_helper.dart';

import '../../../models/loc_match.model.dart';
import 'apply_custom_refinement.dart';

/// Refine the finds.
Future<Map<String, List<LocMatch>>> refineFinds(
    Map<String, List<LocMatch>> inputFinds,
    {String? customRefinementLogicPath}) async {
  Map<String, List<LocMatch>> outputFinds = inputFinds;
  RefinementIsolate? refinementIsolate;
  if (customRefinementLogicPath != null) {
    // Spawn the custom refinement isolte
    refinementIsolate = RefinementIsolate(IOHelper.directory.getCurrent() +
        Platform.pathSeparator +
        customRefinementLogicPath.replaceSeparator());
  }

  await Future.forEach(inputFinds.entries, (inputEntry) async {
    //S2 -- Per-line enhancements
    await Future.forEach(outputFinds.entries, (findEntry) async {
      List<LocMatch> matches = findEntry.value;

      //1. Remove imports & exports
      matches = matches
        ..removeWhere((matchItem) =>
            (matchItem.lineContent.trim().startsWith('import') ||
                matchItem.lineContent.trim().startsWith('export')));

      //2. Remove One-line comments
      matches = matches
        ..removeWhere(
            (matchItem) => (matchItem.lineContent.trim().startsWith('//')));

      //S2 -- Per-position enhancements
      await Future.forEach(matches, (matchValue) async {
        Map<int, String> newM = {};
        await Future.forEach((matchValue.matchesInLine.entries),
            (mapEntry) async {
          //1.Remove strings followed by tr()
          bool isFollowedByTr = matchValue.lineContent.length >
                  ((mapEntry.key) + mapEntry.value.length) &&
              matchValue.lineContent
                  .substring(mapEntry.key + mapEntry.value.length)
                  .startsWith(r'.tr()');

          //2. Apply custom refinement logic.
          bool failsCustomRefinement = false;
          if (refinementIsolate != null) {
            failsCustomRefinement =
                !await refinementIsolate.applyCustomRefinement(
              inputEntry.key,
              matchValue.lineContent,
              mapEntry.value,
            );
          }

          if (!isFollowedByTr && !failsCustomRefinement) {
            newM.addEntries([mapEntry]);
          }
        });

        matches[matches.indexOf(matchValue)] =
            matchValue.copyWith(matchesInLine: newM);
      });

      outputFinds[findEntry.key] = matches
        ..removeWhere((mm) => mm.matchesInLine.isEmpty);
    });
  });
  return outputFinds;
}