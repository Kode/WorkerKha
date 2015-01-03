package;

import js.html.Worker;
import kha.Blob;
import kha.Color;
import kha.Framebuffer;
import kha.Game;
import kha.Image;
import kha.input.Keyboard;
import kha.Key;
import kha.Loader;
import kha.math.Matrix3;
import kha.Music;
import kha.Sound;
import kha.Starter;

class Frame {
	public var commands: Array<Dynamic>;
	
	public function new() {
		commands = [];
	}
}

class WorkerKha extends Game {
	private var worker: Worker;
	private var frames: Array<Frame>;
	private var currentFrame: Frame;
	private var images: Map<Int, Dynamic>;
	private var lastImageId: Int;
	
	public function new() {
		super("WorkerKha", false);
		frames = [];
		currentFrame = new Frame();
		images = new Map();
		lastImageId = 0;
		Keyboard.get().notify(keyboardDown, keyboardUp);
	}
	
	override public function loadFinished(): Void {
		super.loadFinished();
		worker = new Worker('kha.js');
		worker.addEventListener('message', onMessage, false);
	}
	
	override public function render(frame: Framebuffer): Void {
		super.render(frame);
		if (frames.length > 0) {
			var g = frame.g2;
			g.begin();
			var lastFrame = frames[frames.length - 1]; 
			var commands = lastFrame.commands;
			for (command in commands) {
				switch (command.command) {
				case 'drawImage':
					g.color = Color.White;
					g.drawImage(images[command.id], command.x, command.y);
				case 'drawScaledSubImage':
					g.color = Color.White;
					g.drawScaledSubImage(images[command.id], command.sx, command.sy, command.sw, command.sh, command.dx, command.dy, command.dw, command.dh);
				case 'setTransformation':
					g.transformation = new Matrix3([command._0, command._1, command._2, command._3, command._4, command._5, command._6, command._7, command._8]);
				case 'end':
					break;
				}
			}
			g.end();
			frames = [];
			frames.push(lastFrame);
		}
		worker.postMessage( { command: 'frame' } );
	}
	
	private function keyboardDown(key: Key, char: String): Void {
		super.keyDown(key, char);
		worker.postMessage( { command: 'keyDown', key: key.getIndex(), char: char } );
	}
	
	private function keyboardUp(key: Key, char: String): Void {
		super.keyUp(key, char);
		worker.postMessage( { command: 'keyUp', key: key.getIndex(), char: char } );
	}
	
	private function onMessage(message: Dynamic): Void {
		var data = message.data;
		switch (data.command) {
		case 'loadBlob':
			Loader.the.loadBlob( { name: data.name, file: data.file }, function(blob: Blob): Void {
				worker.postMessage( { command: 'loadedBlob', file: data.file, data: blob.bytes.getData() } );
			});
		case 'loadImage':
			Loader.the.loadImage( { name: data.name, file: data.file }, function(image: Image): Void {
				++lastImageId;
				images.set(lastImageId, image);
				worker.postMessage( { command: 'loadedImage', file: data.file, id: lastImageId, width: image.width, height: image.height, realWidth: image.realWidth, realHeight: image.realHeight } );
			});
		case 'loadSound':
			Loader.the.loadSound( { name: data.name, file: data.file }, function(sound: Sound): Void {
				worker.postMessage( { command: 'loadedSound', file: data.file } );
			});
		case 'loadMusic':
			Loader.the.loadMusic( { name: data.name, file: data.file }, function(music: Music): Void {
				worker.postMessage( { command: 'loadedMusic', file: data.file } );
			});
		case 'drawImage':
			currentFrame.commands.push( { command: 'drawImage', id: data.id, x: data.x, y: data.y } );
		case 'drawScaledSubImage':
			currentFrame.commands.push( { command: 'drawScaledSubImage', id: data.id, sx: data.sx, sy: data.sy, sw: data.sw, sh: data.sh, dx: data.dx, dy: data.dy, dw: data.dw, dh: data.dh } );
		case 'setTransformation':
			currentFrame.commands.push( { command: 'setTransformation', _0: data._0, _1: data._1, _2: data._2, _3: data._3, _4: data._4, _5: data._5, _6: data._6, _7: data._7, _8: data._8 } );
		case 'end':
			frames.push(currentFrame);
			currentFrame = new Frame();
		}
	}
}
