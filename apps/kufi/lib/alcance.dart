import 'package:flutter/material.dart';

import 'estado/estado_kufi.dart';

class KufiScope extends InheritedNotifier<EstadoKufi> {
  const KufiScope({required EstadoKufi estado, required super.child, super.key}) : super(notifier: estado);

  static EstadoKufi of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<KufiScope>();
    assert(scope != null, 'Falta KufiScope en el árbol.');
    return scope!.notifier!;
  }
}
