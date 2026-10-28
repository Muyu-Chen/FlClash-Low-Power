class FixedList<T> {
  final int maxLength;
  final _FixedListBuffer<T> _buffer;

  final int _revision;
  List<T>? _snapshot;

  FixedList(this.maxLength, {List<T>? list})
    : assert(maxLength > 0, 'FixedList without a cap grows without bound'),
      _buffer = _FixedListBuffer(maxLength, list ?? []),
      _revision = 0;

  FixedList._(this.maxLength, this._buffer, this._revision);

  int get revision => _revision;

  void add(T item) {
    _buffer.add(item);
    _snapshot = null;
  }

  void clear() {
    _buffer.clear();
    _snapshot = null;
  }

  FixedList<T> append(T item) {
    add(item);
    return FixedList._(maxLength, _buffer, _revision + 1);
  }

  FixedList<T> replace(Map<int, T> items) {
    items.forEach((index, item) => _buffer[index] = item);
    _snapshot = null;
    return FixedList._(maxLength, _buffer, _revision + 1);
  }

  List<T> get list => _snapshot ??= List.unmodifiable(
    Iterable.generate(length, (index) => _buffer[index]),
  );

  int get length => _buffer.length;

  T operator [](int index) => _buffer[index];

  FixedList<T> copyWith() {
    return FixedList(
      maxLength,
      list: List.generate(length, (index) => this[index]),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FixedList<T> &&
      identical(other._buffer, _buffer) &&
      other._revision == _revision;

  @override
  int get hashCode => Object.hash(identityHashCode(_buffer), _revision);
}

class _FixedListBuffer<T> {
  _FixedListBuffer(this.capacity, List<T> items)
    : _items = items.length > capacity
          ? items.sublist(items.length - capacity)
          : List.of(items);

  final int capacity;
  final List<T> _items;
  int _head = 0;

  int get length => _items.length;

  int _offset(int index) {
    RangeError.checkValidIndex(index, _items);
    return (_head + index) % length;
  }

  T operator [](int index) => _items[_offset(index)];

  void operator []=(int index, T item) => _items[_offset(index)] = item;

  void add(T item) {
    if (length < capacity) {
      _items.add(item);
      return;
    }
    _items[_head] = item;
    _head = (_head + 1) % capacity;
  }

  void clear() {
    _items.clear();
    _head = 0;
  }
}

/// Restores the head that [latest] trimmed off [current] so a paused view
/// stays anchored; the result is capped at [limit] from the tail.
List<T> retainTrimmedHead<T>(
  List<T> current,
  List<T> latest,
  int limit, {
  Object Function(T item)? keyOf,
}) {
  if (current.isEmpty || latest.isEmpty) {
    return latest;
  }
  final first = latest.first;
  final index = keyOf == null
      ? current.indexWhere((item) => identical(item, first))
      : current.indexWhere((item) => keyOf(item) == keyOf(first));
  if (index == 0) {
    return latest;
  }
  final head = index > 0 ? current.sublist(0, index) : current;
  return List.unmodifiable([...head, ...latest].take(limit));
}
