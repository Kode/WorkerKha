package;

import js.html.Worker;
import kha.Blob;
import kha.Color;
import kha.Framebuffer;
import kha.Game;
import kha.Image;
import kha.Loader;
import kha.math.Matrix3;
import kha.Music;
import kha.Sound;

class WorkerKha extends Game {
	private var worker: Worker;
	private var renderCommands: Array<Dynamic>;
	private var lastRenderEndIndex: Int;
	private var images: Map<Int, Dynamic>;
	private var lastImageId: Int;
	
	public function new() {
		super("WorkerKha", false);
		renderCommands = [];
		images = new Map();
		lastImageId = 0;
		lastRenderEndIndex = -1;
	}
	
	override public function loadFinished(): Void {
		super.loadFinished();
		worker = new Worker('kha.js');
		worker.addEventListener('message', onMessage, false);
	}
	
	override public function render(frame: Framebuffer): Void {
		super.render(frame);
		var g = frame.g2;
		for (command in renderCommands) {
			switch (command.command) {
			case 'drawImage':
				g.transformation = Matrix3.identity();
				g.color = Color.White;
				g.drawImage(images[command.id], command.x, command.y);
			case 'drawScaledSubImage':
				g.transformation = Matrix3.identity();
				g.color = Color.White;
				g.drawScaledSubImage(images[command.id], command.sx, command.sy, command.sw, command.sh, command.dx, command.dy, command.dw, command.dh);
			case 'end':
				break;
			}
		}
		worker.postMessage( { command: 'frame' } );
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
			renderCommands.push( { command: 'drawImage', id: data.id, x: data.x, y: data.y } );
		case 'drawScaledSubImage':
			renderCommands.push( { command: 'drawScaledSubImage', id: data.id, sx: data.sx, sy: data.sy, sw: data.sw, sh: data.sh, dx: data.dx, dy: data.dy, dw: data.dw, dh: data.dh } );
		case 'end':
			if (lastRenderEndIndex > 0) renderCommands.splice(0, lastRenderEndIndex + 1);
			renderCommands.push( { command: 'end' } );
			lastRenderEndIndex = renderCommands.length - 1;
		}
	}
}
