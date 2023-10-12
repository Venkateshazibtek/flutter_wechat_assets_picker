// Copyright 2019 The FlutterCandies author. All rights reserved.
// Use of this source code is governed by an Apache license that can be found
// in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/config.dart';
import '../delegates/asset_picker_builder_delegate.dart';
import '../delegates/asset_picker_delegate.dart';
import '../provider/asset_picker_provider.dart';
import 'asset_picker_page_route.dart';

AssetPickerDelegate _pickerDelegate = const AssetPickerDelegate();

class AssetPicker<Asset, Path> extends StatefulWidget {
  const AssetPicker({super.key, required this.builder});

  final AssetPickerBuilderDelegate<Asset, Path> builder;

  /// Provide another [AssetPickerDelegate] which override with
  /// custom methods during handling the picking,
  /// e.g. to verify if arguments are properly set during picking calls.
  ///
  /// See also:
  ///  * [AssetPickerDelegate] which is the default picker delegate.
  @visibleForTesting
  static void setPickerDelegate(AssetPickerDelegate delegate) {
    _pickerDelegate = delegate;
  }

  /// {@macro wechat_assets_picker.delegates.AssetPickerDelegate.permissionCheck}
  static Future<PermissionState> permissionCheck() {
    return _pickerDelegate.permissionCheck();
  }

  /// {@macro wechat_assets_picker.delegates.AssetPickerDelegate.pickAssets}
  static Future<List<AssetEntity>?> pickAssets(
    BuildContext context, {
    AssetPickerConfig pickerConfig = const AssetPickerConfig(),
    bool useRootNavigator = true,
    AssetPickerPageRouteBuilder<List<AssetEntity>>? pageRouteBuilder,
  }) {
    return _pickerDelegate.pickAssets(
      context,
      pickerConfig: pickerConfig,
      useRootNavigator: useRootNavigator,
      pageRouteBuilder: pageRouteBuilder,
    );
  }

  /// {@macro wechat_assets_picker.delegates.AssetPickerDelegate.pickAssetsWithDelegate}
  static Future<List<Asset>?> pickAssetsWithDelegate<Asset, Path, PickerProvider extends AssetPickerProvider<Asset, Path>>(
    BuildContext context, {
    required AssetPickerBuilderDelegate<Asset, Path> delegate,
    bool useRootNavigator = true,
    AssetPickerPageRouteBuilder<List<Asset>>? pageRouteBuilder,
  }) {
    return _pickerDelegate.pickAssetsWithDelegate<Asset, Path, PickerProvider>(
      context,
      delegate: delegate,
      useRootNavigator: useRootNavigator,
      pageRouteBuilder: pageRouteBuilder,
    );
  }

  /// {@macro wechat_assets_picker.delegates.AssetPickerDelegate.registerObserve}
  static void registerObserve([ValueChanged<MethodCall>? callback]) {
    _pickerDelegate.registerObserve(callback);
  }

  /// {@macro wechat_assets_picker.delegates.AssetPickerDelegate.unregisterObserve}
  static void unregisterObserve([ValueChanged<MethodCall>? callback]) {
    _pickerDelegate.unregisterObserve(callback);
  }

  /// {@macro wechat_assets_picker.delegates.AssetPickerDelegate.themeData}
  static ThemeData themeData(Color? themeColor, {bool light = false}) {
    return _pickerDelegate.themeData(themeColor, light: light);
  }

  @override
  AssetPickerState<Asset, Path> createState() => AssetPickerState<Asset, Path>();
}

class AssetPickerState<Asset, Path> extends State<AssetPicker<Asset, Path>> with TickerProviderStateMixin, WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AssetPicker.registerObserve(_onLimitedAssetsUpdated);
    widget.builder.initState(this);
    enablePopup();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      PhotoManager.requestPermissionExtend().then(
        (PermissionState ps) => widget.builder.permission.value = ps,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AssetPicker.unregisterObserve(_onLimitedAssetsUpdated);
    widget.builder.dispose();
    super.dispose();
  }

  Future<void> _onLimitedAssetsUpdated(MethodCall call) {
    return widget.builder.onAssetsChanged(call, (VoidCallback fn) {
      fn();
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder.build(context);
  }

  void enablePopup() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? response = prefs.getString('gallery');
    if (response == null || response == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await firstTimeShowPopupDialog(context);
      });
    }
  }

  Future<Future> firstTimeShowPopupDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xff000000).withOpacity(0.6),
      builder: (BuildContext context) {
        return Center(
          child: AlertDialog(
              insetPadding: EdgeInsets.zero,
              contentPadding: EdgeInsets.zero,
              clipBehavior: Clip.antiAliasWithSaveLayer,
              backgroundColor: Colors.transparent,
              content: Builder(
                builder: (BuildContext context) {
                  return Container(
                    padding: const EdgeInsets.only(top: 25, left: 15, right: 15),
                    height: 242,
                    width: 300,
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        const Text(
                          'Select multiple photos/videos from your library',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontFamily: 'NimbusBold',
                            color: Color(0xffF0F2F2),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: 158,
                          height: 33,
                          child: ElevatedButton(
                            onPressed: () async {
                              final SharedPreferences prefs = await SharedPreferences.getInstance();
                              Navigator.of(context).maybePop();
                              await prefs.setString('gallery', 'true');
                            },
                            style: ElevatedButton.styleFrom(
                              primary: const Color(0Xff0cb373),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(03)),
                            ),
                            child: const Text(
                              'Okay!',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Color(0xff000000), fontFamily: 'NimbusBold', fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              )),
        );
      },
    );
  }
}
