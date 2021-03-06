// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/src/dart/analysis/driver.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer_plugin/protocol/protocol.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart';
import 'package:analyzer_plugin/src/utilities/navigation/navigation.dart';
import 'package:analyzer_plugin/utilities/generator.dart';
import 'package:analyzer_plugin/utilities/navigation/navigation.dart';

/**
 * A mixin that can be used when creating a subclass of [ServerPlugin] and
 * mixing in [NavigationMixin]. This implements the creation of the navigation
 * request based on the assumption that the driver being created is an
 * [AnalysisDriver].
 *
 * Clients may not extend or implement this class, but are allowed to use it as
 * a mix-in when creating a subclass of [ServerPlugin] that also uses
 * [NavigationMixin] as a mix-in.
 */
abstract class DartNavigationMixin implements NavigationMixin {
  @override
  Future<NavigationRequest> getNavigationRequest(
      AnalysisGetNavigationParams parameters,
      covariant AnalysisDriver driver) async {
    ResolveResult result = await driver.getResult(parameters.file);
    return new DartNavigationRequestImpl(
        resourceProvider, parameters.offset, parameters.length, result);
  }
}

/**
 * A mixin that can be used when creating a subclass of [ServerPlugin] to
 * provide most of the implementation for handling navigation requests.
 *
 * Clients may not extend or implement this class, but are allowed to use it as
 * a mix-in when creating a subclass of [ServerPlugin].
 */
abstract class NavigationMixin implements ServerPlugin {
  /**
   * Return a list containing the navigation contributors that should be used to
   * create navigation information when used in the context of the given
   * analysis [driver].
   */
  List<NavigationContributor> getNavigationContributors(
      covariant AnalysisDriverGeneric driver);

  /**
   * Return the navigation request that should be passes to the contributors
   * returned from [getNavigationContributors].
   */
  Future<NavigationRequest> getNavigationRequest(
      AnalysisGetNavigationParams parameters,
      covariant AnalysisDriverGeneric driver);

  @override
  Future<AnalysisGetNavigationResult> handleAnalysisGetNavigation(
      AnalysisGetNavigationParams parameters) async {
    String path = parameters.file;
    ContextRoot contextRoot = contextRootContaining(path);
    if (contextRoot == null) {
      // Return an error from the request.
      throw new RequestFailure(
          RequestErrorFactory.pluginError('Failed to analyze $path', null));
    }
    AnalysisDriverGeneric driver = driverMap[contextRoot];
    NavigationRequest request = await getNavigationRequest(parameters, driver);
    NavigationGenerator generator =
        new NavigationGenerator(getNavigationContributors(driver));
    GeneratorResult result =
        await generator.generateNavigationResponse(request);
    result.sendNotifications(channel);
    return result.result;
  }
}
