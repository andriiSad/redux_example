import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

const apiUrl = "http://127.0.0.1:5500/api/people.json";

@immutable
class Person {
  final String id;
  final String name;
  final int age;
  final String imageUrl;
  final Uint8List? imageData;
  final bool isLoading;

  Person copiedWith([
    bool? isLoading,
    Uint8List? imageData,
  ]) =>
      Person(
        id: id,
        name: name,
        age: age,
        imageUrl: imageUrl,
        imageData: imageData ?? this.imageData,
        isLoading: isLoading ?? this.isLoading,
      );

  const Person({
    required this.id,
    required this.name,
    required this.age,
    required this.imageUrl,
    required this.imageData,
    required this.isLoading,
  });
  Person.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        name = json['name'] as String,
        age = json['age'] as int,
        imageUrl = json['image_url'] as String,
        imageData = null,
        isLoading = false;

  @override
  String toString() => 'Person (id = $id, $name, $age years old)';
}

Future<Iterable<Person>> getPersons() => HttpClient()
    .getUrl(Uri.parse(apiUrl))
    .then((req) => req.close())
    .then((resp) => resp.transform(utf8.decoder).join())
    .then((str) => json.decode(str) as List<dynamic>)
    .then((list) => list.map((e) => Person.fromJson(e)));

@immutable
abstract class Action {
  const Action();
}

@immutable
class LoadPeopleAction extends Action {
  const LoadPeopleAction();
}

@immutable
class SuccessfullyFetchedPeopleAction extends Action {
  final Iterable<Person> persons;
  const SuccessfullyFetchedPeopleAction({required this.persons});
}

@immutable
class FailedToFetchPeopleAction extends Action {
  final Object error;
  const FailedToFetchPeopleAction({
    required this.error,
  });
}

@immutable
class State {
  final bool isLoading;
  final Iterable<Person>? fetchedPersons;
  final Object? error;

  Iterable<Person>? get sortedFetchedPersons => fetchedPersons?.toList()
    ?..sort((p1, p2) => int.parse(p1.id).compareTo(int.parse(p2.id)));

  const State({
    required this.isLoading,
    required this.fetchedPersons,
    required this.error,
  });
  const State.empty()
      : isLoading = false,
        fetchedPersons = null,
        error = null;
}

@immutable
class LoadPersonImageAction extends Action {
  final String personId;

  const LoadPersonImageAction({
    required this.personId,
  });
}

@immutable
class SuccessfullyLoadedPersonImageAction extends Action {
  final String personId;
  final Uint8List imageData;

  const SuccessfullyLoadedPersonImageAction({
    required this.personId,
    required this.imageData,
  });
}

State reducer(State oldState, dynamic action) {
  if (action is SuccessfullyLoadedPersonImageAction) {
    final person =
        oldState.fetchedPersons?.firstWhere((p) => p.id == action.personId);
    if (person != null) {
      return State(
        isLoading: false,
        error: oldState.error,
        fetchedPersons: oldState.fetchedPersons
            ?.where(
          (p) => p.id != person.id,
        )
            .followedBy([
          person.copiedWith(
            false,
            action.imageData,
          )
        ]),
      );
    } else {
      //person is null
      return oldState;
    }
  } else if (action is LoadPersonImageAction) {
    final person =
        oldState.fetchedPersons?.firstWhere((p) => p.id == action.personId);
    if (person != null) {
      return State(
        isLoading: false,
        error: oldState.error,
        fetchedPersons: oldState.fetchedPersons
            ?.where(
          (p) => p.id != person.id,
        )
            .followedBy([person.copiedWith(true)]),
      );
    } else {
      //person is null
      return oldState;
    }
  } else if (action is LoadPeopleAction) {
    return const State(
      isLoading: true,
      fetchedPersons: null,
      error: null,
    );
  } else if (action is SuccessfullyFetchedPeopleAction) {
    return State(
      isLoading: false,
      fetchedPersons: action.persons,
      error: null,
    );
  } else if (action is FailedToFetchPeopleAction) {
    return State(
      isLoading: false,
      fetchedPersons: oldState.fetchedPersons,
      error: action.error,
    );
  }
  return oldState;
}

void loadPeopleMiddleware(
  Store<State> store,
  dynamic action,
  NextDispatcher next,
) {
  if (action is LoadPeopleAction) {
    getPersons().then((persons) {
      store.dispatch(SuccessfullyFetchedPeopleAction(persons: persons));
    }).catchError((e) {
      print(e);
      store.dispatch(FailedToFetchPeopleAction(error: e));
    });
  }
  next(action);
}

void loadPersonImageMiddleware(
  Store<State> store,
  dynamic action,
  NextDispatcher next,
) {
  if (action is LoadPersonImageAction) {
    final person =
        store.state.fetchedPersons?.firstWhere((p) => p.id == action.personId);

    if (person != null) {
      final url = person.imageUrl;
      final bundle = NetworkAssetBundle(Uri.parse(url));
      bundle.load(url).then((bd) => bd.buffer.asUint8List()).then(
        (data) {
          store.dispatch(
            SuccessfullyLoadedPersonImageAction(
              personId: person.id,
              imageData: data,
            ),
          );
        },
      );
    }
  }
  next(action);
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Store(
      reducer,
      initialState: const State.empty(),
      middleware: [
        loadPeopleMiddleware,
        loadPersonImageMiddleware,
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Page'),
      ),
      body: StoreProvider(
        store: store,
        child: Column(
          children: [
            Center(
              child: TextButton(
                onPressed: () {
                  store.dispatch(const LoadPeopleAction());
                },
                child: const Text('Load person'),
              ),
            ),
            StoreConnector<State, bool>(
              converter: (store) => store.state.isLoading,
              builder: (context, isLoading) {
                if (isLoading) {
                  return const CircularProgressIndicator();
                } else {
                  return SizedBox();
                }
              },
            ),
            StoreConnector<State, Iterable<Person>?>(
              converter: (store) => store.state.sortedFetchedPersons,
              builder: (context, people) {
                if (people == null) {
                  return const SizedBox();
                } else {
                  return Expanded(
                    child: ListView.builder(
                        itemCount: people.length,
                        itemBuilder: (context, index) {
                          final person = people.elementAt(index);
                          final infoWidget = Text('${person.age} years old');
                          final Widget subtitle = person.imageData == null
                              ? infoWidget
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    infoWidget,
                                    Image.memory(person.imageData!),
                                  ],
                                );
                          final Widget trailing = person.isLoading
                              ? const CircularProgressIndicator()
                              : TextButton(
                                  onPressed: () {
                                    store.dispatch(
                                      LoadPersonImageAction(
                                          personId: person.id),
                                    );
                                  },
                                  child: const Text(
                                    'Load Image',
                                  ),
                                );
                          return ListTile(
                            title: Text(
                              person.name,
                            ),
                            subtitle: subtitle,
                            trailing: trailing,
                          );
                        }),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
