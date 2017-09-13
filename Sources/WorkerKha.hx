package;

import js.html.Worker;
import kha.Assets;
import kha.Blob;
import kha.Color;
import kha.Framebuffer;
import kha.Image;
import kha.graphics4.ConstantLocation;
import kha.graphics4.FragmentShader;
import kha.graphics4.IndexBuffer;
import kha.graphics4.PipelineState;
import kha.graphics4.TextureUnit;
import kha.graphics4.VertexBuffer;
import kha.graphics4.VertexElement;
import kha.graphics4.VertexShader;
import kha.graphics4.VertexStructure;
import kha.input.Keyboard;
import kha.input.KeyCode;
import kha.math.FastMatrix3;
import kha.Sound;

using StringTools;

class Frame {
	public var commands: Array<Dynamic>;
	
	public function new() {
		commands = [];
	}
}

@:expose
class WorkerKha {
	public static var instance: WorkerKha;
	private var worker: Worker;
	private var frames: Array<Frame>;
	private var currentFrame: Frame;
	private var images: Map<Int, Image>;
	private var lastImageId: Int;
	var shaders: Map<String, Dynamic>;
	var pipelines: Map<Int, PipelineState>;
	var indexBuffers: Map<Int, IndexBuffer>;
	var vertexBuffers: Map<Int, VertexBuffer>;
	var constantLocations: Map<Int, ConstantLocation>;
	var textureUnits: Map<Int, TextureUnit>;
	var workerDir: String;
	
	public function new() {
		instance = this;
		frames = [];
		currentFrame = new Frame();
		images = new Map();
		shaders = new Map();
		pipelines = new Map();
		indexBuffers = new Map();
		vertexBuffers = new Map();
		constantLocations = new Map();
		textureUnits = new Map();
		lastImageId = 0;
		Keyboard.get().notify(keyboardDown, keyboardUp);
		//worker = new Worker('khaworker.js');
		//worker.addEventListener('message', onMessage, false);
		worker = null;
	}

	public function load(workerPath: String): Void {
		if (worker != null) {
			worker.terminate();
		}

		for (image in images) {
			image.unload();
		}
		for (pipeline in pipelines) {
			pipeline.delete();
		}
		for (buffer in indexBuffers) {
			buffer.delete();
		}
		for (buffer in vertexBuffers) {
			buffer.delete();
		}

		images = new Map();
		shaders = new Map();
		pipelines = new Map();
		indexBuffers = new Map();
		vertexBuffers = new Map();
		constantLocations = new Map();
		textureUnits = new Map();

		frames = [];
		lastImageId = 0;

		workerDir = workerPath.substring(0, workerPath.lastIndexOf("/") + 1);
		worker = new Worker(workerPath);
		worker.addEventListener('message', onMessage, false);
	}
	
	public function render(framebuffer: Framebuffer): Void {
		if (frames.length > 0) {
			var g = framebuffer.g4;
			for (frame in frames) {
				var commands = frame.commands;
				for (command in commands) {
					switch (command.command) {
					/*case 'drawImage':
						g.color = Color.White;
						g.drawImage(images[command.id], command.x, command.y);
					case 'drawScaledSubImage':
						g.color = Color.White;
						g.drawScaledSubImage(images[command.id], command.sx, command.sy, command.sw, command.sh, command.dx, command.dy, command.dw, command.dh);
					case 'setTransformation':
						g.transformation = new FastMatrix3(command._0, command._1, command._2, command._3, command._4, command._5, command._6, command._7, command._8);*/
					case 'begin':
						g.begin();
					case 'clear':
						g.clear(command.color == null ? null : Color.fromValue(command.color));
					case 'setPipeline':
						g.setPipeline(pipelines[command.id]);
					case 'updateIndexBuffer':
						var indexBuffer = indexBuffers[command.id];
						var data = indexBuffer.lock();
						for (i in 0...data.length) {
							data.set(i, command.data[i]);
						}
						indexBuffer.unlock();
					case 'updateVertexBuffer':
						var vertexBuffer = vertexBuffers[command.id];
						var data = vertexBuffer.lock();
						for (i in 0...data.length) {
							data.set(i, command.data[i]);
						}
						vertexBuffer.unlock();
					case 'setIndexBuffer':
						g.setIndexBuffer(indexBuffers[command.id]);
					case 'setVertexBuffer':
						g.setVertexBuffer(vertexBuffers[command.id]);
					case 'createConstantLocation':
						constantLocations[command.id] = pipelines[command.pipeline].getConstantLocation(command.name);
					case 'createTextureUnit':
						textureUnits[command.id] = pipelines[command.pipeline].getTextureUnit(command.name);
					case 'setTexture':
						g.setTexture(textureUnits[command.stage], images[command.texture]);
					case 'setMatrix3':
						g.setMatrix3(constantLocations[command.location], new FastMatrix3(command._00, command._10, command._20, command._01, command._11, command._21, command._02, command._12, command._22));
					case 'drawIndexedVertices':
						g.drawIndexedVertices(command.start, command.count);
					case 'end':
						g.end();
					}
				}
			}
			frames = [];
		}
		if (worker != null) {
			worker.postMessage( { command: 'frame' } );
		}
	}
	
