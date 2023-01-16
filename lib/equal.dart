extension MapEquals<K, V> on Map<K, V> {
  bool equals(Map<K, V> other) {
    if (length != other.length) return false;

    for (final K key in keys) {
      if (!other.containsKey(key) || other[key]! != this[key]) {
        return false;
      }
    }

    return true;
  }
}

extension IterableEquals<T> on Iterable<T> {
  bool equals(Iterable<T> other) {
    if (length != other.length) return false;

    for (int i = 0; i < length; i++) {
      if (elementAt(i) != other.elementAt(i)) {
        return false;
      }
    }

    return true;
  }

  bool unorderedEquals(Iterable<T> other) {
    if (length != other.length) return false;

    final List<T> source = List<T>.from(other);

    for (int i = 0; i < length; i++) {
      final int j = source.indexOf(elementAt(i));

      if (j == -1) {
        return false;
      } else {
        source.removeAt(j);
      }
    }

    return true;
  }
}
