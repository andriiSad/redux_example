import 'dart:convert';
import 'dart:io';

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

const apiUrl = "http://10.0.2.2:5500/api/people.json";

@immutable
class Person {
  final String name;
  final int age;

  const Person({
    required this.name,
    required this.age,
  });
  Person.fromJson(Map<String, dynamic> json)
      : name = json['name'] as String,
        age = json['age'] as int;

  @override
  String toString() => 'Person ($name, $age years old)';
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

State reducer(State oldState, dynamic action) {
  if (action is LoadPeopleAction) {
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

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Store(
      reducer,
      initialState: const State.empty(),
      middleware: [
        loadPeopleMiddleware,
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
              converter: (store) => store.state.fetchedPersons,
              builder: (context, people) {
                if (people == null) {
                  return const SizedBox();
                } else {
                  return Expanded(
                    child: ListView.builder(
                      itemCount: people.length,
                      itemBuilder: (context, index) => ListTile(
                        title: Text(
                          people.elementAt(index).name,
                        ),
                        subtitle: Text(
                          people.elementAt(index).age.toString(),
                        ),
                      ),
                    ),
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
