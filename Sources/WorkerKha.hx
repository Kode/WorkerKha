package;

import kha.graphics4.StencilValue;
import js.lib.ArrayBuffer;
import kha.graphics4.DepthStencilFormat;
import kha.graphics4.TextureFormat;
import js.Browser;
import js.html.Worker;
import kha.Assets;
import kha.audio1.Audio;
import kha.Blob;
import kha.Color;
import kha.Framebuffer;
import kha.Image;
import kha.graphics4.ConstantLocation;
import kha.graphics4.FragmentShader;
import kha.graphics4.IndexBuffer;
import kha.graphics4.TextureUnit;
import kha.graphics4.VertexBuffer;
import kha.graphics4.VertexElement;
import kha.graphics4.VertexShader;
import kha.graphics4.VertexStructure;
import kha.input.Keyboard;
import kha.input.KeyCode;
import kha.input.Mouse;
import kha.math.FastMatrix3;
import kha.math.FastMatrix4;
import kha.math.FastVector2;
import kha.math.FastVector3;
import kha.math.FastVector4;
import kha.Sound;
import kha.System;

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
	var worker: Worker;
	var frames: Array<Frame>;
	var currentFrame: Frame;
	var images: Map<Int, Image>;
	var lastImageId: Int;
	var shaders: Map<String, Dynamic>;
	var pipelines: Map<Int, Pipeline>;
	var pipelinesByVertexShader: Map<String, Pipeline>;
	var pipelinesByFragmentShader: Map<String, Pipeline>;
	var indexBuffers: Map<Int, IndexBuffer>;
	var vertexBuffers: Map<Int, VertexBuffer>;
	var constantLocations: Map<Int, ConstantLocation>;
	var textureUnits: Map<Int, TextureUnit>;
	var renderTargets: Map<Int, Image>;
	var sounds: Map<Int, Sound>;
	var workerDir: String;
	//var parser: Parser;
	var width: Int;
	var height: Int;
	var renderTarget: Image;

	public function new() {
		instance = this;
		frames = [];
		currentFrame = new Frame();
		images = new Map();
		shaders = new Map();
		pipelines = new Map();
		pipelinesByVertexShader = new Map();
		pipelinesByFragmentShader = new Map();
		indexBuffers = new Map();
		vertexBuffers = new Map();
		constantLocations = new Map();
		textureUnits = new Map();
		renderTargets = new Map();
		sounds = new Map();
		lastImageId = 0;
		Keyboard.get().notify(keyDown, keyUp, keyPress);
		Mouse.get().notify(mouseDown, mouseUp, mouseMove, mouseWheel);
		worker = null;
		renderTarget = Image.createRenderTarget(Browser.window.screen.width, Browser.window.screen.height, TextureFormat.RGBA32, DepthStencilFormat.DepthAutoStencilAuto);
	}

	function loadText(path: String, callback: String->Void): Void {
		Assets.loadBlobFromPath(path, (blob) -> {
			callback(blob.toString());
		}, (error) -> {
			trace("Error loading " + path);
		});
	}

	public function load(workerPath: String): Void {
		loadText(workerPath, function (source: String) {
			//parser = new Parser();
			//parser.parse(source, null);

			if (worker != null) {
				worker.terminate();
			}

			for (image in images) {
				image.unload();
			}
			for (pipeline in pipelines) {
				pipeline.state.delete();
			}
			for (buffer in indexBuffers) {
				buffer.delete();
			}
			for (buffer in vertexBuffers) {
				buffer.delete();
			}
			for (image in renderTargets) {
				image.unload();
			}
			for (sound in sounds) {
				sound.unload();
			}

			images = new Map();
			shaders = new Map();
			pipelines = new Map();
			pipelinesByVertexShader = new Map();
			pipelinesByFragmentShader = new Map();
			indexBuffers = new Map();
			vertexBuffers = new Map();
			constantLocations = new Map();
			textureUnits = new Map();
			renderTargets = new Map();
			sounds = new Map();
			width = -1;
			height = -1;

			frames = [];
			lastImageId = 0;

			workerDir = workerPath.substring(0, workerPath.lastIndexOf("/") + 1);
			worker = new Worker(workerPath);
			worker.addEventListener('message', onMessage, false);
		});
	}

	public function inject(workerPath: String): Void {
		loadText(workerPath, function (source: String) {
			//parser.parse(source, worker);
		});
	}

	function transformShaderName(name: String, type: String): String {
		if (kha.SystemImpl.gl2) {
			return name + "-webgl2." + type + ".essl";
		}
		else {
			var highp = kha.SystemImpl.gl.getShaderPrecisionFormat(js.html.webgl.GL.FRAGMENT_SHADER, js.html.webgl.GL.HIGH_FLOAT);
			var highpSupported = highp.precision != 0;
			if (!highpSupported) {
				return name + "-relaxed." + type + ".essl";
			}
			else {
				return name + "." + type + ".essl";
			}
		}
	}

	public function injectShader(shaderPath: String): Void {
		var localPath = shaderPath.substr(shaderPath.lastIndexOf("/") + 1);
		localPath = localPath.substr(0, localPath.length - 4) + "essl";

		if (shaderPath.endsWith(".frag.glsl")) {
			shaderPath = transformShaderName(shaderPath.substr(0, shaderPath.length - 10), "frag");
		}
		else {
			shaderPath = transformShaderName(shaderPath.substr(0, shaderPath.length - 10), "vert");
		}

		loadText(shaderPath, function (source: String) {
			if (shaderPath.endsWith(".frag.essl")) {
				var shader = FragmentShader.fromSource(source);
				this.shaders[localPath] = shader;
				var pipeline = pipelinesByFragmentShader[localPath];
				if (pipeline != null) {
					pipeline.state.fragmentShader = shader;
					pipeline.state.compile(); // works in webgl but don't do it for portable code
					pipeline.update();
				}
			}
			else if (shaderPath.endsWith(".vert.essl")) {
				var shader = VertexShader.fromSource(source);
				this.shaders[localPath] = shader;
				var pipeline = pipelinesByVertexShader[localPath];
				if (pipeline != null) {
					pipeline.state.vertexShader = shader;
					pipeline.state.compile(); // works in webgl but don't do it for portable code
					pipeline.update();
				}
			}
		});
	}
	
	public function render(framebuffers: Array<Framebuffer>): Void {
		var framebuffer = framebuffers[0];
		if (System.windowWidth() != width || System.windowHeight() != height) {
			width = System.windowWidth();
			height = System.windowHeight();
			if (worker != null) {
				worker.postMessage({ command: 'setWindowSize', width: width, height: height });
			}
		}
		if (frames.length > 0) {
			var g = renderTarget.g4;
			for (frame in frames) {
				var commands = frame.commands;
				for (command in commands) {
					switch (command.command) {
					case 'begin':
						if (command.renderTarget < 0) {
							g = renderTarget.g4;
							g.begin();
							g.viewport(0, 0, width, height);
						}
						else {
							g = renderTargets[command.renderTarget].g4;
							g.begin();
						}
					case 'clear':
						g.clear(command.color == null ? null : Color.fromValue(command.color), command.hasDepth ? command.depth : null, command.hasStencil ? command.stencil : null);
					case 'setPipeline':
						g.setPipeline(pipelines[command.id].state);
					case 'updateIndexBuffer':
						var indexBuffer = indexBuffers[command.id];
						var data: ArrayBuffer = indexBuffer.lock().buffer;
						new js.lib.Uint8Array(data).set(new js.lib.Uint8Array(command.data));
						indexBuffer.unlock();
					case 'updateVertexBuffer':
						var vertexBuffer = vertexBuffers[command.id];
						var start: Int = command.start;
						var count: Int = command.count;
						var data: ArrayBuffer = vertexBuffer.lock(start, count).buffer;
						new js.lib.Uint8Array(data).set(new js.lib.Uint8Array(command.data));
						vertexBuffer.unlock();
					case 'unlockImage':
						var image = images[command.id];
						var bytes = image.lock();
						new js.lib.Uint8Array(bytes.getData()).set(new js.lib.Uint8Array(command.bytes));
						image.unlock();
					case 'setIndexBuffer':
						g.setIndexBuffer(indexBuffers[command.id]);
					case 'setVertexBuffer':
						g.setVertexBuffer(vertexBuffers[command.id]);
					case 'setVertexBuffers':
						var buffers = new Array<VertexBuffer>();
						for (i in 0...command.ids.length) {
							buffers.push(vertexBuffers[command.ids[i]]);
						}
						g.setVertexBuffers(buffers);
					case 'createConstantLocation':
						constantLocations[command.id] = pipelines[command.pipeline].getConstantLocation(command.name);
					case 'createTextureUnit':
						textureUnits[command.id] = pipelines[command.pipeline].getTextureUnit(command.name);
					case 'setTexture':
						if (command.texture < 0 && command.renderTarget < 0) {
							g.setTexture(textureUnits[command.stage], null);
						}
						else if (command.texture < 0) {
							g.setTexture(textureUnits[command.stage], renderTargets[command.renderTarget]);
						}
						else {
							g.setTexture(textureUnits[command.stage], images[command.texture]);
						}
					case 'setTextureParameters':
						g.setTextureParameters(textureUnits[command.id], command.uAddressing, command.vAddressing,
							command.minificationFilter, command.magnificationFilter, command.mipmapFilter);
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
					case 'viewport':
						g.viewport(command.x, command.y, command.width, command.height);
					case 'scissor':
						g.scissor(command.x, command.y, command.width, command.height);
					case 'disableScissor':
						g.disableScissor();
					case 'drawIndexedVertices':
						g.drawIndexedVertices(command.start, command.count);
					case 'drawIndexedVerticesInstanced':
						g.drawIndexedVerticesInstanced(command.instanceCount, command.start, command.count);
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
		framebuffer.g2.begin();
		framebuffer.g2.clear(Color.Black);
		if (Image.renderTargetsInvertedY()) {
			framebuffer.g2.drawScaledSubImage(renderTarget, 0, height, width, -height, 0, 0, width, height);
		}
		else {
			framebuffer.g2.drawImage(renderTarget, 0, 0);
		}
		framebuffer.g2.end();
	}
	
	function keyDown(key: KeyCode): Void {
		if (worker != null) {
			worker.postMessage({ command: 'keyDown', key: key });
		}
	}
	
	function keyUp(key: KeyCode): Void {
		if (worker != null) {
			worker.postMessage({ command: 'keyUp', key: key });
		}
	}

	function keyPress(character: String): Void {
		if (worker != null) {
			worker.postMessage({ command: 'keyPress', character: character });
		}
	}

	function mouseDown(button: Int, x: Int, y: Int): Void {
		if (worker != null) {
			worker.postMessage({ command: 'mouseDown', button: button, x: x, y: y });
		}
	}

	function mouseUp(button: Int, x: Int, y: Int): Void {
		if (worker != null) {
			worker.postMessage({ command: 'mouseUp', button: button, x: x, y: y });
		}
	}

	function mouseMove(x: Int, y: Int, mx: Int, my: Int): Void {
		if (worker != null) {
			worker.postMessage({ command: 'mouseMove', x: x, y: y, mx: mx, my: my });
		}
	}

	function mouseWheel(delta: Int): Void {
		if (worker != null) {
			worker.postMessage({ command: 'mouseWheel', delta: delta });
		}
	}
	
	function onMessage(message: Dynamic): Void {
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
				sounds.set(data.id, sound);
				if (worker != null) {
					worker.postMessage( { command: 'loadedSound', id: data.id, file: data.file } );
				}
			});
		case 'uncompressSound':
			sounds[data.id].uncompress(function () {
				if (worker != null) {
					worker.postMessage({ command: 'uncompressedSound', id: data.id });
				}
			});
		case 'playSound':
			Audio.play(sounds[data.id], data.loop);
		case 'streamSound':
			Audio.stream(sounds[data.id], data.loop);
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
			var pipe = new Pipeline();
			pipe.state.fragmentShader = shaders[data.frag];
			pipelinesByFragmentShader[pipe.state.fragmentShader.files[0]] = pipe;
			pipe.state.vertexShader = shaders[data.vert];
			pipelinesByVertexShader[pipe.state.vertexShader.files[0]] = pipe;
			pipe.state.inputLayout = [];
			var layout: Array<Dynamic> = data.layout;
			for (structure in layout) {
				var newstructure = new VertexStructure();
				var elements: Array<Dynamic> = structure.elements;
				for (element in elements) {
					var newelement = new VertexElement(element.name, element.data);
					newstructure.elements.push(newelement);
				}
				pipe.state.inputLayout.push(newstructure);
			}
			var state = data.state;
			pipe.state.cullMode = state.cullMode;
			pipe.state.depthWrite = state.depthWrite;
			pipe.state.depthMode = state.depthMode;
			pipe.state.stencilFrontMode = state.stencilFrontMode;
			pipe.state.stencilFrontBothPass = state.stencilFrontBothPass;
			pipe.state.stencilFrontDepthFail = state.stencilFrontDepthFail;
			pipe.state.stencilFrontFail = state.stencilFrontFail;
			pipe.state.stencilBackMode = state.stencilBackMode;
			pipe.state.stencilBackBothPass = state.stencilBackBothPass;
			pipe.state.stencilBackDepthFail = state.stencilBackDepthFail;
			pipe.state.stencilBackFail = state.stencilBackFail;
			pipe.state.stencilReferenceValue = state.stencilReferenceValue == -1 ? StencilValue.Dynamic : StencilValue.Static(state.stencilReferenceValue);
			pipe.state.stencilReadMask = state.stencilReadMask;
			pipe.state.stencilWriteMask = state.stencilWriteMask;
			pipe.state.blendSource = state.blendSource;
			pipe.state.blendDestination = state.blendDestination;
			pipe.state.alphaBlendSource = state.alphaBlendSource;
			pipe.state.alphaBlendDestination = state.alphaBlendDestination;
			pipe.state.colorWriteMaskRed = state.colorWriteMaskRed;
			pipe.state.colorWriteMaskGreen = state.colorWriteMaskGreen;
			pipe.state.colorWriteMaskBlue = state.colorWriteMaskBlue;
			pipe.state.colorWriteMaskAlpha = state.colorWriteMaskAlpha;
			pipe.state.conservativeRasterization = state.conservativeRasterization;
			pipe.state.compile();
			pipelines[data.id] = pipe;
		case 'createIndexBuffer':
			indexBuffers[data.id] = new IndexBuffer(data.size, data.usage);
		case 'createVertexBuffer':
			var structure = new VertexStructure();
			var elements: Array<Dynamic> = data.structure.elements;
			for (element in elements) {
				var newelement = new VertexElement(element.name, element.data);
				structure.elements.push(newelement);
			}
			vertexBuffers[data.id] = new VertexBuffer(data.size, structure, data.usage);
		case 'createImage':
			images[data.id] = Image.create(data.width, data.height, data.format, data.usage);
		case 'createRenderTarget':
			renderTargets[data.id] = Image.createRenderTarget(data.width, data.height);
		case 'begin', 'clear', 'end', 'setPipeline', 'updateIndexBuffer', 'updateVertexBuffer', 'setIndexBuffer', 'setVertexBuffer', 'drawIndexedVertices',
			'createConstantLocation', 'createTextureUnit', 'setTexture', 'unlockImage', 'setTextureParameters',
			'setMatrix3', 'setMatrix4', 'setVector2', 'setVector3', 'setVector4', 'setFloats', 'setFloat', 'setFloat2', 'setFloat3', 'setFloat4', 'setInt', 'setBool',
			'viewport', 'scissor', 'disableScissor', 'setVertexBuffers', 'drawIndexedVerticesInstanced':
			currentFrame.commands.push(data);
		case 'beginFrame':

		case 'endFrame':
			frames.push(currentFrame);
			currentFrame = new Frame();
		}
	}
}
