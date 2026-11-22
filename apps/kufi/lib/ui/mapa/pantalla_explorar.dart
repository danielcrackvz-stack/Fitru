import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../alcance.dart';
import '../../formato.dart';
import '../../tema.dart';
import '../widgets.dart';

class PantallaExplorar extends StatefulWidget {
  const PantallaExplorar({super.key});

  @override
  State<PantallaExplorar> createState() => _PantallaExplorarState();
}

class _PantallaExplorarState extends State<PantallaExplorar> {
  final _texto = TextEditingController();
  String _jurisdiccion = 'todas';
  String _operador = '';
  var _soloFavoritos = false;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = KufiScope.of(context);
    final operadores = estado.catalogo.rutas.map((r) => r.operador).where((o) => o.isNotEmpty).toSet().toList()..sort();
    final lista = estado.catalogo.buscar(_texto.text, jurisdiccion: _jurisdiccion).where((ruta) {
      if (_operador.isNotEmpty && ruta.operador != _operador) return false;
      if (_soloFavoritos && !estado.esFavorito(ruta.routeId)) return false;
      if (_texto.text.trim().isNotEmpty) return true;
      return true;
    }).toList();
    return Scaffold(
      appBar: AppBar(leading: const BotonAtras(), title: const Text('Rutas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _texto,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Zona, operador o nombre',
              ),
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _filtro('Todas', _jurisdiccion == 'todas' && !_soloFavoritos, () {
                  setState(() {
                    _jurisdiccion = 'todas';
                    _soloFavoritos = false;
                  });
                }),
                _filtro('Urbanas', _jurisdiccion == 'urbano', () => setState(() => _jurisdiccion = 'urbano')),
                _filtro('Intermunicipales', _jurisdiccion == 'intermunicipal', () => setState(() => _jurisdiccion = 'intermunicipal')),
                _filtro('Favoritas', _soloFavoritos, () => setState(() => _soloFavoritos = !_soloFavoritos)),
              ],
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _filtro('Cualquier sindicato', _operador.isEmpty, () => setState(() => _operador = '')),
                for (final operador in operadores.take(24))
                  _filtro(operador, _operador == operador, () => setState(() => _operador = operador)),
              ],
            ),
          ),
          Expanded(
            child: lista.isEmpty
                ? const Center(child: Text('Ninguna ruta con esos filtros.'))
                : ListView.builder(
                    itemCount: lista.length,
                    itemBuilder: (context, i) {
                      final ruta = lista[i];
                      final fav = estado.esFavorito(ruta.routeId);
                      return ListTile(
                        leading: Icon(Icons.directions_bus, color: colorHex(ruta.colorHex)),
                        title: Text(ruta.nombreComun, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${ruta.etiquetaJurisdiccion} · ${ruta.operador} · ${ruta.zonas}'),
                        trailing: IconButton(
                          icon: Icon(fav ? Icons.star : Icons.star_border, color: ColoresKufi.verde),
                          onPressed: () => estado.alternarFavorito(ruta.routeId),
                        ),
                        onTap: () {
                          estado.recordarBusqueda(ruta.nombreComun);
                          context.push('/ruta/${ruta.routeId}');
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filtro(String texto, bool activo, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(texto),
        selected: activo,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
