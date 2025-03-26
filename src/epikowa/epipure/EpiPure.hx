package epikowa.epipure;

import haxe.macro.Compiler;
import haxe.macro.ComplexTypeTools;
import haxe.macro.TypeTools;
import haxe.macro.Context;
import haxe.Json;
import haxe.macro.Expr.Field;

@:autoBuild(epikowa.epipure.EpiPure.EpiPureMacro.build())
interface EpiPure {}

#if macro
@:nullSafety(Strict)
class EpiPureMacro {
	static function init() {
		Compiler.registerMetadataDescriptionFile('src/meta.json');
	}
	
	public static function build() {
		final localClass = Context.getLocalClass().get();

		final fields = haxe.macro.Context.getBuildFields();
        final problematicFields = new Array<String>();

		for (field in fields) {
            final isFieldOK = isFieldOfImmutableType(field);
			if(!isFieldOK) {
                Context.warning('Field ${field.name} is not immutable.', field.pos);
                problematicFields.push(field.name);
            }
		}

        if (problematicFields.length > 0) {
            Context.error('Class ${localClass.name} is not pure. Problematic fields: ${problematicFields.join(', ')}', Context.currentPos());
        }

		return fields;
	}

	/**
	 * Is the type of the field on the known list of unmutable types?
	 * @param field 
	 * @return Bool
	 */
	static function isFieldOfImmutableType(field:Field):Bool {
		switch (field.kind) {
			case FProp(get, set, t, e):
                if (set != "never") return false;
        		return isComplexTypeImmutable(t);
				
            case FFun(f):
                return true;
            case FVar(t, e):
				if (field.access.indexOf(AFinal) < 0) return false;

				return isComplexTypeImmutable(t);
			default:
		}

		return false;
	}

	static function isComplexTypeImmutable(t) {
		switch (ComplexTypeTools.toType(t)) {
			case TInst(t1, params):
				return isClassMarkedAsImmutable(t1.get()) || isTypeKnownAsImmutable(t);
			case TAbstract(t, params):
				return isPathKnownAsImmutable({pack: t.get().pack, name: t.get().name, params: params.map((p) -> haxe.macro.Expr.TypeParam.TPType(TypeTools.toComplexType(p)))});
			default:
		}
		return false;
	}

	static function isClassMarkedAsImmutable(classType:haxe.macro.Type.ClassType) {
        final isEpiPure = classType.interfaces.filter((i) -> {
            return i.t.toString() == 'epikowa.epipure.EpiPure';
        }).length > 0;

		return isEpiPure || classType.meta.has(':immutable');
	}

	static function isTypeKnownAsImmutable(t:haxe.macro.Expr.ComplexType) {
		switch (t) {
			case TPath(p):
				return isPathKnownAsImmutable(p);
			default:
		}

		return false;
	}

	static function isPathKnownAsImmutable(p:haxe.macro.Expr.TypePath) {
		switch(p) {
			case {pack: [], name: 'String'}, {pack: [], name: 'Int'}, {pack: [], name: 'Float'}:
				return true;
			case {pack: [], name: 'Null'}:
				switch (p.params[0]) {
					case TPExpr(e):
						return true;
					case TPType(t):
						return isComplexTypeImmutable(t);
				}
			default:
		}

		return false;
	}
}
#end
