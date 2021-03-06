/*--------------------------------------------------------*\
|                                                          |
|                          hprose                          |
|                                                          |
| Official WebSite: https://hprose.com                     |
|                                                          |
| cluster.dart                                             |
|                                                          |
| Cluster plugin for Dart.                                 |
|                                                          |
| LastModified: Mar 8, 2019                                |
| Author: Ma Bingyao <andot@hprose.com>                    |
|                                                          |
\*________________________________________________________*/

part of hprose.rpc.plugins;

abstract class ClusterConfig {
  int retry = 10;
  bool idempotent = false;
  void Function(Context context) onSuccess;
  void Function(Context context) onFailure;
  Duration Function(Context context) onRetry;
}

class FailoverConfig extends ClusterConfig {
  static ClusterConfig instance = new FailoverConfig();
  FailoverConfig(
      [int retry = 10,
      Duration minInterval = const Duration(milliseconds: 500),
      Duration maxInterval = const Duration(seconds: 5)]) {
    this.retry = retry;
    var index = 0;
    onFailure = (context) {
      final clientContext = context as ClientContext;
      final uris = clientContext.client.uris;
      final n = uris.length;
      if (n > 1) {
        index = (index + 1) % n;
        clientContext.uri = uris[index];
      }
    };
    onRetry = (context) {
      final clientContext = context as ClientContext;
      final uris = clientContext.client.uris;
      final n = uris.length;
      context['retried']++;
      Duration interval = minInterval * (context['retried'] - n);
      if (interval > maxInterval) {
        interval = maxInterval;
      }
      return interval;
    };
  }
}

class FailtryConfig extends ClusterConfig {
  static ClusterConfig instance = new FailtryConfig();
  FailtryConfig(
      [int retry = 10,
      Duration minInterval = const Duration(milliseconds: 500),
      Duration maxInterval = const Duration(seconds: 5)]) {
    this.retry = retry;
    onRetry = (context) {
      Duration interval = minInterval * (++context['retried']);
      if (interval > maxInterval) {
        interval = maxInterval;
      }
      return interval;
    };
  }
}

class FailfastConfig extends ClusterConfig {
  constructor(void Function(Context context) onFailure) {
    this.retry = 0;
    this.onFailure = onFailure;
  }
}

class Cluster {
  ClusterConfig config;
  Cluster([ClusterConfig config]) {
    if (config == null) config = FailoverConfig.instance;
    this.config = config;
  }
  Future<Uint8List> handler(
      Uint8List request, Context context, NextIOHandler next) async {
    try {
      final response = await next(request, context);
      if (config.onSuccess != null) {
        config.onSuccess(context);
      }
      return response;
    } catch (e) {
      if (config.onFailure != null) {
        config.onFailure(context);
      }
      if (config.onRetry != null) {
        final bool idempotent = context.containsKey('idempotent')
            ? context['idempotent']
            : config.idempotent;
        final int retry =
            context.containsKey('retry') ? context['retry'] : config.idempotent;
        if (!context.containsKey('retried')) {
          context['retried'] = 0;
        }
        if (idempotent && context['retried'] < retry) {
          final interval = config.onRetry(context);
          if (interval > Duration.zero) {
            return Future.delayed(
                interval, () => handler(request, context, next));
          } else {
            return handler(request, context, next);
          }
        }
      }
      rethrow;
    }
  }

  static Future forking(
      String name, List args, Context context, NextInvokeHandler next) {
    final completer = new Completer();
    final clientContext = context as ClientContext;
    final uris = clientContext.client.uris;
    final n = uris.length;
    var count = n;
    for (int i = 0; i < n; ++i) {
      final forkingContext = clientContext.clone() as ClientContext;
      forkingContext.uri = uris[i];
      next(name, args, forkingContext).then((value) {
        completer.complete(value);
      }, onError: (error, stackTrace) {
        if (--count == 0) {
          completer.completeError(error, stackTrace);
        }
      });
    }
    return completer.future;
  }

  static Future broadcast(
      String name, List args, Context context, NextInvokeHandler next) {
    final clientContext = context as ClientContext;
    final uris = clientContext.client.uris;
    final n = uris.length;
    final results = new List<Future>(n);
    for (var i = 0; i < n; ++i) {
      final forkingContext = clientContext.clone() as ClientContext;
      forkingContext.uri = uris[i];
      results[i] = next(name, args, forkingContext);
    }
    return Future.wait(results);
  }
}
