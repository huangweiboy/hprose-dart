/*--------------------------------------------------------*\
|                                                          |
|                          hprose                          |
|                                                          |
| Official WebSite: https://hprose.com                     |
|                                                          |
| type_manager.dart                                        |
|                                                          |
| hprose TypeManager for Dart.                             |
|                                                          |
| LastModified: Mar 9, 2019                                |
| Author: Ma Bingyao <andot@hprose.com>                    |
|                                                          |
\*________________________________________________________*/

part of hprose.io;

typedef T FromJson<T>(Map<String, dynamic> data);

class _TypeManager {
  final Map<String, FromJson> _fromJson = {};
  final Map<String, Map<String, Type>> _types = {};
  final Map<String, String> _names = {};
  final Map<String, Type> _emptyType = {};
  void register<T>(FromJson<T> fromJson,
      [Map<String, Type> fields, String name]) {
    if (name == null || name.isEmpty) {
      name = T.toString();
    }
    _names[T.toString()] = name;
    _fromJson[name] = fromJson;
    _types[name] = fields;
    if (fromJson != null) {
      Deserializer.register<T>(new ObjectDeserializer(name));
    }
  }

  bool isRegister(String name) {
    return _types.containsKey(name);
  }

  Map<String, Type> getType(String name) {
    return isRegister(name) ? _types[name] : _emptyType;
  }

  String getName(String type) {
    return _names.containsKey(type) ? _names[type] : type;
  }

  FromJson getConstructor(String name) {
    return _fromJson[name];
  }
}

final TypeManager = new _TypeManager();
