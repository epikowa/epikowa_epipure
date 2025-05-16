package epikowa.epipure.tests;

using epikowa.epipure.EpiObservable.EpiObservableTools;

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

        var sl = new SecondLevel();
        EpiObservableTools.getObservable(sl).plopinou.signal.bind((value) -> {
            trace('Second level plopinou a changé vers ${value}');
        });
        sl.plopinou = "Yes!";

        var f = [''];

        EpiObservableTools.getObservable(observable);
        
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

class SecondLevel extends MonObservable {
    @:observable var agead:Int;
}
