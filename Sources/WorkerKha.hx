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
import kha.math.FastMatrix4;
import kha.math.FastVector2;
import kha.math.FastVector3;
import kha.math.FastVector4;
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
	var parser: Parser;

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

	function loadText(path: String, callback: String->Void): Void {
		var request = untyped new js.html.XMLHttpRequest();
		request.open("GET", path, true);
		request.responseType = "text";
		
		request.onreadystatechange = function() {
			if (request.readyState != 4) return;
			if (request.status >= 200 && request.status < 400) {
				callback(request.response);
			}
			else {
				trace("Error loading " + path);
			}
		};
		request.send(null);
	}

	public function load(workerPath: String): Void {
		loadText(workerPath, function (source: String) {
			parser = new Parser();
			parser.parse(source, null);

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
		});
	}

	public function inject(workerPath: String): Void {
		loadText(workerPath, function (source: String) {
			parser.parse(source, worker);
		});
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
					case 'setMatrix4':
						g.setMatrix(constantLocations[command.location], new FastMatrix4(command._00, command._10, command._20, command._30,
							command._01, command._11, command._21, command._31, command._02, command._12, command._22, command._32,
							command._03, command._13, command._23, command._33));
					case 'setVector2':
						g.setVector2(constantLocations[command.location], new FastVector2(command.x, command.y));
					case 'setVector3':
						g.setVector3(constantLocations[command.location], new FastVector3(command.x, command.y, command.z));
					case 'setVector4':
						g.setVector4(constantLocations[command.location], new FastVector4(command.x, command.y, command.z, command.w));
					case 'setFloats':
						g.setFloats(constantLocations[command.location], command.values);
					case 'setFloat':
						g.setFloat(constantLocations[command.location], command.value);
					case 'setFloat2':
						g.setFloat2(constantLocations[command.location], command._0, command._1);
					case 'setFloat3':
						g.setFloat3(constantLocations[command.location], command._0, command._1, command._2);
					case 'setFloat4':
						g.setFloat4(constantLocations[command.location], command._0, command._1, command._2, command._3);
					case 'setInt':
						g.setInt(constantLocations[command.location], command.value);
					case 'setBool':
						g.setBool(constantLocations[command.location], command.value);
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
					worker.postMessage( { command: 'loadedBlob', id: data.id, data: blob.bytes.getData() } );
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
					worker.postMessage( { command: 'loadedSound', id: data.id, file: data.file } );
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
			'createConstantLocation', 'createTextureUnit', 'setTexture',
			'setMatrix3', 'setMatrix4', 'setVector2', 'setVector3', 'setVector4', 'setFloats', 'setFloat', 'setFloat2', 'setFloat3', 'setFloat4', 'setInt', 'setBool':
			currentFrame.commands.push(data);
		case 'beginFrame':

		case 'endFrame':
			frames.push(currentFrame);
			currentFrame = new Frame();
		}
	}
}