	private function keyboardDown(key: KeyCode): Void {
		if (worker != null) {
			worker.postMessage( { command: 'keyDown', key: key } );
		}
	}
	
	private function keyboardUp(key: KeyCode): Void {
		if (worker != null) {
			worker.postMessage( { command: 'keyUp', key: key } );
		}
	}
	
	private function onMessage(message: Dynamic): Void {
		var data = message.data;
		switch (data.command) {
		case 'loadBlob':
			Assets.loadBlobFromPath(workerDir + data.file, function (blob: Blob) {
				if (worker != null) {
					worker.postMessage( { command: 'loadedBlob', file: data.file, data: blob.bytes.getData() } );
				}
			});
		case 'loadImage':
			Assets.loadImageFromPath(workerDir + data.file, false, function (image: Image) {
				images.set(data.id, image);
				if (worker != null) {
					worker.postMessage( { command: 'loadedImage', id: data.id, width: image.width, height: image.height, realWidth: image.realWidth, realHeight: image.realHeight } );
				}
			});
		case 'loadSound':
			Assets.loadSoundFromPath(workerDir + data.file, function (sound: Sound) {
				if (worker != null) {
					worker.postMessage( { command: 'loadedSound', file: data.file } );
				}
			});
		/*case 'drawImage':
			currentFrame.commands.push( { command: 'drawImage', id: data.id, x: data.x, y: data.y } );
		case 'drawScaledSubImage':
			currentFrame.commands.push( { command: 'drawScaledSubImage', id: data.id, sx: data.sx, sy: data.sy, sw: data.sw, sh: data.sh, dx: data.dx, dy: data.dy, dw: data.dw, dh: data.dh } );
		case 'setTransformation':
			currentFrame.commands.push( { command: 'setTransformation', _0: data._0, _1: data._1, _2: data._2, _3: data._3, _4: data._4, _5: data._5, _6: data._6, _7: data._7, _8: data._8 } );
		case 'end':
			frames.push(currentFrame);
			currentFrame = new Frame();*/
		case 'setShaders':
			var shaders: Array<Dynamic> = data.shaders;
			for (shader in shaders) {
				var name: String = shader.name;
				if (name.endsWith("_frag")) {
					this.shaders[shader.files[0]] = new FragmentShader(shader.sources, shader.files);
				}
				else if (name.endsWith("_vert")) {
					this.shaders[shader.files[0]] = new VertexShader(shader.sources, shader.files);
				}
			}
		case 'compilePipeline':
			var pipe = new PipelineState();
			pipe.fragmentShader = shaders[data.frag];
			pipe.vertexShader = shaders[data.vert];
			pipe.inputLayout = [];
			var layout: Array<Dynamic> = data.layout;
			for (structure in layout) {
				var newstructure = new VertexStructure();
				//newstructure.elements
				var elements: Array<Dynamic> = structure.elements;
				for (element in elements) {
					var newelement = new VertexElement(element.name, VertexData.createByIndex(element.data));
					newstructure.elements.push(newelement);
				}
				pipe.inputLayout.push(newstructure);
			}
			pipe.compile();
			pipelines[data.id] = pipe;
		case 'createIndexBuffer':
			indexBuffers[data.id] = new IndexBuffer(data.size, kha.graphics4.Usage.StaticUsage);
		case 'createVertexBuffer':
			var structure = new VertexStructure();
			var elements: Array<Dynamic> = data.structure.elements;
			for (element in elements) {
				var newelement = new VertexElement(element.name, VertexData.createByIndex(element.data));
				structure.elements.push(newelement);
			}
			vertexBuffers[data.id] = new VertexBuffer(data.size, structure, kha.graphics4.Usage.StaticUsage);
		case 'begin', 'clear', 'end', 'setPipeline', 'updateIndexBuffer', 'updateVertexBuffer', 'setIndexBuffer', 'setVertexBuffer', 'drawIndexedVertices',
			'createConstantLocation', 'createTextureUnit', 'setMatrix3', 'setTexture':
			currentFrame.commands.push(data);
		case 'beginFrame':

		case 'endFrame':
			frames.push(currentFrame);
			currentFrame = new Frame();
		}
	}
}
