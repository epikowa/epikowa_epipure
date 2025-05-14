package epikowa.epipure.tests;

class TestEpiObservable {
    public static function main() {
        var observable = new MonObservable();
        
        
        trace(observable.__observables_storage.plopinou.signal);
        trace(observable.plopinou);
        observable.__observables_storage.plopinou.signal.bind((value) -> {trace('Le signal: ${value}');});
        observable.plopinou = 'badoumbah';
        observable.plopinou = 'badoumbah2';
        
        trace(observable.plopinou);

        trace('---- test');
        trace(observable.test);
        trace(observable.__observables_storage.test.currentValue);
        observable.__observables_storage.test.signal.bind((value) -> {
            trace('Int signal ${value}');
        });
        observable.test = 12;
        trace(observable.test);

        // trace('Previous ${observable.__observables_storage.get('plopinou').lastValue}');
    }

    public function plop():String {
        var e:Any = ['bim'];

        return e;
    }
}

class MonObservable implements EpiObservable {
    @:observable var plopinou:String;
    @:observable var test:Int = 1;

    @:skipCheck var name:String = "Hello";

    public function new() {
        
    }
}

class SecondLevel extends MonObservable implements EpiObservable {
    @:skipCheck var age:Int;
}