typedef Predicate<T> = bool Function(T value);
typedef EmptyPredicate = bool Function();

class Predicates {
  const Predicates._();

  static Predicate<T> intersect<T>(Predicate<T> p1, Predicate<T> p2) {
    return (T value) => p1(value) && p2(value);
  }

  static Predicate<T> union<T>(Predicate<T> p1, Predicate<T> p2) {
    return (T value) => p1(value) || p2(value);
  }
}
