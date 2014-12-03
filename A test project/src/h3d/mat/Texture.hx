package h3d.mat;
import h3d.mat.Data;

@:allow(h3d)
class Texture {

	static var UID = 0;

	var t : h3d.impl.Driver.Texture;
	var mem : h3d.impl.MemoryManager;
	#if debug
	var allocPos : h3d.impl.AllocPos;
	#end
	public var id(default, null) : Int;
	public var name(default, null) : String;
	public var width(default, null) : Int;
	public var height(default, null) : Int;
	public var flags(default, null) : haxe.EnumFlags<TextureFlags>;

	var lastFrame : Int;
	var bits : Int;
	public var mipMap(default,set) : MipMap;
	public var filter(default,set) : Filter;
	public var wrap(default,set) : Wrap;

	/**
		If this callback is set, the texture can be re-allocated when the 3D context has been lost or when
		it's been free because of lack of memory.
	**/
	public var realloc : Void -> Void;

	public function new(w, h, ?flags : Array<TextureFlags>, ?allocPos : h3d.impl.AllocPos ) {
		var engine = h3d.Engine.getCurrent();
		this.mem = engine.mem;
		this.id = ++UID;
		this.flags = new haxe.EnumFlags();
		if( flags != null )
			for( f in flags )
				this.flags.set(f);

		var tw = 1, th = 1;
		while( tw < w ) tw <<= 1;
		while( th < h) th <<= 1;
		if( tw != w || th != h )
			this.flags.set(IsNPOT);

		// make the texture disposable if we're out of memory
		// this can be disabled after allocation by reseting realloc
		if( this.flags.has(Target) ) realloc = function() { };

		this.width = w;
		this.height = h;
		this.mipMap = this.flags.has(MipMapped) ? Nearest : None;
		this.filter = Linear;
		this.wrap = Clamp;
		bits &= 0x7FFF;
		#if debug
		this.allocPos = allocPos;
		#end
		alloc();
	}

	public function alloc() {
		if( t == null )
			mem.allocTexture(this);
	}

	function toString() {
		var str = name;
		if( name == null ) {
			str = "Texture_" + id;
			#if debug
			if( allocPos != null ) str += "(" + allocPos.className+":" + allocPos.lineNumber + ")";
			#end
		}
		return str+"("+width+"x"+height+")";
	}

	public function setName(n) {
		name = n;
	}

	function set_mipMap(m:MipMap) {
		bits |= 0x80000;
		bits = (bits & ~(3 << 0)) | (Type.enumIndex(m) << 0);
		return mipMap = m;
	}

	function set_filter(f:Filter) {
		bits |= 0x80000;
		bits = (bits & ~(3 << 3)) | (Type.enumIndex(f) << 3);
		return filter = f;
	}

	function set_wrap(w:Wrap) {
		bits |= 0x80000;
		bits = (bits & ~(3 << 6)) | (Type.enumIndex(w) << 6);
		return wrap = w;
	}

	inline function hasDefaultFlags() {
		return bits & 0x80000 == 0;
	}

	public inline function isDisposed() {
		return t == null && realloc == null;
	}

	public function resize(width, height) {
		dispose();

		var tw = 1, th = 1;
		while( tw < width ) tw <<= 1;
		while( th < height ) th <<= 1;
		if( tw != width || th != height )
			this.flags.set(IsNPOT);
		else
			this.flags.unset(IsNPOT);

		this.width = width;
		this.height = height;

		if( !flags.has(NoAlloc) )
			alloc();
	}

	public function clear( color : Int, alpha = 1. ) {
		alloc();
		var p = hxd.Pixels.alloc(width, height, BGRA);
		var k = 0;
		var b = color & 0xFF, g = (color >> 8) & 0xFF, r = (color >> 16) & 0xFF, a = Std.int(alpha * 255);
		if( a < 0 ) a = 0 else if( a > 255 ) a = 255;
		for( i in 0...width * height ) {
			p.bytes.set(k++,b);
			p.bytes.set(k++,g);
			p.bytes.set(k++,r);
			p.bytes.set(k++,a);
		}
		uploadPixels(p);
		p.dispose();
	}

	public function uploadBitmap( bmp : hxd.BitmapData, mipLevel = 0, side = 0 ) {
		alloc();
		mem.driver.uploadTextureBitmap(this, bmp, mipLevel, side);
	}

	public function uploadPixels( pixels : hxd.Pixels, mipLevel = 0, side = 0 ) {
		alloc();
		mem.driver.uploadTexturePixels(this, pixels, mipLevel, side);
	}

	public function dispose() {
		if( t != null ) {
			mem.deleteTexture(this);
			#if debug
			this.allocPos.customParams = ["#DISPOSED"];
			#end
		}
	}

	public static function fromBitmap( bmp : hxd.BitmapData, ?allocPos : h3d.impl.AllocPos ) {
		var t = new Texture(bmp.width, bmp.height, allocPos);
		t.uploadBitmap(bmp);
		return t;
	}

	public static function fromPixels( pixels : hxd.Pixels, ?allocPos : h3d.impl.AllocPos ) {
		var t = new Texture(pixels.width, pixels.height, allocPos);
		t.uploadPixels(pixels);
		return t;
	}

	static var COLOR_CACHE = new Map<Int,h3d.mat.Texture>();
	/**
		Creates a 1x1 texture using the RGB color passed as parameter.
	**/
	public static function fromColor( color : Int, ?alpha = 1., ?allocPos : h3d.impl.AllocPos ) {
		var aval = Std.int(alpha * 255);
		if( aval < 0 ) aval = 0 else if( aval > 255 ) aval = 255;
		var key = (color&0xFFFFFF) | (aval << 24);
		var t = COLOR_CACHE.get(key);
		if( t != null )
			return t;
		var t = new Texture(1, 1, null, allocPos);
		t.clear(color, alpha);
		t.realloc = function() t.clear(color, alpha);
		COLOR_CACHE.set(key, t);
		return t;
	}

}