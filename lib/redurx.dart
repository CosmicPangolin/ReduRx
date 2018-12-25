/// 👌 A thin layer of a Redux-based state manager on top of RxDart.
///
/// Nomi Modifications:
/// - Implemented Store<T> as a Middleware parameter, so Store.dispatch can be
///   called from Middleware to handle side effects. IMPORTANT: Store isn't updated
///   with new state from actions until after all middleware returns! Only state
///   parameter in afterAction() is updated from the reducer
/// - Deleted the Computation typedef 'cause it's just redundant
/// - Removed the second 'beforeAction' Middleware call for AsyncActions
/// - Removed Store(state) variable assignments in Store.dispatch, saving memory!
/// (I think?)

library redurx;

import 'dart:async';

import 'package:rxdart/rxdart.dart';

export 'src/log_middleware.dart';

/// Base interface for all action types.
abstract class ActionType {}

/// Action for synchronous requests.
abstract class Action<T> implements ActionType {
  /// Method to perform a synchronous mutation on the state.
  T reduce(T state);
}

/// Action for asynchronous requests.
abstract class AsyncAction<T> implements ActionType {
  /// Method to perform a asynchronous mutation on the state.
  Future<T> reduce(T state);
}

/// Interface for Middlewares.
abstract class Middleware<T> {
  /// Called before action reducer.
  T beforeAction(ActionType action, Store<T> store, T state) => state;

  /// Called after action reducer.
  T afterAction(ActionType action, Store<T> store, T state) => state;
}

/// The heart of the idea, this is where we control the State and dispatch Actions.
class Store<T> {
  /// You can create the Store given an [initialState].
  Store([T initialState])
    : subject = BehaviorSubject<T>(seedValue: initialState);

  /// This is where RxDart comes in, we manage the final state using a [BehaviorSubject].
  final BehaviorSubject<T> subject;

  /// List of middlewares to be applied.
  final List<Middleware<T>> middlewares = [];

  /// Gets the subject stream.
  Stream<T> get stream => subject.stream;

  /// Gets the subject current value/store's current state.
  T get state => subject.value;

  /// Maps the current subject stream to a new Stream.
  Stream<S> map<S>(S convert(T state)) => stream.map(convert);

  /// Dispatches actions that mutates the current state.
  Store<T> dispatch(ActionType action) {
    if (action is Action<T>) {
      subject.add(
        _foldAfterActionMiddlewares(
          action.reduce(
            _computeBeforeMiddlewares(action, this, state)
          ),
          this,
          action
        )
      );
    }

    if (action is AsyncAction<T>) {
      action
        .reduce(_computeBeforeMiddlewares(action, this, state))
        .then((afterAction) {
          subject.add(_foldAfterActionMiddlewares(afterAction, this, action));
        }
      );
    }

    return this;
  }

  /// Adds middlewares to the store.
  Store<T> add(Middleware<T> middleware) {
    middlewares.add(middleware);
    return this;
  }

  /// Closes the stores subject.
  void close() => subject.close();

  T _computeBeforeMiddlewares(ActionType action, Store<T> store, T state) =>
    middlewares.fold<T>(
      state, (state, middleware) => middleware.beforeAction(action, store, state));

  T _foldAfterActionMiddlewares(T initialValue, Store<T> store, ActionType action) =>
    middlewares.fold<T>(initialValue,
        (state, middleware) => middleware.afterAction(action, store, state));
}
