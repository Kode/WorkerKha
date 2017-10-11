package;

import kha.graphics4.ConstantLocation;
import kha.graphics4.PipelineState;
import kha.graphics4.TextureUnit;

class Pipeline {
	public var state: PipelineState = new PipelineState();
	public var constantLocations: Map<String, ConstantLocation> = new Map();
	public var textureUnits: Map<String, TextureUnit> = new Map();

	public function new() {
		
	}

	public function getConstantLocation(name: String): ConstantLocation {
		var location = state.getConstantLocation(name);
		constantLocations[name] = location;
		return location;
	}

	public function getTextureUnit(name: String): TextureUnit {
		var unit = state.getTextureUnit(name);
		textureUnits[name] = unit;
		return unit;
	}

	public function update(): Void {
		for (name in constantLocations.keys()) {
			var oldLocation: kha.js.graphics4.ConstantLocation = cast constantLocations[name];
			var newLocation: kha.js.graphics4.ConstantLocation = cast state.getConstantLocation(name);
			oldLocation.type = newLocation.type;
			oldLocation.value = newLocation.value;
		}
		for (name in textureUnits.keys()) {
			var oldUnit: kha.js.graphics4.TextureUnit = cast textureUnits[name];
			var newUnit: kha.js.graphics4.TextureUnit = cast state.getTextureUnit(name);
			oldUnit.value = newUnit.value;
		}
	}
}
