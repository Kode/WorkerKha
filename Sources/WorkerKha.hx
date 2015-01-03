package;

import js.html.Worker;
import kha.Blob;
import kha.Framebuffer;
import kha.Game;
import kha.Image;
import kha.Loader;
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
				g.drawImage(images[command.id], command.x, command.y);
			case 'end':
				return;
			}
		}
	}
	
	private function onMessage(message: Dynamic): Void {
		var data = message.data;
		switch (data.command) {
		case 'loadBlob':
			Loader.the.loadBlob( { }, function(blob: Blob): Void {
				worker.postMessage( { command: 'blobLoaded', data: blob.bytes.getData() } );
			});
		case 'loadImage':
			Loader.the.loadImage( { }, function(image: Image): Void {
				++lastImageId;
				images.set(lastImageId, image);
				worker.postMessage( { command: 'imageLoaded', id: lastImageId } );
			});
		case 'loadSound':
			Loader.the.loadSound( { }, function(sound: Sound): Void {
				worker.postMessage( { command: 'soundLoaded' } );
			});
		case 'loadMusic':
			Loader.the.loadMusic( { }, function(music: Music): Void {
				worker.postMessage( { command: 'musicLoaded' } );
			});
		case 'drawImage':
			renderCommands.push( { command: 'drawImage', id: data.id, x: data.x, y: data.y } );
		case 'end':
			for (i in 0...lastRenderEndIndex + 1) {
				renderCommands.pop();
			}
			renderCommands.push( { command: 'end' } );
			lastRenderEndIndex = renderCommands.length - 1;
		}
	}
}
