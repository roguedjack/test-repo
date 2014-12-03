package rj;

import h2d.Text;
import hxd.App;
import hxd.Key;
import hxd.Res;
import hxd.res.FontBuilder;

/**
 * ...
 * @author roguedjack
 */

class Main extends App {
	var text:Text;
	var timer:Float;
	
	override function init() {
		engine.backgroundColor = 0x6495ED;
		s2d.setFixedSize(800, 600);
		
		text = new Text(FontBuilder.getFont('arial', 18), s2d);
		text.text = '<blank>';
		text.dropShadow = { dx:1, dy:1, color:0, alpha:1 };
		//text.textAlign = Align.Center; // has no effect!
		
		timer = 0;
	}
	
	override function update(dt:Float) {
		text.text = 'FPS : ${Std.string(Std.int(engine.fps))}';
		timer += 1.0 / engine.fps;
		text.setPos(s2d.width * 0.5 - 0.5 * text.textWidth + 100*Math.cos(timer), s2d.height * 0.5 - text.textHeight + 100 * Math.sin(timer));
	}
	
	static function main() {
		Res.initEmbed();
		Key.initialize();
		new Main();
	}
}