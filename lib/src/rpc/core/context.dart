/*--------------------------------------------------------*\
|                                                          |
|                          hprose                          |
|                                                          |
| Official WebSite: https://hprose.com                     |
|                                                          |
| context.dart                                             |
|                                                          |
| hprose Context for Dart.                                 |
|                                                          |
| LastModified: Feb 22, 2019                               |
| Author: Ma Bingyao <andot@hprose.com>                    |
|                                                          |
\*________________________________________________________*/

part of hprose.rpc.core;

class Context {
  final Map<String, dynamic> items = <String, dynamic>{};

  operator [](String key) => items[key];

  void operator []=(String key, value) => items[key] = value;

  bool containsKey(String key) => items.containsKey(key);

  noSuchMethod(Invocation invocation) {
    var name = invocation.memberName.toString();
    name = name.substring(8, name.length - 2);
    if (invocation.isGetter) {
      return items[name];
    } else if (invocation.isSetter) {
      name = name.substring(0, name.length - 1);
      items[name] = invocation.positionalArguments[0];
    }
  }

  Context clone() {
    final context = new Context();
    context.items.addAll(items);
    return context;
  }
}
