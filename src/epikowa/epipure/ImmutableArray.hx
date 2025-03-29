package epikowa.epipure;

@:immutable class ImmutableArray<T> {
    final array:Array<T>;

    public var length(get, never):Int;
    function get_length() {
        return array.length;
    }

    public function new(array:Array<T>) {
        this.array = array;
    }

    public function append(element:T) {
        final newArray = Lambda.array(array);
        newArray.push(element);
        return new ImmutableArray(newArray);
    }

    public function prepend(element:T) {
        final newArray = Lambda.array(array);
        newArray.unshift(element);

        return new ImmutableArray(newArray);
    }

    public function insert(before:Int, element:T) {
        final newArray = Lambda.array(array);
        newArray.insert(before, element);

        return new ImmutableArray(newArray);
    }

    public function get(index:Int):Null<T> {
        return array[index];
    }

    public function set(index:Int, value:T) {
        var newArray = Lambda.array(array);
        newArray[index] = value;

        return newArray;
    }

    public function toArray() {
        return Lambda.array(array);
    }

    public function iterator() {
        return new ImmutableArrayIterator(this);
    }
}

class ImmutableArrayIterator<T> {
    public function hasNext():Bool {
        return currentIndex < array.length;
    }

    public function next():T {
        var i:T = cast(array.get(currentIndex));
        ++currentIndex;

        return i;
    }

    var array:ImmutableArray<T>;
    var currentIndex = 0;

    public function new(array:ImmutableArray<T>) {
        this.array = array;
    }
}