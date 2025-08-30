/// GENERATED CODE - DO NOT MODIFY BY HAND
/// *****************************************************
///  FlutterGen
/// *****************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: directives_ordering,unnecessary_import,implicit_dynamic_list_literal,deprecated_member_use

import 'package:flutter/widgets.dart';

class $AssetsAnimationsGen {
  const $AssetsAnimationsGen();

  /// File path: assets/animations/empty_state.json
  String get emptyState => 'assets/animations/empty_state.json';

  /// File path: assets/animations/no_plan_burgundy.gif
  AssetGenImage get noPlanBurgundy =>
      const AssetGenImage('assets/animations/no_plan_burgundy.gif');

  /// File path: assets/animations/no_plan_pink.gif
  AssetGenImage get noPlanPink =>
      const AssetGenImage('assets/animations/no_plan_pink.gif');

  /// File path: assets/animations/no_plan_slate.gif
  AssetGenImage get noPlanSlate =>
      const AssetGenImage('assets/animations/no_plan_slate.gif');

  /// File path: assets/animations/no_plan_teal.gif
  AssetGenImage get noPlanTeal =>
      const AssetGenImage('assets/animations/no_plan_teal.gif');

  /// List of all assets
  List<dynamic> get values => [
    emptyState,
    noPlanBurgundy,
    noPlanPink,
    noPlanSlate,
    noPlanTeal,
  ];
}

class $AssetsConfigGen {
  const $AssetsConfigGen();

  /// File path: assets/config/emoji_mappings.json
  String get emojiMappings => 'assets/config/emoji_mappings.json';

  /// List of all assets
  List<String> get values => [emojiMappings];
}

class $AssetsImagesGen {
  const $AssetsImagesGen();

  /// File path: assets/images/daily quest planner_burgundy_darklogo.png
  AssetGenImage get dailyQuestPlannerBurgundyDarklogo => const AssetGenImage(
    'assets/images/daily quest planner_burgundy_darklogo.png',
  );

  /// File path: assets/images/daily quest planner_burgundy_lightlogo.png
  AssetGenImage get dailyQuestPlannerBurgundyLightlogo => const AssetGenImage(
    'assets/images/daily quest planner_burgundy_lightlogo.png',
  );

  /// File path: assets/images/daily quest planner_pink_darklogo.png
  AssetGenImage get dailyQuestPlannerPinkDarklogo => const AssetGenImage(
    'assets/images/daily quest planner_pink_darklogo.png',
  );

  /// File path: assets/images/daily quest planner_pink_lightlogo.png
  AssetGenImage get dailyQuestPlannerPinkLightlogo => const AssetGenImage(
    'assets/images/daily quest planner_pink_lightlogo.png',
  );

  /// File path: assets/images/daily quest planner_slate_darklogo.png
  AssetGenImage get dailyQuestPlannerSlateDarklogo => const AssetGenImage(
    'assets/images/daily quest planner_slate_darklogo.png',
  );

  /// File path: assets/images/daily quest planner_slate_lightlogo.png
  AssetGenImage get dailyQuestPlannerSlateLightlogo => const AssetGenImage(
    'assets/images/daily quest planner_slate_lightlogo.png',
  );

  /// File path: assets/images/daily quest planner_teal_darklogo.png
  AssetGenImage get dailyQuestPlannerTealDarklogo => const AssetGenImage(
    'assets/images/daily quest planner_teal_darklogo.png',
  );

  /// File path: assets/images/daily quest planner_teal_lightlogo.png
  AssetGenImage get dailyQuestPlannerTealLightlogo => const AssetGenImage(
    'assets/images/daily quest planner_teal_lightlogo.png',
  );

  /// File path: assets/images/daily_quest_logo_burgundy.png
  AssetGenImage get dailyQuestLogoBurgundy =>
      const AssetGenImage('assets/images/daily_quest_logo_burgundy.png');

  /// File path: assets/images/daily_quest_logo_pink.png
  AssetGenImage get dailyQuestLogoPink =>
      const AssetGenImage('assets/images/daily_quest_logo_pink.png');

  /// File path: assets/images/daily_quest_logo_slate.png
  AssetGenImage get dailyQuestLogoSlate =>
      const AssetGenImage('assets/images/daily_quest_logo_slate.png');

  /// File path: assets/images/daily_quest_logo_teal.png
  AssetGenImage get dailyQuestLogoTeal =>
      const AssetGenImage('assets/images/daily_quest_logo_teal.png');

  /// File path: assets/images/snail.png
  AssetGenImage get snail => const AssetGenImage('assets/images/snail.png');

  /// List of all assets
  List<AssetGenImage> get values => [
    dailyQuestPlannerBurgundyDarklogo,
    dailyQuestPlannerBurgundyLightlogo,
    dailyQuestPlannerPinkDarklogo,
    dailyQuestPlannerPinkLightlogo,
    dailyQuestPlannerSlateDarklogo,
    dailyQuestPlannerSlateLightlogo,
    dailyQuestPlannerTealDarklogo,
    dailyQuestPlannerTealLightlogo,
    dailyQuestLogoBurgundy,
    dailyQuestLogoPink,
    dailyQuestLogoSlate,
    dailyQuestLogoTeal,
    snail,
  ];
}

class Assets {
  const Assets._();

  static const $AssetsAnimationsGen animations = $AssetsAnimationsGen();
  static const $AssetsConfigGen config = $AssetsConfigGen();
  static const $AssetsImagesGen images = $AssetsImagesGen();
}

class AssetGenImage {
  const AssetGenImage(this._assetName, {this.size, this.flavors = const {}});

  final String _assetName;

  final Size? size;
  final Set<String> flavors;

  Image image({
    Key? key,
    AssetBundle? bundle,
    ImageFrameBuilder? frameBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    double? scale,
    double? width,
    double? height,
    Color? color,
    Animation<double>? opacity,
    BlendMode? colorBlendMode,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    Rect? centerSlice,
    bool matchTextDirection = false,
    bool gaplessPlayback = true,
    bool isAntiAlias = false,
    String? package,
    FilterQuality filterQuality = FilterQuality.medium,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    return Image.asset(
      _assetName,
      key: key,
      bundle: bundle,
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      scale: scale,
      width: width,
      height: height,
      color: color,
      opacity: opacity,
      colorBlendMode: colorBlendMode,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      isAntiAlias: isAntiAlias,
      package: package,
      filterQuality: filterQuality,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }

  ImageProvider provider({AssetBundle? bundle, String? package}) {
    return AssetImage(_assetName, bundle: bundle, package: package);
  }

  String get path => _assetName;

  String get keyName => _assetName;
}
