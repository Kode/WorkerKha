package;

import js.html.Worker;
import kha.Assets;
import kha.Blob;
import kha.Color;
import kha.Framebuffer;
import kha.Image;
import kha.input.Keyboard;
import kha.input.KeyCode;
import kha.math.FastMatrix3;
import kha.Sound;

class Frame {
	public var commands: Array<Dynamic>;
	
	public function new() {
		commands = [];
	}
}

class WorkerKha {
	private var worker: Worker;
	private var frames: Array<Frame>;
	private var currentFrame: Frame;
	private var images: Map<Int, Dynamic>;
	private var lastImageId: Int;
	
	public function new() {
		frames = [];
		currentFrame = new Frame();
		images = new Map();
		lastImageId = 0;
		Keyboard.get().notify(keyboardDown, keyboardUp);
		worker = new Worker('kha.js');
		worker.addEventListener('message', onMessage, false);
	}
	
	public function render(frame: Framebuffer): Void {
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
					g.transformation = new FastMatrix3(command._0, command._1, command._2, command._3, command._4, command._5, command._6, command._7, command._8);
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
	
	private function keyboardDown(key: KeyCode): Void {
		worker.postMessage( { command: 'keyDown', key: key } );
	}
	
	private function keyboardUp(key: KeyCode): Void {
		worker.postMessage( { command: 'keyUp', key: key } );
	}
	
	private function onMessage(message: Dynamic): Void {
		var data = message.data;
		switch (data.command) {
		case 'loadBlob':
			Assets.loadBlobFromPath(data.file, function (blob: Blob) {
				worker.postMessage( { command: 'loadedBlob', file: data.file, data: blob.bytes.getData() } );
			});
		case 'loadImage':
			Assets.loadImageFromPath(data.file, false, function (image: Image) {
				++lastImageId;
				images.set(lastImageId, image);
				worker.postMessage( { command: 'loadedImage', file: data.file, id: lastImageId, width: image.width, height: image.height, realWidth: image.realWidth, realHeight: image.realHeight } );
			});
		case 'loadSound':
			Assets.loadSoundFromPath(data.file, function (sound: Sound) {
				worker.postMessage( { command: 'loadedSound', file: data.file } );
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
