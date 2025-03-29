package epikowa.epipure.tests;

class TestEpiObservable {
    public static function main() {
        var observable = new MonObservable();
        trace(observable.plopinou);
        observable.plopinou = 'badoumbah';
        observable.plopinou = 'badoumbah2';
        
        trace(observable.plopinou);
        trace('Previous ${observable.__observables_storage.get('plopinou').lastValue}');
    }

    public function plop():String {
        var e:Any = ['bim'];

        return e;
    }
}

class MonObservable implements EpiObservable {
    var plopinou:String;

    public function new() {

    }
}