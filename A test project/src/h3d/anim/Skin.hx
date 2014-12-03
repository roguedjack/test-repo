package h3d.anim;

class Joint {

	public var index : Int;
	public var name : String;
	public var bindIndex : Int;
	public var splitIndex : Int;
	public var defMat : h3d.Matrix; // the default bone matrix
	public var transPos : h3d.Matrix; // inverse pose matrix
	public var parent : Joint;
	public var subs : Array<Joint>;
	/**
		When animated, we will use the default bind pose translation instead of the animated translation,
		enabling retargeting on a skeleton with different proportions
	**/
	public var retargetAnim : Bool;

	public function new() {
		bindIndex = -1;
		subs = [];
	}

}

private class Influence {
	public var j : Joint;
	public var w : Float;
	public function new(j, w) {
		this.j = j;
		this.w = w;
	}
}

class Skin {

	public var name : String;
	public var vertexCount(default, null) : Int;
	public var bonesPerVertex(default,null) : Int;
	public var vertexJoints : haxe.ds.Vector<Int>;
	public var vertexWeights : haxe.ds.Vector<Float>;
	public var rootJoints(default,null) : Array<Joint>;
	public var namedJoints(default,null) : Map<String,Joint>;
	public var allJoints(default,null) : Array<Joint>;
	public var boundJoints(default, null) : Array<Joint>;
	#if !(dataOnly || macro)
	public var primitive : h3d.prim.Primitive;
	#end

	// spliting
	public var splitJoints(default, null) : Array<{ material : Int, joints : Array<Joint> }>;
	public var triangleGroups : haxe.ds.Vector<Int>;

	var envelop : Array<Array<Influence>>;

	public function new( name, vertexCount, bonesPerVertex ) {
		this.name = name;
		this.vertexCount = vertexCount;
		this.bonesPerVertex = bonesPerVertex;
		if( vertexCount > 0 ) {
			vertexJoints = new haxe.ds.Vector(vertexCount * bonesPerVertex);
			vertexWeights = new haxe.ds.Vector(vertexCount * bonesPerVertex);
			envelop = [];
		}
	}

	public function setJoints( joints : Array<Joint>, roots : Array<Joint> ) {
		rootJoints = roots;
		allJoints = joints;
		namedJoints = new Map();
		for( j in joints )
			if( j.name != null )
				namedJoints.set(j.name, j);
	}

	public inline function addInfluence( vid : Int, j : Joint, w : Float ) {
		var il = envelop[vid];
		if( il == null )
			il = envelop[vid] = [];
		il.push(new Influence(j,w));
	}

	function sortInfluences( i1 : Influence, i2 : Influence ) {
		return i2.w > i1.w ? 1 : -1;
	}

	public inline function isSplit() {
		return splitJoints != null;
	}

	public function initWeights() {
		boundJoints = [];
		var pos = 0;
		for( i in 0...vertexCount ) {
			var il = envelop[i];
			if( il == null ) il = [];
			haxe.ds.ArraySort.sort(il,sortInfluences);
			if( il.length > bonesPerVertex )
				il = il.slice(0, bonesPerVertex);
			var tw = 0.;
			for( i in il )
				tw += i.w;
			tw = 1 / tw;
			for( i in 0...bonesPerVertex ) {
				var i = il[i];
				if( i == null ) {
					vertexJoints[pos] = 0;
					vertexWeights[pos] = 0;
				} else {
					if( i.j.bindIndex == -1 ) {
						i.j.bindIndex = boundJoints.length;
						boundJoints.push(i.j);
					}
					vertexJoints[pos] = i.j.bindIndex;
					vertexWeights[pos] = i.w * tw;
				}
				pos++;
			}
		}
		envelop = null;
	}

	public function split( maxBones : Int, index : Array<Int>, triangleMaterials : Null<Array<Int>> ) {
		if( isSplit() )
			return true;
		if( boundJoints.length <= maxBones )
			return false;

		splitJoints = [];
		triangleGroups = new haxe.ds.Vector(Std.int(index.length / 3));

		// collect joints groups used by triangles
		var curGroup = new Array<Joint>(), curJoints = [];
		var ipos = 0, tpos = 0, curMat = triangleMaterials == null ? 0 : triangleMaterials[0];
		while( ipos <= index.length ) {
			var tjoints = [], flush = false;
			if( ipos < index.length ) {
				for( k in 0...3 ) {
					var vid = index[ipos + k];
					for( b in 0...bonesPerVertex ) {
						var bidx = vid * bonesPerVertex + b;
						if( vertexWeights[bidx] == 0 ) continue;
						var j = boundJoints[vertexJoints[bidx]];
						if( curJoints[j.bindIndex] == null ) {
							curJoints[j.bindIndex] = j;
							tjoints.push(j);
						}
					}
				}
			}
			if( curGroup.length + tjoints.length <= maxBones && ipos < index.length && (triangleMaterials == null || triangleMaterials[tpos] == curMat) ) {
				for( j in tjoints )
					curGroup.push(j);
				triangleGroups[tpos++] = splitJoints.length;
				ipos += 3;
			} else {
				splitJoints.push({ material : curMat, joints : curGroup });
				curGroup = [];
				curJoints = [];
				if( triangleMaterials != null ) curMat = triangleMaterials[tpos];
				if( ipos == index.length ) break;
			}
		}

		// assign split indexes to joints
		var groups = [for( i in 0...splitJoints.length ) { id : i, reserved : [], joints : splitJoints[i].joints, mat : splitJoints[i].material }];
		var joints = [for( j in boundJoints ) { j : j, groups : [], index : -1 } ];
		for( g in groups )
			for( j in g.joints )
				joints[j.bindIndex].groups.push(g);
		haxe.ds.ArraySort.sort(joints, function(j1, j2) return j2.groups.length - j1.groups.length);
		for( j in joints ) {
			for( i in 0...maxBones ) {
				var ok = true;
				for( g in j.groups )
					if( g.reserved[i] != null ) {
						ok = false;
						break;
					}
				if( ok ) {
					j.j.splitIndex = i;
					for( g in j.groups )
						g.reserved[i] = j.j;
					break;
				}
			}
			// not very good news if this happen.
			// It means that we need a smarter way to assign the joint indexes
			// Maybe by presorting triangles based on bone usage to have more coherent groups
			if( j.j.splitIndex < 0 ) throw "Bone conflict while spliting groups";
		}

		// rebuild joints list (and fill holes)
		splitJoints = [];
		for( g in groups ) {
			var jl = [];
			for( i in 0...g.reserved.length ) {
				var j = g.reserved[i];
				if( j == null ) j = boundJoints[0];
				jl.push(j);
			}
			splitJoints.push( { material : g.mat, joints : jl } );
		}

		// rebind
		for( i in 0...vertexJoints.length )
			vertexJoints[i] = boundJoints[vertexJoints[i]].splitIndex;

		return true;
	}


}