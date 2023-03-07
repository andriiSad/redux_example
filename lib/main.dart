import 'package:flutter/material.dart';
import 'package:redux/redux.dart';
import 'package:flutter_redux/flutter_redux.dart';

void main() {
  runApp(
    MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

@immutable
class State {
  final Iterable<String> items;
  final ItemFilter filter;

  const State({
    required this.items,
    required this.filter,
  });

  Iterable<String> get filteredItems {
    switch (filter) {
      case ItemFilter.all:
        return items;
      case ItemFilter.longTexts:
        return items.where((item) => item.length >= 10);
      case ItemFilter.shortTexts:
        return items.where((item) => item.length <= 3);
    }
  }

  State.init()
      : items = [],
        filter = ItemFilter.all;
}

enum ItemFilter {
  all,
  longTexts,
  shortTexts,
}

@immutable
class ChangeFilterTypeAction extends Action {
  final ItemFilter filter;

  const ChangeFilterTypeAction({
    required this.filter,
  });
}

@immutable
abstract class Action {
  const Action();
}

@immutable
abstract class ItemAction extends Action {
  final String item;

  const ItemAction({
    required this.item,
  });
}

@immutable
class AddItemAction extends ItemAction {
  const AddItemAction(String item) : super(item: item);
}

@immutable
class RemoveItemAction extends ItemAction {
  const RemoveItemAction(String item) : super(item: item);
}

extension AddRemoveItems<T> on Iterable<T> {
  Iterable<T> operator +(T other) => followedBy([other]);
  Iterable<T> operator -(T other) => where((element) => element != other);
}

Iterable<String> addItemReducer(
  Iterable<String> previousItems,
  AddItemAction action,
) =>
    previousItems + action.item;

Iterable<String> removeItemReducer(
  Iterable<String> previousItems,
  RemoveItemAction action,
) =>
    previousItems - action.item;

Reducer<Iterable<String>> itemsReducer = combineReducers<Iterable<String>>([
  TypedReducer<Iterable<String>, AddItemAction>(addItemReducer),
  TypedReducer<Iterable<String>, RemoveItemAction>(removeItemReducer),
]);

ItemFilter itemFilterReducer(State oldState, Action action) {
  if (action is ChangeFilterTypeAction) {
    return action.filter;
  } else {
    return oldState.filter;
  }
}

State appStateReducer(
  State oldState,
  action,
) =>
    State(
      items: itemsReducer(oldState.items, action),
      filter: itemFilterReducer(oldState, action),
    );

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Page'),
      ),
    );
  }
}
